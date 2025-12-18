import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:exif/exif.dart';

class ModelHelper {
  static Interpreter? _interpreter;
  static List<String> _labels = [];
  static bool _isLoaded = false;

  static Future<bool> loadModel() async {
    if (_isLoaded) return true;

    try {
      // Load labels
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
        final parts = line.trim().split(' ');
        if (parts.length > 1) {
          return parts.sublist(1).join(' ').trim();
        }
        return line.trim();
      }).toList();

      // Load model
      final interpreterOptions = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset(
        'assets/model_unquant.tflite',
        options: interpreterOptions,
      );

      _isLoaded = true;
      print('Model loaded successfully. Labels: $_labels');
      return true;
    } catch (e) {
      print('Error loading model: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  static Future<Map<String, double>?> predictImage(String imagePath) async {
    if (!_isLoaded || _interpreter == null) {
      final loaded = await loadModel();
      if (!loaded) return null;
    }

    try {
      // Get input and output tensor shapes
      final inputTensor = _interpreter!.getInputTensors()[0];
      final outputTensor = _interpreter!.getOutputTensors()[0];

      final inputShape = inputTensor.shape;
      final outputShape = outputTensor.shape;

      final inputHeight = inputShape[1] as int;
      final inputWidth = inputShape[2] as int;
      final numChannels = inputShape[3] as int;

      // Read and preprocess image
      final imageBytes = await File(imagePath).readAsBytes();
      var image = img.decodeImage(imageBytes);

      if (image == null) return null;

      // Fix EXIF orientation (especially important for camera images)
      image = await _fixImageOrientation(image, imageBytes);

      // Center-crop the image to reduce background influence.
      // This helps make camera photos closer to your training / gallery images.
      final minSide = image.width < image.height ? image.width : image.height;
      final cropSize = (minSide * 0.8).toInt(); // use 80% of the shortest side
      final cropX = ((image.width - cropSize) / 2).round().clamp(0, image.width - cropSize);
      final cropY = ((image.height - cropSize) / 2).round().clamp(0, image.height - cropSize);

      final croppedImage = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropSize,
        height: cropSize,
      );

      // Resize image to model input size
      // Use linear interpolation for quality
      final resizedImage = img.copyResize(
        croppedImage,
        width: inputWidth,
        height: inputHeight,
        interpolation: img.Interpolation.linear,
      );

      // Convert to nested list matching tensor shape [1, height, width, channels]
      // For FLOAT (non-quantized) models, normalize to [0, 1] range
      final inputBuffer = List.generate(
        1, // batch size
        (_) => List.generate(
          inputHeight,
          (h) => List.generate(
            inputWidth,
            (w) {
              final pixel = resizedImage.getPixel(w, h);
              // Float models expect normalization to [0, 1] range
              // Ensure values are clamped and properly normalized
              final r = (pixel.r.clamp(0, 255) / 255.0);
              final g = (pixel.g.clamp(0, 255) / 255.0);
              final b = (pixel.b.clamp(0, 255) / 255.0);
              return [
                r, // R
                g, // G
                b, // B
              ];
            },
          ),
        ),
      );

      // Create output buffer matching the output shape [1, numClasses]
      final outputBuffer = List.generate(
        outputShape[0] as int, // batch size (1)
        (_) => List<double>.filled(outputShape[1] as int, 0.0),
      );

      print('Input shape: $inputShape');
      print('Output shape: $outputShape');
      print(
          'Input buffer structure: [${inputBuffer.length}][${inputBuffer[0].length}][${inputBuffer[0][0].length}][${inputBuffer[0][0][0].length}]');
      print(
          'Output buffer structure: [${outputBuffer.length}][${outputBuffer[0].length}]');

      // Validate input buffer values are in [0, 1] range
      final samplePixel = inputBuffer[0][0][0];
      print(
          'Sample pixel (first pixel): R=${samplePixel[0]}, G=${samplePixel[1]}, B=${samplePixel[2]}');
      print('Input normalization: [0, 1] range (float model)');

      // Run inference
      try {
        _interpreter!.run(inputBuffer, outputBuffer);
        print('Inference completed successfully');
      } catch (e) {
        print('ERROR during inference: $e');
        print('Stack trace: ${StackTrace.current}');
        return null;
      }

      // Output buffer is now [1][numClasses]
      final predictions = outputBuffer[0];
      print('Output buffer after inference: $predictions');
      print('Output buffer sum: ${predictions.fold(0.0, (a, b) => a + b)}');

      // Map output to labels
      final results = <String, double>{};

      if (_labels.isEmpty) {
        print('ERROR: Labels are empty!');
        return null;
      }

      final numLabels =
          predictions.length < _labels.length ? predictions.length : _labels.length;
      print('Mapping $numLabels predictions to ${_labels.length} labels');
      print('Label order verification:');
      for (int i = 0; i < _labels.length && i < 5; i++) {
        print('  Index $i -> ${_labels[i]}');
      }

      for (int i = 0; i < numLabels && i < _labels.length; i++) {
        final label = _labels[i];
        final confidence = predictions[i];
        results[label] = confidence;
        if (i < 5 || confidence > 0.01) {
          print('Label $i ($label): ${(confidence * 100).toStringAsFixed(2)}%');
        }
      }

      print('Final predictions map: $results');
      print('Number of results: ${results.length}');
      print('Number of labels: ${_labels.length}');
      print('Output size: ${predictions.length}');

      final maxConfidence = results.values.isEmpty
          ? 0.0
          : results.values.reduce((a, b) => a > b ? a : b);
      print('Max confidence: $maxConfidence');

      if (maxConfidence == 0.0 && results.isNotEmpty) {
        print(
            'WARNING: All predictions are zero! Model might not be working correctly.');
      }

      return results.isEmpty ? null : results;
    } catch (e) {
      print('Error predicting image: $e');
      return null;
    }
  }

  /// Fixes image orientation based on EXIF data
  /// This is crucial for camera images which often have orientation metadata
  static Future<img.Image> _fixImageOrientation(
      img.Image image, List<int> imageBytes) async {
    try {
      final exifData = await readExifFromBytes(Uint8List.fromList(imageBytes));

      if (exifData.isEmpty) {
        return image;
      }

      IfdTag? orientationTag;
      if (exifData.containsKey('Image Orientation')) {
        orientationTag = exifData['Image Orientation'];
      } else if (exifData.containsKey('EXIF Orientation')) {
        orientationTag = exifData['EXIF Orientation'];
      } else if (exifData.containsKey('0x0112')) {
        orientationTag = exifData['0x0112'];
      }

      if (orientationTag == null) {
        return image;
      }

      // Get orientation value from printable string
      int orientationValue = 1;
      try {
        final printable = orientationTag.printable.trim();
        if (printable.isNotEmpty) {
          final match = RegExp(r'\d+').firstMatch(printable);
          if (match != null) {
            orientationValue =
                int.tryParse(match.group(0) ?? '1') ?? 1;
          }
        }
      } catch (e) {
        print('Warning: Could not parse orientation value: $e');
        orientationValue = 1;
      }

      switch (orientationValue) {
        case 1: // Normal
          return image;
        case 2: // Flip horizontal
          return img.flipHorizontal(image);
        case 3: // Rotate 180°
          return img.copyRotate(image, angle: 180);
        case 4: // Flip vertical
          return img.flipVertical(image);
        case 5: // Rotate 90° CCW and flip horizontal
          return img.flipHorizontal(img.copyRotate(image, angle: -90));
        case 6: // Rotate 90° CW
          return img.copyRotate(image, angle: 90);
        case 7: // Rotate 90° CW and flip horizontal
          return img.flipHorizontal(img.copyRotate(image, angle: 90));
        case 8: // Rotate 90° CCW
          return img.copyRotate(image, angle: -90);
        default:
          return image;
      }
    } catch (e) {
      print('Warning: Could not read EXIF data: $e');
      return image;
    }
  }

  static List<String> getAllLabels() {
    return List<String>.from(_labels);
  }

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}

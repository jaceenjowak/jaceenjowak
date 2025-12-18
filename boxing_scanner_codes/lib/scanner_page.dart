import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'home_page.dart';
import 'model_helper.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  // 0 = Home, 1 = Camera, 2 = Gallery, 3 = Graph, 4 = Logs
  int _bottomNavIndex = 1; // default to Camera
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  Map<String, double>? _predictions;
  bool _isLoading = false;
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final loaded = await ModelHelper.loadModel();
      setState(() {
        _modelLoaded = loaded;
        _isLoading = false;
      });
      if (!loaded && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load AI model. Please restart the app.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error in _loadModel: $e');
      if (mounted) {
        setState(() {
          _modelLoaded = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Model loading error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFromCamera() async {
    // Use higher quality settings for camera
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100, // Maximum quality
    );
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _predictions = null;
      });
      await _runPrediction(image.path, source: 'camera');
    }
  }

  Future<void> _pickFromGallery() async {
    // Use high quality for gallery too for consistency
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100, // Maximum quality
    );
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _predictions = null;
      });
      await _runPrediction(image.path, source: 'gallery');
    }
  }

  Future<void> _runPrediction(String imagePath, {required String source}) async {
    if (!_modelLoaded) {
      await _loadModel();
      if (!_modelLoaded) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load model. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _predictions = null;
    });

    try {
      final predictions = await ModelHelper.predictImage(imagePath);

      if (!mounted) return;

      setState(() {
        _predictions = predictions;
        _isLoading = false;
      });

      if (predictions == null || predictions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No predictions found. Please try another image.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Save prediction result to Firebase
      await _savePredictionToFirebase(
        source: source,
        imagePath: imagePath,
        predictions: predictions,
      );
    } catch (e) {
      print('Error running prediction: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentBackground,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        title: const Text(
          'Scanner',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _bottomNavIndex == 3
            ? _buildGraphPage()
            : _bottomNavIndex == 4
                ? _buildLogsPage()
                : Column(
                children: [
                  const SizedBox(height: 16),
                  _buildScannerCard(context),
                  if (_predictions != null && _predictions!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildPredictionResults(),
                  ],
                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: CircularProgressIndicator(
                        color: kPrimaryColor,
                      ),
                    ),
                  ],
                  if (_selectedImage != null && 
                      !_isLoading && 
                      (_predictions == null || _predictions!.isEmpty)) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          if (_selectedImage != null) {
                            // Re-analyze using the current tab context as source.
                            final source = _bottomNavIndex == 2 ? 'gallery' : 'camera';
                            await _runPrediction(_selectedImage!.path, source: source);
                          }
                        },
                        icon: const Icon(Icons.analytics_rounded),
                        label: const Text(
                          'Analyze Image',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          if (_bottomNavIndex == 1) {
                            await _pickFromCamera();
                          } else if (_bottomNavIndex == 2) {
                            await _pickFromGallery();
                          }
                        },
                        icon: Icon(
                          _bottomNavIndex == 2
                              ? Icons.photo_library_rounded
                              : Icons.camera_alt_rounded,
                        ),
                        label: Text(
                          _bottomNavIndex == 2
                              ? 'Pick from Gallery'
                              : 'Capture image',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildScannerCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _selectedImage == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: kSecondaryColor,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Capture or pick an image to begin',
                      style: TextStyle(
                        fontSize: 16,
                        color: kSecondaryColor,
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(
                  File(_selectedImage!.path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
                  ),
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildPredictionResults() {
    if (_predictions == null || _predictions!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort predictions by confidence
    final sortedPredictions = _predictions!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Basic uncertainty check: if top confidence is low or close to second,
    // we surface that the model is unsure.
    final top = sortedPredictions.first;
    final second = sortedPredictions.length > 1 ? sortedPredictions[1] : null;
    final topConf = top.value;
    final secondConf = second?.value ?? 0.0;
    final isUncertain = topConf < 0.6 || (topConf - secondConf) < 0.15;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prediction Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            if (isUncertain) ...[
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: kSecondaryColor,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Model is not very confident. Consider checking the top 2–3 brands.',
                      style: TextStyle(
                        fontSize: 12,
                        color: kSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            ...sortedPredictions.take(5).map((entry) {
              final confidence = (entry.value * 100).toStringAsFixed(1);
              final isTopPrediction = sortedPredictions.indexOf(entry) == 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: isTopPrediction ? () => _showGraphDialog() : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: isTopPrediction ? 16 : 14,
                            fontWeight: isTopPrediction
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isTopPrediction
                                ? kPrimaryColor
                                : kSecondaryColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isTopPrediction
                              ? kPrimaryColor.withOpacity(0.1)
                              : kSecondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$confidence%',
                              style: TextStyle(
                                fontSize: isTopPrediction ? 14 : 12,
                                fontWeight: FontWeight.bold,
                                color: isTopPrediction
                                    ? kPrimaryColor
                                    : kSecondaryColor,
                              ),
                            ),
                            if (isTopPrediction) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.show_chart_rounded,
                                size: 16,
                                color: kPrimaryColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
              ),
      ),
    );
  }

  Future<void> _savePredictionToFirebase({
    required String source,
    required String imagePath,
    required Map<String, double> predictions,
  }) async {
    try {
      final sorted = predictions.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final top = sorted.isNotEmpty ? sorted.first : null;

      await FirebaseFirestore.instance.collection('predictions').add({
        'source': source, // 'camera' or 'gallery'
        'imagePath': imagePath,
        'timestamp': FieldValue.serverTimestamp(),
        'topLabel': top?.key,
        'topConfidence': top?.value,
        'allPredictions': predictions.map(
          (label, value) => MapEntry(label, value),
        ),
      });
    } catch (e) {
      // Don't block the UI if logging fails; just log the error.
      debugPrint('Error saving prediction to Firebase: $e');
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          setState(() {
            _bottomNavIndex = index;
          });

          if (index == 0) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
            );
          }
          // Graph (3) and Logs (4) just switch the tab for now.
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: kPrimaryColor,
        unselectedItemColor: kSecondaryColor.withOpacity(0.6),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_rounded),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library_rounded),
            label: 'Gallery',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_rounded),
            label: 'Graph',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_rounded),
            label: 'Logs',
          ),
        ],
      ),
    );
  }

  void _showGraphDialog() {
    if (_predictions == null || _predictions!.isEmpty) return;

    // Get all labels from the model
    final allLabels = ModelHelper.getAllLabels();
    
    // Create a map with all brands, setting 0% for those not in predictions
    final allPredictions = <String, double>{};
    for (final label in allLabels) {
      allPredictions[label] = _predictions![label] ?? 0.0;
    }

    // Sort by percentage (highest first)
    final sortedAllPredictions = allPredictions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Predictions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    color: kSecondaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: SizedBox(
                    height: sortedAllPredictions.length * 60.0,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 100,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => kPrimaryColor,
                            tooltipRoundedRadius: 8,
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipMargin: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final brand = sortedAllPredictions[group.x.toInt()].key;
                              final percentage = rod.toY.toStringAsFixed(1);
                              return BarTooltipItem(
                                '$brand\n$percentage%',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= sortedAllPredictions.length) {
                                  return const Text('');
                                }
                                final brand = sortedAllPredictions[value.toInt()].key;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    brand.length > 10
                                        ? '${brand.substring(0, 10)}...'
                                        : brand,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: kSecondaryColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              },
                              reservedSize: 50,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: kSecondaryColor,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: kSecondaryColor.withOpacity(0.2),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 20,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: kSecondaryColor.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        barGroups: sortedAllPredictions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final prediction = entry.value.value;
                          final percentage = prediction * 100;
                          final isTop = index == 0;
                          
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: percentage,
                                color: isTop ? kPrimaryColor : kSecondaryColor,
                                width: 20,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // List view of all predictions
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedAllPredictions.length,
                  itemBuilder: (context, index) {
                    final entry = sortedAllPredictions[index];
                    final percentage = (entry.value * 100).toStringAsFixed(1);
                    final isTop = index == 0;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            child: Text(
                              '${index + 1}.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                                color: isTop ? kPrimaryColor : kSecondaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                                color: isTop ? kPrimaryColor : kSecondaryColor,
                              ),
                            ),
                          ),
                          Text(
                            '$percentage%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                              color: isTop ? kPrimaryColor : kSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraphPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('predictions')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.show_chart_rounded,
                  size: 64,
                  color: kSecondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No scan data available',
                  style: TextStyle(
                    fontSize: 18,
                    color: kSecondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start scanning to see analytics',
                  style: TextStyle(
                    fontSize: 14,
                    color: kSecondaryColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        final predictions = snapshot.data!.docs;
        final graphData = _processGraphData(predictions);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildConfidenceTiersCard(graphData),
              const SizedBox(height: 16),
              _buildConfidenceTrendCard(graphData),
              const SizedBox(height: 16),
              _buildScansByCondimentCard(graphData),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic> _processGraphData(List<QueryDocumentSnapshot> docs) {
    // Process confidence tiers
    int highCount = 0;
    int mediumCount = 0;
    int lowCount = 0;

    // Process confidence trend (last 7 days)
    final now = DateTime.now();
    final Map<String, List<double>> dailyConfidences = {};
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('EEE').format(date);
      dailyConfidences[dayKey] = [];
    }

    // Process scans by condiment
    final Map<String, int> condimentCounts = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final topConfidence = (data['topConfidence'] as num?)?.toDouble() ?? 0.0;
      final topLabel = data['topLabel'] as String? ?? 'Unknown';
      final timestamp = data['timestamp'] as Timestamp?;

      // Count confidence tiers
      if (topConfidence > 0.8) {
        highCount++;
      } else if (topConfidence >= 0.6) {
        mediumCount++;
      } else {
        lowCount++;
      }

      // Add to daily confidences
      if (timestamp != null) {
        final date = timestamp.toDate();
        final dayKey = DateFormat('EEE').format(date);
        if (dailyConfidences.containsKey(dayKey)) {
          dailyConfidences[dayKey]!.add(topConfidence);
        } else {
          // If date is older than 7 days, add to the oldest day
          final oldestDay = dailyConfidences.keys.first;
          dailyConfidences[oldestDay]!.add(topConfidence);
        }
      }

      // Count scans by condiment
      condimentCounts[topLabel] = (condimentCounts[topLabel] ?? 0) + 1;
    }

    // Calculate average confidence per day
    final Map<String, double> dailyAverages = {};
    dailyConfidences.forEach((day, confidences) {
      if (confidences.isEmpty) {
        dailyAverages[day] = 0.0;
      } else {
        dailyAverages[day] = confidences.reduce((a, b) => a + b) / confidences.length;
      }
    });

    return {
      'highCount': highCount,
      'mediumCount': mediumCount,
      'lowCount': lowCount,
      'totalCount': highCount + mediumCount + lowCount,
      'dailyAverages': dailyAverages,
      'condimentCounts': condimentCounts,
    };
  }

  Widget _buildConfidenceTiersCard(Map<String, dynamic> data) {
    final highCount = data['highCount'] as int;
    final mediumCount = data['mediumCount'] as int;
    final lowCount = data['lowCount'] as int;
    final totalCount = data['totalCount'] as int;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confidence tiers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          const SizedBox(height: 20),
          _buildTierRow(
            'High > 80%',
            highCount,
            totalCount,
            Colors.green,
            Icons.thumb_up_rounded,
          ),
          const SizedBox(height: 16),
          _buildTierRow(
            'Medium 60-80%',
            mediumCount,
            totalCount,
            Colors.orange,
            null,
          ),
          const SizedBox(height: 16),
          _buildTierRow(
            'Low < 60%',
            lowCount,
            totalCount,
            Colors.red,
            Icons.thumb_down_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTierRow(String label, int count, int total, Color color, IconData? icon) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Text(
              '$count scans',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kSecondaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceTrendCard(Map<String, dynamic> data) {
    final dailyAverages = data['dailyAverages'] as Map<String, double>;
    final days = dailyAverages.keys.toList();
    final values = days.map((day) => dailyAverages[day]! * 100).toList();
    final maxY = values.isEmpty
        ? 100.0
        : (values.reduce((a, b) => a > b ? a : b) * 1.2).clamp(0.0, 100.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confidence trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: kSecondaryColor.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              days[value.toInt()],
                              style: const TextStyle(
                                fontSize: 10,
                                color: kSecondaryColor,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: kSecondaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: kSecondaryColor.withOpacity(0.2),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      days.length,
                      (index) => FlSpot(index.toDouble(), values[index]),
                    ),
                    isCurved: false,
                    color: const Color(0xFFFF7043),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFFFF7043),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFFF7043).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 0,
                maxY: maxY,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScansByCondimentCard(Map<String, dynamic> data) {
    final condimentCounts = data['condimentCounts'] as Map<String, int>;
    final sortedCondiments = condimentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedCondiments.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxCount = sortedCondiments.first.value;
    final colors = [
      const Color(0xFFFF7043),
      const Color(0xFFFF8A65),
      const Color(0xFFFFAB91),
      const Color(0xFFFFCCBC),
      const Color(0xFFFFE0B2),
      const Color(0xFFFFF3E0),
      const Color(0xFFFFF8E1),
      const Color(0xFFFFF9C4),
      const Color(0xFFFFFFB3),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scans by Glove Brands',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCount.toDouble() * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => kPrimaryColor,
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final condiment = sortedCondiments[group.x.toInt()].key;
                      final count = rod.toY.toInt();
                      return BarTooltipItem(
                        '$condiment\n$count scans',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < sortedCondiments.length) {
                          final condiment = sortedCondiments[value.toInt()].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                condiment.length > 8
                                    ? '${condiment.substring(0, 8)}...'
                                    : condiment,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: kSecondaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 50,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: kSecondaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: kSecondaryColor.withOpacity(0.2),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxCount > 0 ? (maxCount / 4).ceil().toDouble() : 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: kSecondaryColor.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                barGroups: sortedCondiments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final count = entry.value.value;
                  final colorIndex = index < colors.length ? index : colors.length - 1;
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: colors[colorIndex],
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('predictions')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: kSecondaryColor),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_rounded,
                  size: 64,
                  color: kSecondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No scan history',
                  style: TextStyle(
                    fontSize: 18,
                    color: kSecondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start scanning to see your logs',
                  style: TextStyle(
                    fontSize: 14,
                    color: kSecondaryColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        final logs = snapshot.data!.docs;

        return Column(
          children: [
            // App bar with profile icon (optional)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scan History',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                  // Profile icon placeholder (can be customized later)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kSecondaryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(
                            Icons.person_rounded,
                            color: kSecondaryColor,
                            size: 24,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Logs list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final doc = logs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildLogCard(data, doc.id);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogCard(Map<String, dynamic> data, String docId) {
    final topLabel = data['topLabel'] as String? ?? 'Unknown';
    final topConfidence = (data['topConfidence'] as num?)?.toDouble() ?? 0.0;
    final source = data['source'] as String? ?? 'camera';
    final timestamp = data['timestamp'] as Timestamp?;
    final imagePath = data['imagePath'] as String?;
    final allPredictions = data['allPredictions'] as Map<String, dynamic>?;

    final confidencePercent = (topConfidence * 100).toStringAsFixed(1);
    final relativeTime = timestamp != null
        ? _formatRelativeTime(timestamp.toDate())
        : 'Unknown time';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLogDetailDialog(
            imagePath: imagePath,
            allPredictions: allPredictions,
            topLabel: topLabel,
            topConfidence: topConfidence,
            source: source,
            timestamp: timestamp,
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Source icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    source == 'gallery'
                        ? Icons.photo_library_rounded
                        : Icons.camera_alt_rounded,
                    color: kPrimaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$confidencePercent% confidence',
                            style: TextStyle(
                              fontSize: 13,
                              color: kSecondaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            source == 'gallery'
                                ? Icons.photo_library_rounded
                                : Icons.camera_alt_rounded,
                            size: 14,
                            color: kSecondaryColor.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            source,
                            style: TextStyle(
                              fontSize: 13,
                              color: kSecondaryColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Timestamp
                Text(
                  relativeTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: kSecondaryColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showLogDetailDialog({
    required String? imagePath,
    required Map<String, dynamic>? allPredictions,
    required String topLabel,
    required double topConfidence,
    required String source,
    required Timestamp? timestamp,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topLabel,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                source == 'gallery'
                                    ? Icons.photo_library_rounded
                                    : Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                source,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${(topConfidence * 100).toStringAsFixed(1)}% confidence',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Image
                      if (imagePath != null) ...[
                        Container(
                          constraints: const BoxConstraints(
                            maxHeight: 300,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(imagePath),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: kSecondaryColor.withOpacity(0.1),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported_rounded,
                                      size: 48,
                                      color: kSecondaryColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // All predictions
                      if (allPredictions != null && allPredictions.isNotEmpty) ...[
                        const Text(
                          'All Predictions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._buildPredictionList(allPredictions),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPredictionList(Map<String, dynamic> predictions) {
    // Convert to list and sort by confidence
    final sorted = predictions.entries.toList()
      ..sort((a, b) {
        final aVal = (a.value as num).toDouble();
        final bVal = (b.value as num).toDouble();
        return bVal.compareTo(aVal);
      });

    return sorted.map((entry) {
      final label = entry.key;
      final confidence = (entry.value as num).toDouble();
      final percentage = (confidence * 100).toStringAsFixed(1);
      final isTop = sorted.indexOf(entry) == 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isTop
              ? kPrimaryColor.withOpacity(0.1)
              : kSecondaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: isTop
              ? Border.all(color: kPrimaryColor.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                  color: isTop ? kPrimaryColor : kSecondaryColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isTop
                    ? kPrimaryColor.withOpacity(0.2)
                    : kSecondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isTop ? kPrimaryColor : kSecondaryColor,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}


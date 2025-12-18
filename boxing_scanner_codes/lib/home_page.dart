import 'package:flutter/material.dart';
import 'scanner_page.dart';

// Shared brand colors
const Color kPrimaryColor = Color(0xFF452829);
const Color kSecondaryColor = Color(0xFF57595B);
const Color kAccentBackground = Color(0xFFE8D1C5);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/homepage_bg/background.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.black,
              ),
            ),
          ),
          // Dark overlay for readability
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),
          SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Boxing Gloves',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Classification',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: const Color(0xFFFF7043),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Identify boxing gloves with AI-powered image recognition',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
                const Spacer(flex: 1),
                // "Let's Scan" button
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ScannerPage(),
                        ),
                      );
                    },
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            kPrimaryColor,
                            kPrimaryColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryColor.withOpacity(0.6),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Let's Scan",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                const SizedBox(height: 8),
                // Condiment cards section
                Container(
                  padding: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'Boxing Gloves',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 230,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: const [
                            _CondimentCard(
                              title: '1. Cleto Reyes',
                              description:
                                  'Premium Mexican-made boxing gloves used by many professionals.',
                              imagePath: 'assets/images/Brands_images/cleto reyes.jpg',
                              color: Color(0xFFB71C1C),
                            ),
                            _CondimentCard(
                              title: '2. Venum',
                              description:
                                  'Popular training and sparring gloves for boxers and MMA athletes.',
                              imagePath: 'assets/images/Brands_images/venum.jpg',
                              color: Color(0xFF1E88E5),
                            ),
                            _CondimentCard(
                              title: '3. Winning',
                              description:
                                  'High-end Japanese boxing gloves known for protection and comfort.',
                              imagePath: 'assets/images/Brands_images/winning.jpg',
                              color: Color(0xFF424242),
                            ),
                            _CondimentCard(
                              title: '4. Rival',
                              description:
                                  'Performance gloves designed for both pros and amateurs.',
                              imagePath: 'assets/images/Brands_images/rival.jpg',
                              color: Color(0xFFFFA000),
                            ),
                            _CondimentCard(
                              title: '5. Everlast',
                              description:
                                  'Classic boxing brand with gloves used in gyms worldwide.',
                              imagePath: 'assets/images/Brands_images/everlast.jpg',
                              color: Color(0xFF2E7D32),
                            ),
                            _CondimentCard(
                              title: '6. Twins Special',
                              description:
                                  'Thai-made gloves great for boxing, Muay Thai, and kickboxing.',
                              imagePath: 'assets/images/Brands_images/twins special (2).jpg',
                              color: Color(0xFF6A1B9A),
                            ),
                            _CondimentCard(
                              title: '7. Hayabusa',
                              description:
                                  'Modern gloves featuring advanced wrist support and padding.',
                              imagePath: 'assets/images/Brands_images/hayabusa.jpg',
                              color: Color(0xFF00897B),
                            ),
                            _CondimentCard(
                              title: '8. Grant Worldwide',
                              description:
                                  'Premium, often custom-made professional boxing gloves.',
                              imagePath: 'assets/images/Brands_images/grant worldwide.jpg',
                              color: Color(0xFF5D4037),
                            ),
                            _CondimentCard(
                              title: '9. Fairtex',
                              description:
                                  'High quality Thai gloves widely used for training and sparring.',
                              imagePath: 'assets/images/Brands_images/fairtex.jpg',
                              color: Color(0xFFF4511E),
                            ),
                            _CondimentCard(
                              title: '10. Fly',
                              description:
                                  'Luxury UK-made boxing gloves with a sleek design.',
                              imagePath: 'assets/images/Brands_images/fly.jpg',
                              color: Color(0xFF546E7A),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CondimentCard extends StatelessWidget {
  final String title;
  final String description;
  final String imagePath;
  final Color color;
  final Color textColor;

  const _CondimentCard({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.color,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image on top with padding
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imagePath,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 110,
                  color: color.withOpacity(0.3),
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ),
          // Text below with padding
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withOpacity(0.85),
                          ),
                    ),
                  ),
                ],
              ),
                ),
          ),
        ],
      ),
    );
  }
}



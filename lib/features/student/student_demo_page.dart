import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentDemoPage extends ConsumerStatefulWidget {
  const StudentDemoPage({super.key});

  @override
  ConsumerState<StudentDemoPage> createState() => _StudentDemoPageState();
}

class _StudentDemoPageState extends ConsumerState<StudentDemoPage> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markDemoAsComplete() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirestoreService().updateUserProfile(
          userId,
          {'demoViewed': true},
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error marking demo as complete: $e');
    }
  }

  void _goToNextPage() {
    if (_currentPage < _demoSlides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _markDemoAsComplete();
    }
  }

  void _skipDemo() {
    _markDemoAsComplete();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: _demoSlides
                .map((slide) => _buildDemoSlide(slide, scheme, context))
                .toList(),
          ),
          // Top-right Skip button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: TextButton(
              onPressed: _skipDemo,
              child: const Text('Skip'),
            ),
          ),
          // Bottom navigation
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomNavigation(scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoSlide(
      DemoSlide slide, ColorScheme scheme, BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.1),
              scheme.secondary.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon/Illustration
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.15),
                ),
                child: Icon(
                  slide.icon,
                  size: 60,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                slide.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 24),
              // Feature list (if available)
              if (slide.features.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: scheme.surface,
                    border: Border.all(
                        color: scheme.outline.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: slide.features
                        .map((feature) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: scheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurface,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        children: [
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _demoSlides.length,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  width: index == _currentPage ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: index == _currentPage
                        ? scheme.primary
                        : scheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Buttons
          Row(
            children: [
              // Back button (only if not first slide)
              if (_currentPage > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text('Back'),
                  ),
                ),
              if (_currentPage > 0) const SizedBox(width: 12),
              // Next or Finish button
              Expanded(
                child: FilledButton(
                  onPressed: _goToNextPage,
                  child: Text(
                    _currentPage == _demoSlides.length - 1 ? 'Finish' : 'Next',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static final List<DemoSlide> _demoSlides = [
    DemoSlide(
      icon: Icons.trending_up,
      title: 'Welcome to PutraMate',
      description:
          'Your personal mental wellness companion at UPM. Track your mood, connect with counsellors, and build a healthier you.',
      features: [
        'Track daily mood and emotions',
        'Connect with professional counsellors',
        'Join community support groups',
      ],
    ),
    DemoSlide(
      icon: Icons.sentiment_satisfied_alt,
      title: 'Mood Tracking',
      description:
          'Monitor your emotional well-being with our easy mood tracking feature. Visualize your emotional patterns over time.',
      features: [
        'Log mood entries daily',
        'View mood trends and patterns',
        'Identify emotional triggers',
        'Get personalized insights',
      ],
    ),
    DemoSlide(
      icon: Icons.person,
      title: 'Book a Counsellor',
      description:
          'Connect with qualified mental health professionals. Browse available counsellors and schedule sessions that work for you.',
      features: [
        'Browse counsellor profiles',
        'View availability and specialties',
        'Book appointments instantly',
        'Get session reminders',
      ],
    ),
    DemoSlide(
      icon: Icons.forum,
      title: 'Community Support',
      description:
          'Share your experiences and support others in our moderated community forum. You\'re not alone in this journey.',
      features: [
        'Share and discuss experiences',
        'Get peer support',
        'Access moderated discussions',
      ],
    ),
    DemoSlide(
      icon: Icons.chat_bubble,
      title: 'AI Chatbot Support',
      description:
          'Get instant mental wellness tips and guidance from our AI-powered chatbot available 24/7.',
      features: [
        'Chat anytime, anywhere',
        'Get wellness recommendations',
        'Resource library access',
      ],
    ),
    DemoSlide(
      icon: Icons.celebration,
      title: 'You\'re All Set!',
      description:
          'You\'re ready to start your mental wellness journey. Remember, taking care of your mental health is important.',
      features: [
        'Explore at your own pace',
        'Reach out for help anytime',
        'Be kind to yourself',
      ],
    ),
  ];
}

class DemoSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<String> features;

  DemoSlide({
    required this.icon,
    required this.title,
    required this.description,
    this.features = const [],
  });
}

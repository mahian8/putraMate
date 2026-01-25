import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentDemoModal extends ConsumerStatefulWidget {
  const StudentDemoModal({super.key});

  @override
  ConsumerState<StudentDemoModal> createState() => _StudentDemoModalState();
}

class _StudentDemoModalState extends ConsumerState<StudentDemoModal>
    with TickerProviderStateMixin {
  String? _selectedFeature;
  late AnimationController _typewriterController;
  int _currentIndex = 0;

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

  List<Map<String, dynamic>> _getFeatures() {
    return [
      {
        'id': 'mood',
        'icon': Icons.sentiment_satisfied_alt,
        'title': 'Mood Tracking',
      },
      {
        'id': 'counsellor',
        'icon': Icons.person,
        'title': 'Book Counsellor',
      },
      {
        'id': 'community',
        'icon': Icons.forum,
        'title': 'Community',
      },
      {
        'id': 'chatbot',
        'icon': Icons.chat_bubble,
        'title': 'AI Chatbot',
      },
      {
        'id': 'appointments',
        'icon': Icons.schedule,
        'title': 'Appointments',
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _typewriterController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    final features = _getFeatures();
    if (features.isNotEmpty) {
      _selectedFeature = features.first['id'];
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _startTypewriterAnimation());
    }
  }

  @override
  void dispose() {
    _typewriterController.dispose();
    super.dispose();
  }

  void _startTypewriterAnimation() {
    _typewriterController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final features = _getFeatures();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    scheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Welcome to PutraMate',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    onPressed: _markDemoAsComplete,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Guide - Tap any button to learn more',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    // Feature list buttons (compact)
                    Expanded(
                      child: ListView.separated(
                        itemCount: features.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final feature = features[index];
                          final isSelected = _selectedFeature == feature['id'];

                          return GestureDetector(
                            onTap: () {
                              if (isSelected) return;
                              setState(() {
                                _currentIndex = index;
                                _selectedFeature = feature['id'];
                              });
                              _startTypewriterAnimation();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? scheme.primary.withValues(alpha: 0.12)
                                    : scheme.surfaceContainerHighest,
                                border: Border.all(
                                  color: isSelected
                                      ? scheme.primary
                                      : scheme.outline.withValues(alpha: 0.2),
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    feature['icon'],
                                    size: 20,
                                    color: isSelected
                                        ? scheme.primary
                                        : scheme.onSurface,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      feature['title'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontSize: 12,
                                            color: isSelected
                                                ? scheme.primary
                                                : scheme.onSurface,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.chevron_right,
                                    size: 18,
                                    color: isSelected
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Details section
                    if (_selectedFeature != null)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getFeatureIcon(_selectedFeature!),
                                      color: scheme.primary,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _getFeatureTitle(_selectedFeature!),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: scheme.primary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                AnimatedBuilder(
                                  animation: _typewriterController,
                                  builder: (context, child) {
                                    final fullText = _getFeatureDescription(
                                        _selectedFeature!);
                                    final charCount = (fullText.length *
                                            _typewriterController.value)
                                        .toInt();
                                    final displayText = fullText.substring(
                                        0, charCount.clamp(0, fullText.length));
                                    return Text(
                                      displayText,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurface,
                                            height: 1.7,
                                            fontSize: 13,
                                          ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        scheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '✨ Key Benefits:',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: scheme.primary,
                                              fontSize: 13,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      ..._getFeatureBenefits(_selectedFeature!)
                                          .map((benefit) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 6),
                                                child: Text(
                                                  '• $benefit',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme.onSurface,
                                                        fontSize: 12,
                                                      ),
                                                ),
                                              )),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Footer buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _markDemoAsComplete,
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final features = _getFeatures();
                        if (features.isEmpty) {
                          _markDemoAsComplete();
                          return;
                        }
                        if (_currentIndex < features.length - 1) {
                          setState(() {
                            _currentIndex++;
                            _selectedFeature = features[_currentIndex]['id'];
                          });
                          _startTypewriterAnimation();
                        } else {
                          _markDemoAsComplete();
                        }
                      },
                      child: Text(
                        _currentIndex < _getFeatures().length - 1
                            ? 'Next'
                            : 'Finish',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFeatureTitle(String featureId) {
    switch (featureId) {
      case 'mood':
        return 'Mood Tracking';
      case 'counsellor':
        return 'Book a Counsellor';
      case 'community':
        return 'Community Support';
      case 'chatbot':
        return 'AI Chatbot';
      case 'appointments':
        return 'My Appointments';
      default:
        return '';
    }
  }

  IconData _getFeatureIcon(String featureId) {
    switch (featureId) {
      case 'mood':
        return Icons.sentiment_satisfied_alt;
      case 'counsellor':
        return Icons.person;
      case 'community':
        return Icons.forum;
      case 'chatbot':
        return Icons.chat_bubble;
      case 'appointments':
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }

  String _getFeatureDescription(String featureId) {
    switch (featureId) {
      case 'mood':
        return 'Open Mood Tracking to log how you feel each day, spot patterns, and see charts of your ups and downs. Use it before/after classes to find triggers and share trends with your counsellor when you need support. Try pinning a quick entry right after a tough lecture so you can compare later.';
      case 'counsellor':
        return 'Go to Book a Counsellor to browse real UPM counsellors, view their bios and slots, then pick a time that fits you. You can reschedule from here and see exactly where to join your session. Tap any profile card to read their approach and choose the time that matches your schedule.';
      case 'community':
        return 'Visit Community to read discussions, ask questions, and reply to peers in a moderated, student-only space. Follow threads that matter to you and discover tips others use to cope. Start with the top “What’s trending” posts to see what other students are talking about today.';
      case 'chatbot':
        return 'Tap AI Chatbot for instant answers 24/7. Ask how to calm anxiety, get quick breathing exercises, or ask where to find a counsellor slot—the bot guides you step by step at any hour. If you’re stuck, type “help” and it will list popular prompts to try.';
      case 'appointments':
        return 'Open Appointments to see every session you have booked, with dates, times, and join instructions. Set reminders, check location/online links, and keep your progress notes together. Tap any session to view details or to move it to a time that better suits you.';
      default:
        return '';
    }
  }

  List<String> _getFeatureBenefits(String featureId) {
    switch (featureId) {
      case 'mood':
        return [
          'Understand your emotional patterns',
          'Identify stress triggers',
          'Track improvements over time',
          'Share insights with counsellor',
        ];
      case 'counsellor':
        return [
          'Professional mental health support',
          'Flexible scheduling',
          'Private and confidential',
          'Expert guidance for your challenges',
        ];
      case 'community':
        return [
          'Peer support from real students',
          'Safe and moderated environment',
          'Share and get advice',
          'Reduce feelings of isolation',
        ];
      case 'chatbot':
        return [
          'Instant support anytime',
          'No waiting for appointments',
          'Coping strategies and tips',
          'Mental wellness resources',
        ];
      case 'appointments':
        return [
          'Never miss your sessions',
          'Get appointment reminders',
          'Track your progress',
          'Easy to reschedule',
        ];
      default:
        return [];
    }
  }
}

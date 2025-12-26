import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/mood_entry.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../common/common_widgets.dart';

final firestoreServiceProvider = Provider((ref) => FirestoreService());
final geminiServiceProvider = Provider((ref) => GeminiService());

class MoodChartPage extends ConsumerStatefulWidget {
  const MoodChartPage({super.key});

  @override
  ConsumerState<MoodChartPage> createState() => _MoodChartPageState();
}

class _MoodChartPageState extends ConsumerState<MoodChartPage> {
  int _selectedMood = 3; // Default to neutral
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  // Mood options with emojis and labels
  final List<Map<String, dynamic>> _moods = [
    {'emoji': '😄', 'label': 'Amazing', 'score': 5, 'color': Colors.green},
    {'emoji': '😊', 'label': 'Good', 'score': 4, 'color': Colors.lightGreen},
    {'emoji': '😐', 'label': 'Neutral', 'score': 3, 'color': Colors.orange},
    {'emoji': '😕', 'label': 'Not Great', 'score': 2, 'color': Colors.deepOrange},
    {'emoji': '😢', 'label': 'Struggling', 'score': 1, 'color': Colors.red},
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitMood() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final note = _noteController.text.trim();
      
      // Analyze sentiment
      Map<String, dynamic> sentiment = {};
      if (note.isNotEmpty) {
        final gemini = ref.read(geminiServiceProvider);
        sentiment = await gemini.analyzeSentiment(note);
      }

      final entry = MoodEntry(
        id: '',
        userId: user.uid,
        moodScore: _selectedMood,
        note: note,
        timestamp: DateTime.now(),
        sentiment: sentiment['sentiment'] as String?,
        riskLevel: sentiment['riskLevel'] as String?,
        flaggedForCounsellor: (sentiment['riskLevel'] == 'high' || 
                               sentiment['riskLevel'] == 'critical'),
      );

      await ref.read(firestoreServiceProvider).addMoodEntry(entry);

      // Flag low moods or concerning sentiment to counsellors
      if ((_selectedMood <= 2) || 
          (sentiment['riskLevel'] == 'high' || sentiment['riskLevel'] == 'critical')) {
        final profile = ref.read(userProfileProvider).value;
        if (profile != null) {
          await ref.read(firestoreServiceProvider).flagHighRiskStudent(
            studentId: user.uid,
            studentName: profile.displayName,
            riskLevel: sentiment['riskLevel'] ?? 'medium',
            sentiment: sentiment['sentiment'] ?? 'concerning',
            message: 'Mood: ${_moods.firstWhere((m) => m['score'] == _selectedMood)['label']}. Note: $note',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              entry.flaggedForCounsellor
                  ? 'Mood logged. A counsellor may reach out to support you.'
                  : 'Mood logged successfully!',
            ),
          ),
        );
        setState(() {
          _noteController.clear();
          _selectedMood = 3; // Reset to neutral
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Color _getMoodColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.lightGreen;
    if (score >= 4) return Colors.orange;
    return Colors.red;
  }

  Map<int, int> _calculateMoodDistribution(List<MoodEntry> entries) {
    final distribution = <int, int>{};
    for (var entry in entries) {
      distribution[entry.moodScore] = (distribution[entry.moodScore] ?? 0) + 1;
    }
    return distribution;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    
    if (user == null) {
      return const PrimaryScaffold(
        title: 'Mood Tracker',
        body: Center(child: Text('Please sign in')),
      );
    }

    final moodStream = ref.watch(firestoreServiceProvider).moodEntries(user.uid);

    return PrimaryScaffold(
      title: 'Mood Tracker',
      body: StreamBuilder<List<MoodEntry>>(
        stream: moodStream,
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];
          
          return ListView(
            children: [
              // Log New Mood
              SectionCard(
                title: 'How are you feeling right now?',
                trailing: Icon(
                  Icons.notifications_active,
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  children: [
                    const Text(
                      'Select your mood:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: _moods.map((mood) {
                        final isSelected = _selectedMood == mood['score'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedMood = mood['score'] as int),
                          child: Container(
                            width: 80,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (mood['color'] as Color).withValues(alpha: 0.2)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? (mood['color'] as Color)
                                    : Colors.grey[300]!,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  mood['emoji'] as String,
                                  style: TextStyle(
                                    fontSize: isSelected ? 48 : 36,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  mood['label'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? (mood['color'] as Color) : Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'What\'s on your mind? (optional)',
                        hintText: 'Share your thoughts...',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitMood,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isSubmitting ? 'Logging...' : 'Log Mood'),
                    ),
                  ],
                ),
              ),

              // Mood History Chart - Pie Chart
              if (entries.isNotEmpty)
                SectionCard(
                  title: 'Your Mood Distribution',
                  child: Column(
                    children: [
                      if (entries.length < 2)
                        const Center(child: Text('Log more moods to see distribution'))
                      else
                        Column(
                          children: [
                            // Pie chart
                            SizedBox(
                              height: 200,
                              width: 200,
                              child: Center(
                                child: CustomPaint(
                                  size: const Size(200, 200),
                                  painter: _PieChartPainter(
                                    moodCounts: _calculateMoodDistribution(entries.take(30).toList()),
                                    moods: _moods,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Legend
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 16,
                              runSpacing: 8,
                              children: _moods.map((mood) {
                                final count = _calculateMoodDistribution(entries.take(30).toList())[mood['score']] ?? 0;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: mood['color'] as Color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${mood['label']}: $count',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Based on last ${entries.take(30).length} entries',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

              // Recent Entries
              if (entries.isNotEmpty)
                SectionCard(
                  title: 'Recent Entries',
                  child: Column(
                    children: entries.take(5).map((entry) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getMoodColor(entry.moodScore),
                            child: Text(
                              entry.moodScore.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(entry.note.isEmpty ? 'No note' : entry.note),
                          subtitle: Text(DateFormat('MMM d, y h:mm a').format(entry.timestamp)),
                          trailing: entry.flaggedForCounsellor
                              ? Chip(
                                  label: const Text('Flagged', style: TextStyle(fontSize: 10)),
                                  backgroundColor: Colors.orange.shade100,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// Custom Pie Chart Painter
class _PieChartPainter extends CustomPainter {
  final Map<int, int> moodCounts;
  final List<Map<String, dynamic>> moods;

  _PieChartPainter({required this.moodCounts, required this.moods});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.8;
    
    // Calculate total count
    final totalCount = moodCounts.values.fold(0, (a, b) => a + b);
    
    if (totalCount == 0) return;

    double startAngle = -90 * 3.14159 / 180; // Start from top

    for (var mood in moods) {
      final score = mood['score'] as int;
      final count = moodCounts[score] ?? 0;
      
      if (count > 0) {
        final sweepAngle = (count / totalCount) * 2 * 3.14159;
        
        final paint = Paint()
          ..color = mood['color'] as Color
          ..style = PaintingStyle.fill;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          paint,
        );

        // Draw white border
        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          borderPaint,
        );

        // Draw percentage text
        if (count / totalCount > 0.08) {
          final middleAngle = startAngle + sweepAngle / 2;
          final textX = center.dx + radius * 0.6 * cos(middleAngle);
          final textY = center.dy + radius * 0.6 * sin(middleAngle);
          
          final percentage = ((count / totalCount) * 100).toStringAsFixed(0);
          final textSpan = TextSpan(
            text: '$percentage%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          );
          
          final textPainter = TextPainter(
            text: textSpan,
            textAlign: TextAlign.center,
          )..textDirection = ui.TextDirection.ltr;
          
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(textX - textPainter.width / 2, textY - textPainter.height / 2),
          );
        }

        startAngle += sweepAngle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

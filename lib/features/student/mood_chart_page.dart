import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/mood_entry.dart';
import '../../providers/auth_providers.dart';
import '../../router/app_router.dart';
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
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _currentView = 0; // 0: Log, 1: Calendar, 2: Stats

  // Mood options with emojis and labels
  final List<Map<String, dynamic>> _moods = [
    {'emoji': '😄', 'label': 'Amazing', 'score': 5, 'color': Colors.green},
    {'emoji': '😊', 'label': 'Good', 'score': 4, 'color': Colors.lightGreen},
    {'emoji': '😐', 'label': 'Neutral', 'score': 3, 'color': Colors.orange},
    {
      'emoji': '😕',
      'label': 'Not Great',
      'score': 2,
      'color': Colors.deepOrange
    },
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

    final note = _noteController.text.trim();

    // Require note for struggling moods (score 1-2)
    if (_selectedMood <= 2 && note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please explain why you\'re feeling this way. This helps us support you better.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Analyze sentiment with AI, then apply simple keyword fallback
      Map<String, dynamic> sentiment = {};
      if (note.isNotEmpty) {
        final gemini = ref.read(geminiServiceProvider);
        sentiment = await gemini.analyzeSentiment(note);

        // Fallback heuristic if AI returns neutral/low
        if ((sentiment['sentiment'] ?? 'neutral') == 'neutral') {
          final lower = note.toLowerCase();
          final criticalWords = ['suicide', 'kill myself', 'end my life'];
          final highWords = ['hopeless', 'worthless', 'panic', 'panic attack'];
          final mediumWords = [
            'anxious',
            'depressed',
            'sad',
            'lonely',
            'stressed'
          ];

          if (criticalWords.any((w) => lower.contains(w))) {
            sentiment = {
              'sentiment': 'concerning',
              'riskLevel': 'critical',
            };
          } else if (highWords.any((w) => lower.contains(w))) {
            sentiment = {
              'sentiment': 'negative',
              'riskLevel': 'high',
            };
          } else if (mediumWords.any((w) => lower.contains(w))) {
            sentiment = {
              'sentiment': 'negative',
              'riskLevel': 'medium',
            };
          }
        }
      }

      final entry = MoodEntry(
        id: '',
        userId: user.uid,
        moodScore: _selectedMood,
        note: note,
        timestamp: DateTime.now(),
        sentiment: sentiment['sentiment'] as String?,
        riskLevel: sentiment['riskLevel'] as String?,
        flaggedForCounsellor: (_selectedMood <= 2) ||
            (sentiment['riskLevel'] == 'high' ||
                sentiment['riskLevel'] == 'critical'),
      );

      await ref.read(firestoreServiceProvider).addMoodEntry(entry);

      // Flag low moods or concerning sentiment to counsellors
      if ((_selectedMood <= 2) ||
          (sentiment['riskLevel'] == 'high' ||
              sentiment['riskLevel'] == 'critical')) {
        final profile = ref.read(userProfileProvider).value;
        if (profile != null) {
          await ref.read(firestoreServiceProvider).flagHighRiskStudent(
                studentId: user.uid,
                studentName: profile.displayName,
                riskLevel: sentiment['riskLevel'] ?? 'medium',
                sentiment: sentiment['sentiment'] ?? 'concerning',
                message:
                    'Mood: ${_moods.firstWhere((m) => m['score'] == _selectedMood)['label']}. Note: $note',
              );
        }
      }

      if (mounted) {
        if (entry.flaggedForCounsellor) {
          // Show urgent booking suggestion for flagged entries
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Mood logged. A counsellor may reach out to support you.'),
              duration: Duration(seconds: 2),
            ),
          );

          // Show urgent booking dialog
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            _showUrgentBookingDialog(context);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mood logged successfully!')),
          );
        }

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

  void _showUrgentBookingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.priority_high, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Need Support?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We noticed you\'re going through a difficult time. Would you like to book an urgent session with a counsellor?',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Talking to a professional can help',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not Now'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.pushNamed(AppRoute.booking.name);
              },
              icon: const Icon(Icons.calendar_today),
              label: const Text('Book Session'),
            ),
          ],
        );
      },
    );
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

    return PrimaryScaffold(
      title: 'Mood Tracker',
      body: Column(
        children: [
          // View Selector Tabs
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('Log Mood', Icons.add_reaction, 0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton('Calendar', Icons.calendar_month, 1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton('Stats', Icons.bar_chart, 2),
                ),
              ],
            ),
          ),
          Expanded(
            child: _currentView == 0
                ? _buildLogMoodView(user.uid)
                : _currentView == 1
                    ? _buildCalendarView(user.uid)
                    : _buildStatsView(user.uid),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final isActive = _currentView == index;
    return ElevatedButton.icon(
      onPressed: () => setState(() => _currentView = index),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade200,
        foregroundColor: isActive ? Colors.white : Colors.black87,
        elevation: isActive ? 2 : 0,
      ),
    );
  }

  Widget _buildLogMoodView(String userId) {
    final moodStream = ref.watch(firestoreServiceProvider).moodEntries(userId);

    return StreamBuilder<List<MoodEntry>>(
      stream: moodStream,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];

        return ListView(
          children: [
            // Log New Mood
            SectionCard(
              title: 'How are you feeling right now?',
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
                        onTap: () => setState(
                            () => _selectedMood = mood['score'] as int),
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (mood['color'] as Color)
                                    .withValues(alpha: 0.2)
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
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? (mood['color'] as Color)
                                      : Colors.black87,
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
                    decoration: InputDecoration(
                      labelText: _selectedMood <= 2
                          ? 'Please explain why you\'re feeling this way *'
                          : 'What\'s on your mind? (optional)',
                      hintText: 'Share your thoughts...',
                      helperText: _selectedMood <= 2
                          ? 'Required for low mood entries'
                          : null,
                      helperStyle: const TextStyle(color: Colors.orange),
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

            // Recent Entries
            if (entries.isNotEmpty)
              SectionCard(
                title: 'Recent Entries',
                trailing: TextButton(
                  onPressed: () => setState(() => _currentView = 1),
                  child: const Text('View All'),
                ),
                child: Column(
                  children: entries.take(5).map((entry) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getMoodColor(entry.moodScore),
                          child: Text(
                            _moods.firstWhere(
                                (m) => m['score'] == entry.moodScore,
                                orElse: () => {
                                      'emoji': '😐',
                                      'score': 3
                                    })['emoji'] as String,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title:
                            Text(entry.note.isEmpty ? 'No note' : entry.note),
                        subtitle: Text(DateFormat('MMM d, y h:mm a')
                            .format(entry.timestamp)),
                        trailing: entry.flaggedForCounsellor
                            ? Chip(
                                label: const Text('Flagged',
                                    style: TextStyle(fontSize: 10)),
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
    );
  }

  Widget _buildCalendarView(String userId) {
    return StreamBuilder<List<MoodEntry>>(
      stream: _getMoodEntriesForMonth(userId, _focusedDay),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = snapshot.data ?? [];

        // Group entries by day for calendar markers
        final Map<DateTime, List<MoodEntry>> eventsByDay = {};
        for (final entry in entries) {
          final key = DateTime(
            entry.timestamp.year,
            entry.timestamp.month,
            entry.timestamp.day,
          );
          eventsByDay.putIfAbsent(key, () => []).add(entry);
        }

        final selectedDayEntries = _selectedDay == null
            ? <MoodEntry>[]
            : eventsByDay[DateTime(_selectedDay!.year, _selectedDay!.month,
                    _selectedDay!.day)] ??
                const <MoodEntry>[];

        return ListView(
          children: [
            SectionCard(
              title:
                  'Mood Calendar - ${DateFormat('MMMM y').format(_focusedDay)}',
              child: Column(
                children: [
                  TableCalendar<MoodEntry>(
                    firstDay: DateTime(2020, 1, 1),
                    lastDay: DateTime.now(),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: (day) {
                      final key = DateTime(day.year, day.month, day.day);
                      return eventsByDay[key] ?? const <MoodEntry>[];
                    },
                    calendarFormat: CalendarFormat.month,
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      setState(() => _focusedDay = focusedDay);
                    },
                    calendarStyle: CalendarStyle(
                      markerDecoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return null;

                        final moodEntries = events.cast<MoodEntry>();
                        final avgMood = moodEntries
                                .map((e) => e.moodScore)
                                .reduce((a, b) => a + b) /
                            moodEntries.length;

                        return Positioned(
                          bottom: 1,
                          child: Container(
                            width: 32,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _getMoodColor(avgMood.round()),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedDay != null) ...[
                    Text(
                      'Entries for ${DateFormat('MMMM d, y').format(_selectedDay!)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (selectedDayEntries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No mood entries for this day'),
                      )
                    else
                      ...selectedDayEntries.map((entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getMoodColor(entry.moodScore),
                                child: Text(
                                  _moods.firstWhere(
                                      (m) => m['score'] == entry.moodScore,
                                      orElse: () => {
                                            'emoji': '😐',
                                            'score': 3
                                          })['emoji'] as String,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                              title: Text(
                                  entry.note.isEmpty ? 'No note' : entry.note),
                              subtitle: Text(
                                  DateFormat('h:mm a').format(entry.timestamp)),
                              trailing: entry.flaggedForCounsellor
                                  ? const Icon(Icons.flag, color: Colors.orange)
                                  : null,
                            ),
                          )),
                  ] else
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Select a day to view entries'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsView(String userId) {
    return StreamBuilder<List<MoodEntry>>(
      stream: _getMoodEntriesForMonth(userId, _focusedDay),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = snapshot.data ?? [];

        return ListView(
          children: [
            // Month selector
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(
                          _focusedDay.year,
                          _focusedDay.month - 1,
                        );
                      });
                    },
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_focusedDay),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _focusedDay.month == DateTime.now().month &&
                            _focusedDay.year == DateTime.now().year
                        ? null
                        : () {
                            setState(() {
                              _focusedDay = DateTime(
                                _focusedDay.year,
                                _focusedDay.month + 1,
                              );
                            });
                          },
                  ),
                ],
              ),
            ),

            // Mood Distribution Pie Chart
            if (entries.isNotEmpty)
              SectionCard(
                title: 'Mood Distribution',
                child: Column(
                  children: [
                    if (entries.length < 2)
                      const Center(
                          child: Text('Log more moods to see distribution'))
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
                                  moodCounts:
                                      _calculateMoodDistribution(entries),
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
                              final count = _calculateMoodDistribution(
                                      entries)[mood['score']] ??
                                  0;
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
                      'Based on ${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            else
              const SectionCard(
                title: 'Mood Distribution',
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No mood entries for this month'),
                  ),
                ),
              ),

            // Average Mood Score
            if (entries.isNotEmpty)
              SectionCard(
                title: 'Monthly Summary',
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          'Total Entries',
                          entries.length.toString(),
                          Icons.note,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'Avg Mood',
                          (entries
                                      .map((e) => e.moodScore)
                                      .reduce((a, b) => a + b) /
                                  entries.length)
                              .toStringAsFixed(1),
                          Icons.mood,
                          Colors.green,
                        ),
                        _buildStatCard(
                          'Flagged',
                          entries
                              .where((e) => e.flaggedForCounsellor)
                              .length
                              .toString(),
                          Icons.flag,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // Stream that loads mood entries for a specific month (optimized for large datasets)
  Stream<List<MoodEntry>> _getMoodEntriesForMonth(
      String userId, DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    // Use Firestore directly for month-specific queries
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('moods')
        .where('timestamp',
            isGreaterThanOrEqualTo: startOfMonth.millisecondsSinceEpoch)
        .where('timestamp',
            isLessThanOrEqualTo: endOfMonth.millisecondsSinceEpoch)
        .orderBy('timestamp', descending: true)
        .limit(1000) // Limit to 1000 entries per month for performance
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MoodEntry.fromJson(doc.data(), doc.id))
            .toList());
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
            Offset(
                textX - textPainter.width / 2, textY - textPainter.height / 2),
          );
        }

        startAngle += sweepAngle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

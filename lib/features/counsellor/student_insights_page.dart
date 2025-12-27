import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../providers/auth_providers.dart';
import '../common/common_widgets.dart';

class StudentInsightsPage extends ConsumerWidget {
  const StudentInsightsPage({
    super.key,
    required this.studentId,
    required this.counsellorId,
    this.studentName,
  });

  final String studentId;
  final String counsellorId;
  final String? studentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);

    // If we somehow navigated without IDs, show a friendly message.
    if (studentId.isEmpty || counsellorId.isEmpty) {
      return PrimaryScaffold(
        title: 'Student insights',
        body: const Center(
            child: Text('Missing student or counsellor information')),
      );
    }

    // Fetch mood entries and risk flags for sentiment analysis
    final moodStream = fs.moodEntries(studentId);
    final riskFlagsStream = fs.highRiskFlags(studentId);

    return PrimaryScaffold(
      title:
          studentName == null ? 'Student insights' : 'Insights • $studentName',
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ],
      body: StreamBuilder<List<Appointment>>(
        stream: fs.appointmentsForStudentAndCounsellor(
          studentId: studentId,
          counsellorId: counsellorId,
        ),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Text('Unable to load insights: ${snap.error}'),
            );
          }

          final appointments = snap.data ?? [];

          // Separate lists: booking history and comments/notes
          final bookingHistory = appointments
              .where((a) =>
                  a.status == AppointmentStatus.completed ||
                  a.status == AppointmentStatus.cancelled ||
                  a.status == AppointmentStatus.confirmed)
              .toList()
            ..sort((a, b) => b.start.compareTo(a.start));

          final comments = appointments
              .where((a) =>
                  (a.studentComment != null && a.studentComment!.isNotEmpty) ||
                  (a.counsellorNotes != null && a.counsellorNotes!.isNotEmpty))
              .toList()
            ..sort((a, b) => b.start.compareTo(a.start));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Mood Tracking Section
              StreamBuilder(
                stream: moodStream,
                builder: (context, moodSnap) {
                  final moods = moodSnap.data ?? [];

                  if (moods.isEmpty) {
                    return SectionCard(
                      title: 'Mood Tracking',
                      trailing: const Icon(Icons.mood, color: Colors.grey),
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No mood entries yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  }

                  final recentMoods = moods.take(10).toList();
                  final concerningMoods = recentMoods
                      .where((m) =>
                          m.moodScore <= 2 ||
                          m.riskLevel == 'high' ||
                          m.riskLevel == 'critical')
                      .toList();

                  return SectionCard(
                    title: 'Mood Tracking',
                    trailing: concerningMoods.isNotEmpty
                        ? const Icon(Icons.warning, color: Colors.red)
                        : const Icon(Icons.check_circle, color: Colors.green),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Aggregated mood bar chart (last 7 days)
                        MoodBarChart(entries: recentMoods, days: 7),
                        const SizedBox(height: 12),
                        if (concerningMoods.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning,
                                    color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${concerningMoods.length} concerning mood ${concerningMoods.length == 1 ? "entry" : "entries"} detected',
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Horizontal scroller of recent mood entries
                        SizedBox(
                          height: 120,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: recentMoods.map((mood) {
                                final score = mood.moodScore;
                                final timestamp = mood.timestamp;
                                final riskLevel = mood.riskLevel;
                                final isFlagged = mood.flaggedForCounsellor;

                                final bgColor = isFlagged
                                    ? Colors.red.shade50
                                    : Colors.grey.shade100;
                                final circleColor = score <= 2
                                    ? Colors.red
                                    : score <= 3
                                        ? Colors.orange
                                        : Colors.green;

                                return Container(
                                  width: 140,
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isFlagged
                                          ? Colors.red.shade200
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: circleColor,
                                            child: Text(
                                              score.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (riskLevel == 'high' ||
                                              riskLevel == 'critical')
                                            const Icon(Icons.warning,
                                                color: Colors.red, size: 18)
                                          else
                                            const Icon(Icons.check_circle,
                                                color: Colors.green, size: 18),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        DateFormat('MMM d').format(timestamp),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('h:mm a').format(timestamp),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Risk Flags Section
              StreamBuilder<List<dynamic>>(
                stream: riskFlagsStream,
                builder: (context, flagSnap) {
                  final flags = flagSnap.data ?? [];

                  if (flags.isEmpty) {
                    return SectionCard(
                      title: 'Sentiment Analysis Alerts',
                      trailing:
                          const Icon(Icons.check_circle, color: Colors.green),
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No high-risk alerts',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  }

                  return SectionCard(
                    title: 'Sentiment Analysis Alerts',
                    trailing: const Icon(Icons.warning, color: Colors.red),
                    child: Column(
                      children: flags.take(5).map((flag) {
                        final sentiment =
                            flag['sentiment'] as String? ?? 'Unknown';
                        final riskLevel =
                            flag['riskLevel'] as String? ?? 'medium';
                        final message = flag['lastMessage'] as String? ?? '';
                        final flaggedAt = DateTime.fromMillisecondsSinceEpoch(
                            (flag['flaggedAt'] as num?)?.toInt() ?? 0);
                        final resolved = flag['resolved'] as bool? ?? false;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: resolved
                              ? Colors.grey.shade100
                              : Colors.red.shade50,
                          child: ListTile(
                            leading: Icon(
                              resolved ? Icons.check_circle : Icons.warning,
                              color: resolved ? Colors.grey : Colors.red,
                            ),
                            title: Text(
                              '$sentiment (Risk: $riskLevel)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: resolved
                                    ? Colors.grey
                                    : Colors.red.shade900,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(message),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM d, y h:mm a')
                                      .format(flaggedAt),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            trailing: resolved
                                ? const Chip(
                                    label: Text('Resolved',
                                        style: TextStyle(fontSize: 10)),
                                    backgroundColor: Colors.grey,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Booking history',
                child: bookingHistory.isEmpty
                    ? const Text('No past bookings yet')
                    : Column(
                        children: bookingHistory
                            .map((a) => ListTile(
                                  leading: Icon(
                                    a.status == AppointmentStatus.completed
                                        ? Icons.check_circle
                                        : a.status ==
                                                AppointmentStatus.cancelled
                                            ? Icons.cancel
                                            : Icons.event,
                                    color:
                                        a.status == AppointmentStatus.completed
                                            ? Colors.green
                                            : a.status ==
                                                    AppointmentStatus.cancelled
                                                ? Colors.red
                                                : Colors.blue,
                                  ),
                                  title: Text(
                                      '${DateFormat('EEE, MMM d, yyyy').format(a.start)}'),
                                  subtitle: Text(
                                      '${DateFormat('hh:mm a').format(a.start)} - ${DateFormat('hh:mm a').format(a.end)} • ${a.topic ?? 'Session'}'),
                                  trailing: Text(a.status.name),
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Past comments & notes',
                child: comments.isEmpty
                    ? const Text('No comments or notes yet')
                    : Column(
                        children: comments
                            .map((a) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('MMM d, yyyy • hh:mm a')
                                              .format(a.start),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        if (a.studentRating != null)
                                          Text(
                                              'Student rating: ${a.studentRating}/5'),
                                        if (a.studentComment != null &&
                                            a.studentComment!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          const Text('Student comment:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          Text(a.studentComment!),
                                        ],
                                        if (a.counsellorNotes != null &&
                                            a.counsellorNotes!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          const Text('Counsellor note:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          Text(a.counsellorNotes!),
                                        ],
                                      ],
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MoodBarChart extends StatelessWidget {
  const MoodBarChart({
    super.key,
    required this.entries,
    this.days = 7,
  });

  final List<dynamic> entries; // List<MoodEntry>
  final int days;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    // Normalize to last `days` dates
    final now = DateTime.now();
    final dates = List.generate(days, (i) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: days - 1 - i));
      return DateTime(d.year, d.month, d.day);
    });

    // Aggregate average mood per day
    final Map<int, List<int>> moodsByDayIndex = {
      for (var i = 0; i < days; i++) i: <int>[],
    };

    for (final e in entries) {
      final ts = (e.timestamp as DateTime);
      final day = DateTime(ts.year, ts.month, ts.day);
      final idx = dates.indexWhere((d) => d == day);
      if (idx != -1) {
        moodsByDayIndex[idx]!.add(e.moodScore as int);
      }
    }

    final avgScores = List<double>.generate(days, (i) {
      final list = moodsByDayIndex[i]!;
      if (list.isEmpty) return 0.0;
      return list.reduce((a, b) => a + b) / list.length;
    });

    // Chart rendering
    const double chartHeight = 120;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(days, (i) {
              final score = avgScores[i];
              final barHeight = score <= 0 ? 4.0 : (score / 10.0) * chartHeight;
              final color = _colorForScore(score);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(days, (i) {
            final label =
                i == days - 1 ? 'Today' : DateFormat('EEE').format(dates[i]);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: const [
            _LegendDot(color: Colors.green, label: 'Positive'),
            _LegendDot(color: Colors.orange, label: 'Neutral'),
            _LegendDot(color: Colors.red, label: 'Negative'),
          ],
        ),
      ],
    );
  }

  Color _colorForScore(double score) {
    if (score >= 7.5) return Colors.green;
    if (score >= 4.5) return Colors.orange;
    if (score > 0) return Colors.red;
    return Colors.grey.shade300; // No data
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
      ],
    );
  }
}

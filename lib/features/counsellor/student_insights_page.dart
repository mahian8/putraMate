import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/appointment.dart';
import '../../providers/auth_providers.dart';
import '../../router/app_router.dart';
import '../common/common_widgets.dart';

class StudentInsightsPage extends ConsumerStatefulWidget {
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
  ConsumerState<StudentInsightsPage> createState() =>
      _StudentInsightsPageState();
}

class _StudentInsightsPageState extends ConsumerState<StudentInsightsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.studentId.isEmpty || widget.counsellorId.isEmpty) {
      return PrimaryScaffold(
        title: 'Student Insights',
        body: const Center(
            child: Text('Missing student or counsellor information')),
      );
    }

    return PrimaryScaffold(
      title: widget.studentName == null
          ? 'Student Insights'
          : 'Insights • ${widget.studentName}',
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
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: false,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.event), text: 'Sessions'),
              Tab(icon: Icon(Icons.mood), text: 'Mood & Risk'),
              Tab(icon: Icon(Icons.comment), text: 'Notes'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(
                    studentId: widget.studentId,
                    counsellorId: widget.counsellorId),
                _SessionsTab(
                    studentId: widget.studentId,
                    counsellorId: widget.counsellorId),
                _MoodStatsTab(studentId: widget.studentId),
                _NotesTab(
                    studentId: widget.studentId,
                    counsellorId: widget.counsellorId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Overview Tab - Summary statistics
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.studentId, required this.counsellorId});

  final String studentId;
  final String counsellorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);

    return StreamBuilder<List<Appointment>>(
      stream: fs.appointmentsForStudentAndCounsellor(
        studentId: studentId,
        counsellorId: counsellorId,
      ),
      builder: (context, appointmentSnap) {
        final allAppointments = appointmentSnap.data ?? [];
        final completedSessions = allAppointments
            .where((a) => a.status == AppointmentStatus.completed)
            .length;
        final upcomingSessions = allAppointments
            .where((a) => a.start.isAfter(DateTime.now()))
            .length;
        final cancelledSessions = allAppointments
            .where((a) => a.status == AppointmentStatus.cancelled)
            .length;

        return StreamBuilder(
          stream: fs.moodEntries(studentId),
          builder: (context, moodSnap) {
            final moods = moodSnap.data ?? [];
            final avgMood = moods.isEmpty
                ? 0.0
                : moods
                        .take(30)
                        .map((m) => m.moodScore)
                        .reduce((a, b) => a + b) /
                    moods.take(30).length;

            // Get flagged moods instead of sentiment flags
            final flaggedMoods =
                moods.where((m) => m.flaggedForCounsellor).toList();

            return SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Summary Cards
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                          children: [
                            _StatCard(
                              title: 'Total Sessions',
                              value: allAppointments.length.toString(),
                              icon: Icons.event,
                              color: Colors.blue,
                            ),
                            _StatCard(
                              title: 'Completed',
                              value: completedSessions.toString(),
                              icon: Icons.check_circle,
                              color: Colors.green,
                            ),
                            _StatCard(
                              title: 'Avg Mood (30d)',
                              value: avgMood.toStringAsFixed(1),
                              icon: Icons.mood,
                              color: avgMood >= 7
                                  ? Colors.green
                                  : avgMood >= 5
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                            _StatCard(
                              title: 'Flagged Moods',
                              value: flaggedMoods.length.toString(),
                              icon: Icons.warning,
                              color: flaggedMoods.isNotEmpty
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Recent Activity
                        SectionCard(
                          title: 'Recent Activity',
                          child: Column(
                            children: [
                              if (upcomingSessions > 0)
                                ListTile(
                                  leading: const Icon(Icons.upcoming,
                                      color: Colors.blue),
                                  title: Text(
                                      '$upcomingSessions upcoming session${upcomingSessions == 1 ? '' : 's'}'),
                                ),
                              if (moods.isNotEmpty)
                                ListTile(
                                  leading: const Icon(Icons.timeline,
                                      color: Colors.purple),
                                  title: Text(
                                      '${moods.length} mood entries logged'),
                                  subtitle: Text(
                                      'Latest: ${DateFormat('MMM d, h:mm a').format(moods.first.timestamp)}'),
                                ),
                              if (cancelledSessions > 0)
                                ListTile(
                                  leading: const Icon(Icons.cancel,
                                      color: Colors.orange),
                                  title: Text(
                                      '$cancelledSessions cancelled session${cancelledSessions == 1 ? '' : 's'}'),
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
          },
        );
      },
    );
  }
}

// Sessions Tab
class _SessionsTab extends ConsumerStatefulWidget {
  const _SessionsTab({required this.studentId, required this.counsellorId});

  final String studentId;
  final String counsellorId;

  @override
  ConsumerState<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends ConsumerState<_SessionsTab> {
  String _filter = 'All';
  String _timeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final fs = ref.watch(firestoreServiceProvider);

    return StreamBuilder<List<Appointment>>(
      stream: fs.appointmentsForStudentAndCounsellor(
        studentId: widget.studentId,
        counsellorId: widget.counsellorId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var sessions = snapshot.data!;

        if (_filter == 'Completed') {
          sessions = sessions
              .where((s) => s.status == AppointmentStatus.completed)
              .toList();
        } else if (_filter == 'Cancelled') {
          sessions = sessions
              .where((s) => s.status == AppointmentStatus.cancelled)
              .toList();
        } else if (_filter == 'Upcoming') {
          sessions =
              sessions.where((s) => s.start.isAfter(DateTime.now())).toList();
        }

        if (_timeFilter == 'This Week') {
          final weekAgo = DateTime.now().subtract(const Duration(days: 7));
          sessions = sessions.where((s) => s.start.isAfter(weekAgo)).toList();
        } else if (_timeFilter == 'This Month') {
          final monthAgo = DateTime.now().subtract(const Duration(days: 30));
          sessions = sessions.where((s) => s.start.isAfter(monthAgo)).toList();
        } else if (_timeFilter == 'Last 3 Months') {
          final threeMonthsAgo =
              DateTime.now().subtract(const Duration(days: 90));
          sessions =
              sessions.where((s) => s.start.isAfter(threeMonthsAgo)).toList();
        }

        sessions.sort((a, b) => b.start.compareTo(a.start));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _filter == 'All',
                        onSelected: (_) => setState(() => _filter = 'All'),
                      ),
                      FilterChip(
                        label: const Text('Completed'),
                        selected: _filter == 'Completed',
                        onSelected: (_) =>
                            setState(() => _filter = 'Completed'),
                      ),
                      FilterChip(
                        label: const Text('Upcoming'),
                        selected: _filter == 'Upcoming',
                        onSelected: (_) => setState(() => _filter = 'Upcoming'),
                      ),
                      FilterChip(
                        label: const Text('Cancelled'),
                        selected: _filter == 'Cancelled',
                        onSelected: (_) =>
                            setState(() => _filter = 'Cancelled'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All Time'),
                        selected: _timeFilter == 'All',
                        onSelected: (_) => setState(() => _timeFilter = 'All'),
                      ),
                      FilterChip(
                        label: const Text('This Week'),
                        selected: _timeFilter == 'This Week',
                        onSelected: (_) =>
                            setState(() => _timeFilter = 'This Week'),
                      ),
                      FilterChip(
                        label: const Text('This Month'),
                        selected: _timeFilter == 'This Month',
                        onSelected: (_) =>
                            setState(() => _timeFilter = 'This Month'),
                      ),
                      FilterChip(
                        label: const Text('Last 3 Months'),
                        selected: _timeFilter == 'Last 3 Months',
                        onSelected: (_) =>
                            setState(() => _timeFilter = 'Last 3 Months'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Text(
                      '${sessions.length} session${sessions.length == 1 ? '' : 's'}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600])),
                ],
              ),
            ),
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_busy,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No sessions found',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(
                              'Only your sessions with ${widget.studentId} are shown here',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return StreamBuilder(
                          stream: fs.userProfile(session.counsellorId),
                          builder: (context, counsellorSnap) {
                            final counsellorName =
                                counsellorSnap.data?.displayName ??
                                    'Counsellor';
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: ListTile(
                                onTap: () {
                                  context.pushNamed(
                                    AppRoute.appointmentDetail.name,
                                    pathParameters: {'id': session.id},
                                  );
                                },
                                leading: CircleAvatar(
                                  backgroundColor: session.status ==
                                          AppointmentStatus.completed
                                      ? Colors.green
                                      : session.status ==
                                              AppointmentStatus.cancelled
                                          ? Colors.red
                                          : Colors.blue,
                                  child: Icon(
                                    session.status ==
                                            AppointmentStatus.completed
                                        ? Icons.check
                                        : session.status ==
                                                AppointmentStatus.cancelled
                                            ? Icons.close
                                            : Icons.event,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(session.topic ?? 'Session'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(DateFormat('EEE, MMM d, y \\at h:mm a')
                                        .format(session.start)),
                                    Text('With: $counsellorName'),
                                    if (session.sessionType != null)
                                      Text(
                                          'Type: ${session.sessionType == SessionType.online ? 'Online' : 'Face-to-Face'}'),
                                  ],
                                ),
                                trailing: Chip(
                                  label: Text(session.status.name,
                                      style: const TextStyle(fontSize: 11)),
                                  backgroundColor: session.status ==
                                          AppointmentStatus.completed
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : session.status ==
                                              AppointmentStatus.cancelled
                                          ? Colors.red.withValues(alpha: 0.2)
                                          : Colors.blue.withValues(alpha: 0.2),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// Mood Stats Tab
class _MoodStatsTab extends ConsumerStatefulWidget {
  const _MoodStatsTab({required this.studentId});

  final String studentId;

  @override
  ConsumerState<_MoodStatsTab> createState() => _MoodStatsTabState();
}

class _MoodStatsTabState extends ConsumerState<_MoodStatsTab> {
  String _period = 'Week';

  @override
  Widget build(BuildContext context) {
    final fs = ref.watch(firestoreServiceProvider);

    return StreamBuilder(
      stream: fs.moodEntries(widget.studentId),
      builder: (context, moodSnap) {
        final moods = moodSnap.data ?? [];

        if (moods.isEmpty) {
          return const Center(child: Text('No mood entries yet'));
        }

        final days = _period == 'Week' ? 7 : 30;
        final cutoff = DateTime.now().subtract(Duration(days: days));
        final recentMoods =
            moods.where((m) => m.timestamp.isAfter(cutoff)).toList();

        // Calculate statistics
        final avgScore = recentMoods.isEmpty
            ? 0.0
            : recentMoods.map((m) => m.moodScore).reduce((a, b) => a + b) /
                recentMoods.length;
        final highMoods = recentMoods.where((m) => m.moodScore >= 7).length;
        final concerningMoods = recentMoods
            .where((m) => m.riskLevel == 'high' || m.riskLevel == 'critical')
            .length;
        final flaggedMoodsCount =
            recentMoods.where((m) => m.flaggedForCounsellor).length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Period selector
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Last 7 Days'),
                  selected: _period == 'Week',
                  onSelected: (_) => setState(() => _period = 'Week'),
                ),
                ChoiceChip(
                  label: const Text('Last 30 Days'),
                  selected: _period == 'Month',
                  onSelected: (_) => setState(() => _period = 'Month'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Statistics Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  title: 'Average Mood',
                  value: avgScore.toStringAsFixed(1),
                  icon: Icons.analytics,
                  color: avgScore >= 7
                      ? Colors.green
                      : avgScore >= 5
                          ? Colors.orange
                          : Colors.red,
                ),
                _StatCard(
                  title: 'Total Entries',
                  value: recentMoods.length.toString(),
                  icon: Icons.timeline,
                  color: Colors.blue,
                ),
                _StatCard(
                  title: 'Positive Moods',
                  value: highMoods.toString(),
                  icon: Icons.sentiment_satisfied,
                  color: Colors.green,
                ),
                _StatCard(
                  title: 'Flagged Moods',
                  value: flaggedMoodsCount.toString(),
                  icon: Icons.flag,
                  color: flaggedMoodsCount > 0 ? Colors.red : Colors.grey,
                ),
              ],
            ),
            if (concerningMoods > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$concerningMoods high-risk mood ${concerningMoods == 1 ? 'entry' : 'entries'} detected',
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Mood Chart
            SectionCard(
              title: 'Mood Trend',
              child: MoodBarChart(entries: recentMoods, days: days),
            ),
            const SizedBox(height: 16),
            // Recent entries
            SectionCard(
              title: 'Recent Entries',
              child: Column(
                children: recentMoods.take(10).map((mood) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: mood.moodScore >= 7
                          ? Colors.green
                          : mood.moodScore >= 5
                              ? Colors.orange
                              : Colors.red,
                      child: Text(mood.moodScore.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(
                        DateFormat('MMM d, y h:mm a').format(mood.timestamp)),
                    trailing:
                        mood.riskLevel == 'high' || mood.riskLevel == 'critical'
                            ? const Icon(Icons.warning, color: Colors.red)
                            : null,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            // Flagged Mood Entries Section
            SectionCard(
              title: 'Flagged Mood Entries',
              child: () {
                final flaggedEntries =
                    recentMoods.where((m) => m.flaggedForCounsellor).toList();

                if (flaggedEntries.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 32),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No flagged mood entries',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flag, color: Colors.red, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${flaggedEntries.length} flagged mood ${flaggedEntries.length == 1 ? 'entry' : 'entries'}',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...flaggedEntries.take(5).map((mood) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: Colors.red.shade50,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red,
                            child: Text(
                              mood.moodScore.toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            'Mood Score: ${mood.moodScore}/10',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (mood.riskLevel != null)
                                Text('Risk Level: ${mood.riskLevel}'),
                              Text(
                                DateFormat('MMM d, y h:mm a')
                                    .format(mood.timestamp),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.flag, color: Colors.red),
                        ),
                      );
                    }),
                  ],
                );
              }(),
            ),
          ],
        );
      },
    );
  }
}

// Notes Tab - Session notes and follow-ups
class _NotesTab extends ConsumerWidget {
  const _NotesTab({required this.studentId, required this.counsellorId});

  final String studentId;
  final String counsellorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);

    return StreamBuilder<List<Appointment>>(
      stream: fs.appointmentsForStudentAndCounsellor(
        studentId: studentId,
        counsellorId: counsellorId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter to show only past completed sessions with notes/follow-up
        final sessions = snapshot.data!
            .where((a) =>
                a.status == AppointmentStatus.completed &&
                a.start.isBefore(DateTime.now()) &&
                ((a.counsellorNotes != null && a.counsellorNotes!.isNotEmpty) ||
                    (a.followUpPlan != null && a.followUpPlan!.isNotEmpty)))
            .toList();

        sessions.sort((a, b) => b.start.compareTo(a.start));

        if (sessions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No session notes yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                    'Notes from completed sessions will appear here',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return StreamBuilder(
              stream: fs.userProfile(session.counsellorId),
              builder: (context, counsellorSnap) {
                final counsellorName =
                    counsellorSnap.data?.displayName ?? 'Counsellor';
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue.shade100,
                              child: const Icon(Icons.event,
                                  size: 16, color: Colors.blue),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('MMM d').format(session.start),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        // Topic
                        Text(
                          session.topic ?? 'Session',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Counselor
                        Row(
                          children: [
                            const Icon(Icons.person,
                                size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                counsellorName,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Notes preview
                        if (session.counsellorNotes != null &&
                            session.counsellorNotes!.isNotEmpty)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.note,
                                          size: 12, color: Colors.blue),
                                      SizedBox(width: 4),
                                      Text('Notes',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: Text(
                                      session.counsellorNotes!,
                                      style: const TextStyle(fontSize: 11),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Follow-up preview
                        if (session.followUpPlan != null &&
                            session.followUpPlan!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.assignment,
                                        size: 12, color: Colors.orange),
                                    SizedBox(width: 4),
                                    Text('Follow-up',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  session.followUpPlan!,
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// Helper Widget - Stat Card
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Mood Bar Chart Widget
class MoodBarChart extends StatelessWidget {
  const MoodBarChart({
    super.key,
    required this.entries,
    this.days = 7,
  });

  final List<dynamic> entries;
  final int days;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final dates = List.generate(days, (i) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: days - 1 - i));
      return DateTime(d.year, d.month, d.day);
    });

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
            final label = i == days - 1
                ? 'Today'
                : DateFormat(days == 7 ? 'EEE' : 'M/d').format(dates[i]);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: const [
            _LegendDot(color: Colors.green, label: 'Positive (7-10)'),
            _LegendDot(color: Colors.orange, label: 'Neutral (4-6)'),
            _LegendDot(color: Colors.red, label: 'Negative (1-3)'),
          ],
        ),
      ],
    );
  }

  Color _colorForScore(double score) {
    if (score >= 7) return Colors.green;
    if (score >= 4) return Colors.orange;
    if (score > 0) return Colors.red;
    return Colors.grey.shade300;
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
            style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../models/appointment.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';
import '../student/community_forum_page.dart';

final _fsProvider = Provider((ref) => FirestoreService());

class CounsellorDashboardPage extends ConsumerStatefulWidget {
  const CounsellorDashboardPage({super.key});

  @override
  ConsumerState<CounsellorDashboardPage> createState() =>
      _CounsellorDashboardPageState();
}

class _CounsellorDashboardPageState
    extends ConsumerState<CounsellorDashboardPage> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    // Auto-complete expired sessions once when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authStateProvider);
      authState.whenData((user) {
        if (user != null) {
          ref.read(_fsProvider).autoCompleteExpiredSessionsForUser(user.uid);
        }
      });
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      unawaited(ref.read(authServiceProvider).signOut());
      if (mounted) {
        context.goNamed(AppRoute.login.name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const PrimaryScaffold(
        title: 'Counsellor Dashboard',
        body: Center(child: Text('Please sign in')),
      );
    }

    // Auto-complete is handled in initState to avoid duplicate calls on rebuild

    return PrimaryScaffold(
      title: 'Counsellor Dashboard',
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: const CircleAvatar(
          radius: 16,
          backgroundImage: AssetImage('assets/images/PutraMate.png'),
        ),
      ),
      titleWidget: Row(
        children: [
          const Text('PutraMate',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(
            'Welcome, ${user.email ?? ''}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
      actions: [
        const DigitalClock(),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _logout,
          tooltip: 'Logout',
        ),
      ],
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TabButton(
                    label: 'Next Sessions',
                    index: 0,
                    selected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0)),
                _TabButton(
                    label: 'Assigned Students',
                    index: 1,
                    selected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1)),
                _TabButton(
                    label: 'Leave Management',
                    index: 2,
                    selected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2)),
                _TabButton(
                    label: 'Profile',
                    index: 3,
                    selected: _selectedTab == 3,
                    onTap: () => setState(() => _selectedTab = 3)),
                _TabButton(
                    label: 'Community',
                    index: 4,
                    selected: _selectedTab == 4,
                    onTap: () => setState(() => _selectedTab = 4)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                const _NextSessionsTab(),
                _AssignedStudentsTab(counsellorId: user.uid),
                _LeaveManagementTab(counsellorId: user.uid),
                _CounsellorProfileTab(userId: user.uid),
                const CommunityForumPage(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ActionChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_circle, size: 16),
              const SizedBox(width: 6),
            ],
            Text(label),
          ],
        ),
        onPressed: onTap,
        backgroundColor:
            selected ? Theme.of(context).colorScheme.primaryContainer : null,
      ),
    );
  }
}

// Tab 1: Next Sessions
class _NextSessionsTab extends ConsumerStatefulWidget {
  const _NextSessionsTab();

  @override
  ConsumerState<_NextSessionsTab> createState() => _NextSessionsTabState();
}

class _NextSessionsTabState extends ConsumerState<_NextSessionsTab> {
  String _searchQuery = '';
  String _pastSearchQuery = '';
  String _timeFilter = 'All'; // Last Week, Last Month, Last 3 Months, All

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Center(child: Text('Not signed in'));

    final stream = ref.watch(_fsProvider).appointmentsForUser(user.uid);

    return StreamBuilder<List<Appointment>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Auto-complete expired sessions whenever data updates
        final fs = ref.read(_fsProvider);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          fs.autoCompleteExpiredSessionsForUser(user.uid);
          // Also send appointment reminders
          fs.sendAppointmentReminders(user.uid);
        });

        final appts = snapshot.data!;
        // Show upcoming and in-progress sessions (start time in future OR currently in progress)
        final upcoming = appts.where((a) {
          final now = DateTime.now();
          // Show if session hasn't ended yet and status is not completed/cancelled
          return a.end.isAfter(now) &&
              a.status != AppointmentStatus.completed &&
              a.status != AppointmentStatus.cancelled;
        }).toList();
        var past = appts.where((a) => a.end.isBefore(DateTime.now())).toList();

        // Sort past sessions by most recent first
        past.sort((a, b) => b.start.compareTo(a.start));

        // Apply time filter
        if (_timeFilter == 'Last Week') {
          final weekAgo = DateTime.now().subtract(const Duration(days: 7));
          past = past.where((a) => a.start.isAfter(weekAgo)).toList();
        } else if (_timeFilter == 'Last Month') {
          final monthAgo = DateTime.now().subtract(const Duration(days: 30));
          past = past.where((a) => a.start.isAfter(monthAgo)).toList();
        } else if (_timeFilter == 'Last 3 Months') {
          final threeMonthsAgo =
              DateTime.now().subtract(const Duration(days: 90));
          past = past.where((a) => a.start.isAfter(threeMonthsAgo)).toList();
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          past = past.where((a) {
            final query = _searchQuery.toLowerCase();
            return (a.topic?.toLowerCase().contains(query) ?? false) ||
                (a.initialProblem?.toLowerCase().contains(query) ?? false) ||
                (a.notes?.toLowerCase().contains(query) ?? false);
          }).toList();
        }

        final displayedPast = past.take(5).toList();

        // Get all students for search filtering
        final studentsStream = ref.watch(_fsProvider).allStudents();

        // Group upcoming sessions by student ID
        final upcomingByStudent = <String, List<Appointment>>{};
        for (final a in upcoming) {
          upcomingByStudent.putIfAbsent(a.studentId, () => []).add(a);
        }

        return StreamBuilder<List<UserProfile>>(
          stream: studentsStream,
          builder: (context, studentSnap) {
            final studentMap = {
              for (final s in studentSnap.data ?? []) s.uid: s.displayName
            };

            // Filter past by student name if search query is provided
            var filteredPast = displayedPast;
            if (_pastSearchQuery.isNotEmpty) {
              final query = _pastSearchQuery.toLowerCase();
              filteredPast = displayedPast.where((a) {
                final studentName =
                    (studentMap[a.studentId] ?? '').toLowerCase();
                return studentName.contains(query) ||
                    (a.topic?.toLowerCase().contains(query) ?? false) ||
                    (a.initialProblem?.toLowerCase().contains(query) ??
                        false) ||
                    (a.notes?.toLowerCase().contains(query) ?? false);
              }).toList();
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Upcoming Sessions',
                  child: upcomingByStudent.isEmpty
                      ? const Text('No upcoming sessions')
                      : Column(
                          children: upcomingByStudent.entries
                              .map((entry) => _StudentSessionGroup(
                                    studentId: entry.key,
                                    appointments: entry.value,
                                    onUpdate:
                                        (appt, status, notes, plan, link) => ref
                                            .read(_fsProvider)
                                            .updateAppointmentStatus(
                                              appointmentId: appt.id,
                                              status: status,
                                              counsellorNotes: notes,
                                              followUpPlan: plan,
                                              meetLink: link,
                                            ),
                                  ))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Past Sessions',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search bar
                      TextField(
                        decoration: InputDecoration(
                          hintText:
                              'Search by student name, topic, or notes...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _pastSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => _pastSearchQuery = ''),
                                )
                              : null,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _pastSearchQuery = value),
                      ),
                      const SizedBox(height: 12),
                      // Time filter chips
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Last Week'),
                            selected: _timeFilter == 'Last Week',
                            onSelected: (selected) => setState(() =>
                                _timeFilter = selected ? 'Last Week' : 'All'),
                          ),
                          FilterChip(
                            label: const Text('Last Month'),
                            selected: _timeFilter == 'Last Month',
                            onSelected: (selected) => setState(() =>
                                _timeFilter = selected ? 'Last Month' : 'All'),
                          ),
                          FilterChip(
                            label: const Text('Last 3 Months'),
                            selected: _timeFilter == 'Last 3 Months',
                            onSelected: (selected) => setState(() =>
                                _timeFilter =
                                    selected ? 'Last 3 Months' : 'All'),
                          ),
                          FilterChip(
                            label: const Text('All Time'),
                            selected: _timeFilter == 'All',
                            onSelected: (selected) =>
                                setState(() => _timeFilter = 'All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Results count
                      Text(
                        '${past.length} session${past.length == 1 ? '' : 's'} found • showing ${displayedPast.length} recent',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const Divider(height: 16),
                      // Session list (scrollable with smaller cards)
                      if (filteredPast.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No past sessions found'),
                          ),
                        )
                      else
                        SizedBox(
                          height: 300,
                          child: ListView.builder(
                            itemCount: filteredPast.length,
                            itemBuilder: (ctx, idx) {
                              final a = filteredPast[idx];
                              return _SessionCardCompact(
                                appointment: a,
                                onUpdate: (status, notes, plan, link) => ref
                                    .read(_fsProvider)
                                    .updateAppointmentStatus(
                                      appointmentId: a.id,
                                      status: status,
                                      counsellorNotes: notes,
                                      followUpPlan: plan,
                                      meetLink: link,
                                    ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SessionCard extends ConsumerStatefulWidget {
  const _SessionCard({
    required this.appointment,
    required this.onUpdate,
    required this.showFeedback,
  });

  final Appointment appointment;
  final Function(AppointmentStatus, String?, String?, String?) onUpdate;
  final bool showFeedback;

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> {
  String? _meetLink;

  @override
  void initState() {
    super.initState();
    _meetLink = widget.appointment.meetLink;
  }

  Future<void> _showRescheduleDialog() async {
    final fs = ref.read(_fsProvider);
    DateTime? newDate;
    TimeOfDay? newTime;
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Reschedule Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Current: ${DateFormat('MMM d, y at h:mm a').format(widget.appointment.start)}'),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(newDate == null
                      ? 'Select new date'
                      : DateFormat('MMM d, y').format(newDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: widget.appointment.start,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setState(() => newDate = picked);
                    }
                  },
                ),
                ListTile(
                  title: Text(newTime == null
                      ? 'Select new time'
                      : newTime!.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          TimeOfDay.fromDateTime(widget.appointment.start),
                    );
                    if (picked != null) {
                      setState(() => newTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason for rescheduling *',
                    hintText: 'This will be reviewed by admin',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: newDate != null &&
                      newTime != null &&
                      reasonController.text.trim().isNotEmpty
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Submit for Review'),
            ),
          ],
        ),
      ),
    );

    if (result == true && newDate != null && newTime != null && mounted) {
      final newStart = DateTime(
        newDate!.year,
        newDate!.month,
        newDate!.day,
        newTime!.hour,
        newTime!.minute,
      );
      final duration =
          widget.appointment.end.difference(widget.appointment.start);
      final newEnd = newStart.add(duration);

      // Submit reschedule request to admin
      await fs.submitRescheduleRequest(
        appointmentId: widget.appointment.id,
        counsellorId: widget.appointment.counsellorId,
        studentId: widget.appointment.studentId,
        oldStart: widget.appointment.start,
        newStart: newStart,
        newEnd: newEnd,
        reason: reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Reschedule request submitted for admin review')),
        );
      }
    }
  }

  Future<void> _showDetailsDialog() async {
    final fs = ref.read(_fsProvider);
    final notesController =
        TextEditingController(text: widget.appointment.counsellorNotes);
    final planController =
        TextEditingController(text: widget.appointment.followUpPlan);
    final meetLinkController = TextEditingController(text: _meetLink);
    final locationController =
        TextEditingController(text: widget.appointment.location);

    final risk = widget.appointment.riskLevel;
    final sentiment = widget.appointment.sentiment;
    final isHighRisk = risk == 'high' || risk == 'critical';
    final isPending = widget.appointment.status == AppointmentStatus.pending;
    final canReschedule = widget.appointment.start.isAfter(DateTime.now());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student info
              StreamBuilder<UserProfile?>(
                stream: fs.userProfile(widget.appointment.studentId),
                builder: (context, snapshot) {
                  final student = snapshot.data;
                  if (student == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Student: ${student.displayName}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text('Email: ${student.email}'),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.person_search, size: 20),
                            tooltip: 'View Student Profile & Stats',
                            onPressed: () {
                              Navigator.pop(context);
                              context.pushNamed(
                                AppRoute.studentInsights.name,
                                queryParameters: {
                                  'sid': widget.appointment.studentId,
                                  'cid': widget.appointment.counsellorId,
                                  'sname': student.displayName,
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                    ],
                  );
                },
              ),

              // High-risk warning
              if (isHighRisk) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning,
                          color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'High-risk detected: $sentiment / $risk\nPlease prioritize and check safety.',
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Text('Topic: ${widget.appointment.topic ?? "N/A"}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                  'Date: ${DateFormat('MMM d, y \\at h:mm a').format(widget.appointment.start)}'),
              const SizedBox(height: 8),
              Text(
                  'Type: ${widget.appointment.sessionType == SessionType.online ? "Online" : "Face-to-Face"}'),
              const SizedBox(height: 8),
              Text('Status: ${widget.appointment.status.name.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (widget.appointment.initialProblem != null) ...[
                const SizedBox(height: 12),
                const Text('Initial Problem:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.appointment.initialProblem!),
              ],
              if (widget.appointment.notes != null) ...[
                const SizedBox(height: 12),
                const Text('Student Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.appointment.notes!),
              ],
              if (widget.showFeedback &&
                  widget.appointment.studentComment != null) ...[
                const SizedBox(height: 12),
                const Text('Student Feedback:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.appointment.studentComment!),
                if (widget.appointment.studentRating != null)
                  Text('Rating: ${widget.appointment.studentRating}/5 ⭐'),
              ],
              const Divider(),
              const SizedBox(height: 8),
              const Text('Your Actions:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (widget.appointment.sessionType == SessionType.online) ...[
                TextField(
                  controller: meetLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Google Meet Link',
                    hintText: 'https://meet.google.com/xxx-xxxx-xxx',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (widget.appointment.sessionType == SessionType.faceToFace) ...[
                TextField(
                  controller: locationController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Location/Address *',
                    hintText: 'e.g., Room 301, Building A, UPM',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Counsellor Notes', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: planController,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Follow-up Plan', isDense: true),
              ),
              const SizedBox(height: 16),
              const Text('Change Status:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Confirmed'),
                    selected: widget.appointment.status ==
                        AppointmentStatus.confirmed,
                    onSelected: (_) {
                      widget.onUpdate(
                          AppointmentStatus.confirmed, null, null, null);
                      Navigator.pop(context);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Completed'),
                    selected: widget.appointment.status ==
                        AppointmentStatus.completed,
                    onSelected: (_) {
                      widget.onUpdate(
                          AppointmentStatus.completed, null, null, null);
                      Navigator.pop(context);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Cancelled'),
                    selected: widget.appointment.status ==
                        AppointmentStatus.cancelled,
                    onSelected: (_) {
                      widget.onUpdate(
                          AppointmentStatus.cancelled, null, null, null);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (canReschedule)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showRescheduleDialog();
              },
              icon: const Icon(Icons.schedule),
              label: const Text('Reschedule'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _meetLink = meetLinkController.text.trim());

              final location = locationController.text.trim();
              final meetLink = meetLinkController.text.trim();
              final notes = notesController.text.trim();
              final plan = planController.text.trim();

              // Update appointment
              await fs.updateAppointmentWithLocation(
                appointmentId: widget.appointment.id,
                status: widget.appointment.status,
                counsellorNotes: notes.isEmpty ? null : notes,
                followUpPlan: plan.isEmpty ? null : plan,
                meetLink: meetLink.isEmpty ? null : meetLink,
                location: location.isEmpty ? null : location,
              );

              // Send notification if confirming with location/link
              if (isPending && (location.isNotEmpty || meetLink.isNotEmpty)) {
                await fs.updateAppointmentStatus(
                  appointmentId: widget.appointment.id,
                  status: AppointmentStatus.confirmed,
                  counsellorNotes: notes.isEmpty ? null : notes,
                  followUpPlan: plan.isEmpty ? null : plan,
                  meetLink: meetLink.isEmpty ? null : meetLink,
                );
              }

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Updated successfully')),
                );
              }
            },
            child: const Text('Save & Notify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, h:mm a');
    final fs = ref.watch(_fsProvider);

    final risk = widget.appointment.riskLevel;
    final isHighRisk = risk == 'high' || risk == 'critical';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ListTile(
        leading: Stack(
          children: [
            StreamBuilder<UserProfile?>(
              stream: fs.userProfile(widget.appointment.studentId),
              builder: (context, snapshot) {
                final name = snapshot.data?.displayName ?? 'Student';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';
                return CircleAvatar(
                  child: Text(initial),
                );
              },
            ),
            if (isHighRisk)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        title: StreamBuilder<UserProfile?>(
          stream: fs.userProfile(widget.appointment.studentId),
          builder: (context, snapshot) {
            final name = snapshot.data?.displayName ?? 'Student';
            return Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            );
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.appointment.topic ?? 'Session',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              df.format(widget.appointment.start),
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              widget.appointment.sessionType == SessionType.online
                  ? 'Online'
                  : 'Face-to-Face',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: SizedBox(
          width: 100,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Chip(
                label: Text(
                  widget.appointment.status.name,
                  style: const TextStyle(fontSize: 10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        onTap: _showDetailsDialog,
      ),
    );
  }
}

// Tab 2: Assigned Students
class _AssignedStudentsTab extends ConsumerWidget {
  const _AssignedStudentsTab({required this.counsellorId});

  final String counsellorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(_fsProvider);

    // Use appointments-based derivation to ensure visibility even if student profiles were not updated
    return StreamBuilder<List<UserProfile>>(
      stream: fs.assignedStudentsFromAppointments(counsellorId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = snapshot.data!;
        if (students.isEmpty) {
          return const Center(child: Text('No assigned students'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return _StudentCard(student: student, counsellorId: counsellorId);
          },
        );
      },
    );
  }
}

class _StudentCard extends ConsumerWidget {
  const _StudentCard({required this.student, required this.counsellorId});

  final UserProfile student;
  final String counsellorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading:
            CircleAvatar(child: Text(student.displayName[0].toUpperCase())),
        title: Text(student.displayName),
        subtitle: Text(student.email),
        trailing: StreamBuilder<List<dynamic>>(
          stream: ref.watch(_fsProvider).highRiskFlags(student.uid),
          builder: (context, snapshot) {
            final hasRisk = snapshot.hasData && snapshot.data!.isNotEmpty;
            return Icon(
              hasRisk ? Icons.warning : Icons.check_circle,
              color: hasRisk ? Colors.red : Colors.green,
            );
          },
        ),
        onTap: () {
          // Navigate to insights page for this student (push to keep back button)
          context.pushNamed(
            AppRoute.studentInsights.name,
            queryParameters: {
              'sid': student.uid,
              'cid': counsellorId,
              'sname': student.displayName,
            },
          );
        },
      ),
    );
  }
}

// Tab 3: Leave Management
class _LeaveManagementTab extends ConsumerWidget {
  const _LeaveManagementTab({required this.counsellorId});

  final String counsellorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ref.watch(_fsProvider).userLeaves(counsellorId),
      builder: (context, snapshot) {
        final leaves = snapshot.data ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  'Leave management is handled by Admin. Contact admin to add or change leave dates.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            Expanded(
              child: leaves.isEmpty
                  ? const Center(child: Text('No leaves'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: leaves.length,
                      itemBuilder: (context, index) {
                        final leave = leaves[index];
                        final startDate = DateTime.fromMillisecondsSinceEpoch(
                            leave['startDate']);
                        final endDate = DateTime.fromMillisecondsSinceEpoch(
                            leave['endDate']);

                        return Card(
                          child: ListTile(
                            title: Text('${leave['leaveType']} Leave'),
                            subtitle: Text(
                                '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)}\n${leave['reason'] ?? ""}\nStatus: ${leave['status'] ?? 'pending'}'),
                          ),
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

// Tab 4: Profile
class _CounsellorProfileTab extends ConsumerStatefulWidget {
  const _CounsellorProfileTab({required this.userId});

  final String userId;

  @override
  ConsumerState<_CounsellorProfileTab> createState() =>
      _CounsellorProfileTabState();
}

class _CounsellorProfileTabState extends ConsumerState<_CounsellorProfileTab> {
  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  final _expertiseController = TextEditingController();
  bool _isEditing = false;

  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                hintText: 'Min 8 chars, 1 special character',
              ),
            ),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirm New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }

              final regex = RegExp(r'^(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$');
              if (!regex.hasMatch(newController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Password must be at least 8 characters with 1 special character')),
                );
                return;
              }

              try {
                await ref.read(authServiceProvider).changePassword(
                      currentPassword: currentController.text,
                      newPassword: newController.text,
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password changed successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile(UserProfile profile) async {
    final fs = ref.read(_fsProvider);
    try {
      await ref
          .read(authServiceProvider)
          .updateDisplayName(_nameController.text.trim());
      await fs.updateUserProfile(
        widget.userId,
        {
          'fullName': _nameController.text.trim(),
          'designation': _designationController.text.trim(),
          'expertise': _expertiseController.text.trim(),
        },
      );

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: ref.watch(_fsProvider).userProfile(widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data!;

        if (!_isEditing) {
          _nameController.text = profile.displayName;
          _designationController.text = profile.designation ?? '';
          _expertiseController.text = profile.expertise ?? '';
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Profile Information',
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: profile.email),
                    decoration:
                        const InputDecoration(labelText: 'Email (read-only)'),
                    enabled: false,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _designationController,
                    decoration: const InputDecoration(labelText: 'Designation'),
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _expertiseController,
                    decoration: const InputDecoration(labelText: 'Expertise'),
                    maxLines: 2,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 16),
                  if (_isEditing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _isEditing = false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _saveProfile(profile),
                          child: const Text('Save'),
                        ),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: () => setState(() => _isEditing = true),
                      child: const Text('Edit Profile'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Security',
              child: ElevatedButton(
                onPressed: _showChangePasswordDialog,
                child: const Text('Change Password'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _expertiseController.dispose();
    super.dispose();
  }
}

// Helper: Group sessions by student
class _StudentSessionGroup extends StatefulWidget {
  final String studentId;
  final List<Appointment> appointments;
  final Function(Appointment, AppointmentStatus, String?, String?, String?)
      onUpdate;

  const _StudentSessionGroup({
    required this.studentId,
    required this.appointments,
    required this.onUpdate,
  });

  @override
  State<_StudentSessionGroup> createState() => _StudentSessionGroupState();
}

class _StudentSessionGroupState extends State<_StudentSessionGroup> {
  bool _isExpanded = false;

  Future<void> _showSessionDetails(
      BuildContext context, Appointment appointment, String studentName) async {
    final fs = FirestoreService();
    final notesController =
        TextEditingController(text: appointment.counsellorNotes);
    final planController =
        TextEditingController(text: appointment.followUpPlan);
    final meetLinkController =
        TextEditingController(text: appointment.meetLink);
    final locationController =
        TextEditingController(text: appointment.location);
    AppointmentStatus selectedStatus = appointment.status;
    bool isSaving = false;

    Color getStatusColor(AppointmentStatus status) {
      switch (status) {
        case AppointmentStatus.pending:
          return Colors.orange;
        case AppointmentStatus.confirmed:
          return Colors.green;
        case AppointmentStatus.cancelled:
          return Colors.red;
        case AppointmentStatus.completed:
          return Colors.blue;
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Session with $studentName',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          getStatusColor(selectedStatus).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      selectedStatus.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: getStatusColor(selectedStatus),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      appointment.sessionType == SessionType.online
                          ? '💻 Online'
                          : '👤 In-Person',
                      style: const TextStyle(fontSize: 12),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('MMM d, y').format(appointment.start),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('h:mm a').format(appointment.start),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      if (appointment.topic != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.subject, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                appointment.topic!,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Status Section
                const Text('Session Status',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonFormField<AppointmentStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: AppointmentStatus.values
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: getStatusColor(s),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(s.name[0].toUpperCase() +
                                      s.name.substring(1)),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (status) {
                      if (status != null)
                        setState(() => selectedStatus = status);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Initial Problem
                if (appointment.initialProblem != null) ...[
                  const Text('Student\'s Concern',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      appointment.initialProblem!,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Session Details (Online/In-Person)
                if (appointment.sessionType == SessionType.online) ...[
                  const Text('Google Meet Link',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: meetLinkController,
                    decoration: InputDecoration(
                      hintText: 'https://meet.google.com/xxx-xxxx-xxx',
                      prefixIcon: const Icon(Icons.videocam_outlined, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (appointment.sessionType ==
                    SessionType.faceToFace) ...[
                  const Text('Meeting Location',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g., Room 301, Building A, UPM',
                      prefixIcon:
                          const Icon(Icons.location_on_outlined, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Counsellor Notes
                const Text('Session Notes',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Document key points discussed, observations, or concerns...',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),

                // Follow-up Plan
                const Text('Follow-up Plan',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: planController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText:
                        'Next steps, assignments, or recommendations for the student...',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
            ElevatedButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      setState(() => isSaving = true);
                      try {
                        await fs.updateAppointmentStatus(
                          appointmentId: appointment.id,
                          status: selectedStatus,
                          counsellorNotes: notesController.text.isNotEmpty
                              ? notesController.text
                              : null,
                          followUpPlan: planController.text.isNotEmpty
                              ? planController.text
                              : null,
                          meetLink: meetLinkController.text.isNotEmpty
                              ? meetLinkController.text
                              : null,
                        );

                        // Send notification to student if status changed
                        if (selectedStatus != appointment.status) {
                          await fs.sendNotification(
                            userId: appointment.studentId,
                            title: 'Session ${selectedStatus.name}',
                            message: selectedStatus ==
                                    AppointmentStatus.confirmed
                                ? 'Your session has been confirmed! 📅'
                                : selectedStatus == AppointmentStatus.completed
                                    ? 'Your session has been completed. Thank you! ✅'
                                    : 'Your session status has been updated.',
                            type: 'appointment_status_change',
                            appointmentId: appointment.id,
                          );
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    '✅ Session updated and student notified')),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ Error: $e')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => isSaving = false);
                      }
                    },
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(isSaving ? 'Saving...' : 'Save & Notify'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return StreamBuilder<UserProfile?>(
      stream: fs.userProfile(widget.studentId),
      builder: (context, snapshot) {
        final student = snapshot.data;
        final studentName = student?.displayName ?? 'Unknown';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              ListTile(
                title: Text(studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${widget.appointments.length} upcoming appointment${widget.appointments.length == 1 ? '' : 's'}'),
                trailing:
                    Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                onTap: () => setState(() => _isExpanded = !_isExpanded),
              ),
              if (_isExpanded) ...[
                const Divider(height: 1),
                ...widget.appointments.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final a = entry.value;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMM d, y • h:mm a').format(a.start),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (a.topic != null)
                          Text('Topic: ${a.topic}',
                              style: const TextStyle(fontSize: 12)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Chip(
                              label: Text(a.status.name),
                              visualDensity: VisualDensity.compact,
                            ),
                            TextButton(
                              onPressed: () => _showSessionDetails(context, a,
                                  student?.displayName ?? 'Student'),
                              child: const Text('View'),
                            ),
                          ],
                        ),
                        if (idx < widget.appointments.length - 1)
                          const Divider(height: 12),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

// Compact session card for past sessions
class _SessionCardCompact extends StatelessWidget {
  final Appointment appointment;
  final Function(AppointmentStatus, String?, String?, String?) onUpdate;

  const _SessionCardCompact({
    required this.appointment,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return StreamBuilder<UserProfile?>(
      stream: fs.userProfile(appointment.studentId),
      builder: (context, snapshot) {
        final student = snapshot.data;
        final studentName = student?.displayName ?? appointment.studentId;

        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            title: Text(
              '$studentName • ${DateFormat('MMM d, h:mm a').format(appointment.start)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              appointment.topic ?? 'No topic',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Text(
              appointment.status.name,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        );
      },
    );
  }
}

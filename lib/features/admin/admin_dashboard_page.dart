import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/appointment.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../router/app_router.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';
import '../student/community_forum_page.dart';

final _fsProvider = Provider((ref) => FirestoreService());

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _selectedTab = 0;

  Future<void> _logout() async {
    final confirm = await _showCenteredDialog<bool>(
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

  Future<T?> _showCenteredDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: builder(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const PrimaryScaffold(
        title: 'Admin Dashboard',
        body: Center(child: Text('Please sign in')),
      );
    }

    return PrimaryScaffold(
      title: 'Admin Dashboard',
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: CircleAvatar(
          radius: 16,
          backgroundImage: const AssetImage('assets/images/PutraMate.png'),
        ),
      ),
      titleWidget: Row(
        children: [
          const Text('PutraMate - Admin',
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
                    label: 'Overview',
                    index: 0,
                    selected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0)),
                _TabButton(
                    label: 'Students',
                    index: 1,
                    selected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1)),
                _TabButton(
                    label: 'Counsellors',
                    index: 2,
                    selected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2)),
                _TabButton(
                    label: 'Appointments',
                    index: 3,
                    selected: _selectedTab == 3,
                    onTap: () => setState(() => _selectedTab = 3)),
                _TabButton(
                    label: 'Leave Management',
                    index: 4,
                    selected: _selectedTab == 4,
                    onTap: () => setState(() => _selectedTab = 4)),
                _TabButton(
                    label: 'Community',
                    index: 5,
                    selected: _selectedTab == 5,
                    onTap: () => setState(() => _selectedTab = 5)),
                _TabButton(
                    label: 'Profile',
                    index: 6,
                    selected: _selectedTab == 6,
                    onTap: () => setState(() => _selectedTab = 6)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _OverviewTab(showCenteredDialog: _showCenteredDialog),
                _StudentsTab(showCenteredDialog: _showCenteredDialog),
                _CounsellorsTab(showCenteredDialog: _showCenteredDialog),
                _AppointmentsTab(showCenteredDialog: _showCenteredDialog),
                _LeaveManagementTab(showCenteredDialog: _showCenteredDialog),
                const CommunityForumPage(embedded: true),
                _AdminProfileTab(userId: user.uid),
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

// OVERVIEW TAB
class _OverviewTab extends ConsumerStatefulWidget {
  final Future<T?> Function<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
  }) showCenteredDialog;

  const _OverviewTab({required this.showCenteredDialog});

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  String _upcomingFilter = '2 days'; // 2 days, 1 week, 1 month, all time
  String _upcomingSearch = '';
  String _pastFilter = '1 week'; // 1 week, 1 month, 3 months, all time
  String _pastSearch = '';

  @override
  Widget build(BuildContext context) {
    final studentsStream = ref.watch(_fsProvider).allStudents();
    final counsellorsStream = ref.watch(_fsProvider).counsellors();
    final appointmentsStream = ref.watch(_fsProvider).allAppointments();

    return StreamBuilder<List<UserProfile>>(
      stream: studentsStream,
      builder: (context, studentSnap) {
        return StreamBuilder<List<UserProfile>>(
          stream: counsellorsStream,
          builder: (context, counsellorSnap) {
            return StreamBuilder<List<Appointment>>(
              stream: appointmentsStream,
              builder: (context, apptSnap) {
                final students = studentSnap.data ?? [];
                final counsellors = counsellorSnap.data ?? [];
                final allAppts = apptSnap.data ?? [];

                final totalStudents = students.length;
                final totalCounsellors = counsellors.length;
                final totalBookings = allAppts.length;
                final activeBookings = allAppts
                    .where((a) =>
                        a.status != 'completed' &&
                        a.status != 'cancelled' &&
                        a.start.isAfter(DateTime.now()))
                    .length;

                // Filter upcoming appointments
                final now = DateTime.now();
                DateTime upcomingCutoff;
                switch (_upcomingFilter) {
                  case '2 days':
                    upcomingCutoff = now.add(const Duration(days: 2));
                    break;
                  case '1 week':
                    upcomingCutoff = now.add(const Duration(days: 7));
                    break;
                  case '1 month':
                    upcomingCutoff = now.add(const Duration(days: 30));
                    break;
                  case 'all time':
                    upcomingCutoff = DateTime(2100); // Far future
                    break;
                  default:
                    upcomingCutoff = now.add(const Duration(days: 2));
                }

                var upcomingAppts = allAppts
                    .where((a) =>
                        a.start.isAfter(now) &&
                        a.start.isBefore(upcomingCutoff))
                    .toList();
                upcomingAppts.sort((a, b) => a.start.compareTo(b.start));

                // Filter past appointments
                DateTime pastCutoff;
                switch (_pastFilter) {
                  case '1 week':
                    pastCutoff = now.subtract(const Duration(days: 7));
                    break;
                  case '1 month':
                    pastCutoff = now.subtract(const Duration(days: 30));
                    break;
                  case '3 months':
                    pastCutoff = now.subtract(const Duration(days: 90));
                    break;
                  case 'all time':
                    pastCutoff = DateTime(2000); // Far past
                    break;
                  default:
                    pastCutoff = now.subtract(const Duration(days: 7));
                }

                var pastAppts = allAppts
                    .where((a) =>
                        a.start.isBefore(now) && a.start.isAfter(pastCutoff))
                    .toList();
                pastAppts.sort((a, b) => b.start.compareTo(a.start));

                // Create name maps
                final studentMap = {
                  for (final s in students) s.uid: s.displayName
                };
                final counsellorMap = {
                  for (final c in counsellors) c.uid: c.displayName
                };

                // Apply search filters
                if (_upcomingSearch.isNotEmpty) {
                  final query = _upcomingSearch.toLowerCase();
                  upcomingAppts = upcomingAppts.where((a) {
                    final studentName =
                        (studentMap[a.studentId] ?? '').toLowerCase();
                    final counsellorName =
                        (counsellorMap[a.counsellorId] ?? '').toLowerCase();
                    return studentName.contains(query) ||
                        counsellorName.contains(query);
                  }).toList();
                }

                if (_pastSearch.isNotEmpty) {
                  final query = _pastSearch.toLowerCase();
                  pastAppts = pastAppts.where((a) {
                    final studentName =
                        (studentMap[a.studentId] ?? '').toLowerCase();
                    final counsellorName =
                        (counsellorMap[a.counsellorId] ?? '').toLowerCase();
                    return studentName.contains(query) ||
                        counsellorName.contains(query);
                  }).toList();
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Stats Cards
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatCard(
                          title: 'Total Students',
                          value: totalStudents.toString(),
                          icon: Icons.school,
                          color: Colors.blue,
                        ),
                        _StatCard(
                          title: 'Total Counsellors',
                          value: totalCounsellors.toString(),
                          icon: Icons.people,
                          color: Colors.green,
                        ),
                        _StatCard(
                          title: 'Total Bookings',
                          value: totalBookings.toString(),
                          icon: Icons.event,
                          color: Colors.orange,
                        ),
                        _StatCard(
                          title: 'Active Bookings',
                          value: activeBookings.toString(),
                          icon: Icons.event_available,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Upcoming Appointments
                    SectionCard(
                      title: 'Upcoming Appointments',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 150,
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Search...',
                                prefixIcon: Icon(Icons.search, size: 18),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) =>
                                  setState(() => _upcomingSearch = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _upcomingFilter,
                            items: const [
                              DropdownMenuItem(
                                  value: '2 days', child: Text('2 Days')),
                              DropdownMenuItem(
                                  value: '1 week', child: Text('1 Week')),
                              DropdownMenuItem(
                                  value: '1 month', child: Text('1 Month')),
                              DropdownMenuItem(
                                  value: 'all time', child: Text('All Time')),
                            ],
                            onChanged: (v) =>
                                setState(() => _upcomingFilter = v ?? '2 days'),
                          ),
                        ],
                      ),
                      child: upcomingAppts.isEmpty
                          ? const Text('No upcoming appointments')
                          : Column(
                              children: upcomingAppts
                                  .map((a) => _AppointmentCard(
                                        appointment: a,
                                        studentName: studentMap[a.studentId] ??
                                            'Unknown',
                                        counsellorName:
                                            counsellorMap[a.counsellorId] ??
                                                'Unknown',
                                        onTap: () => _showAppointmentDetails(
                                          context,
                                          a,
                                          studentMap[a.studentId] ?? 'Unknown',
                                          counsellorMap[a.counsellorId] ??
                                              'Unknown',
                                        ),
                                      ))
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: 24),
                    // Past Sessions
                    SectionCard(
                      title: 'Past Sessions',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 150,
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Search...',
                                prefixIcon: Icon(Icons.search, size: 18),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => setState(() => _pastSearch = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _pastFilter,
                            items: const [
                              DropdownMenuItem(
                                  value: '1 week', child: Text('1 Week')),
                              DropdownMenuItem(
                                  value: '1 month', child: Text('1 Month')),
                              DropdownMenuItem(
                                  value: '3 months', child: Text('3 Months')),
                              DropdownMenuItem(
                                  value: 'all time', child: Text('All Time')),
                            ],
                            onChanged: (v) =>
                                setState(() => _pastFilter = v ?? '1 week'),
                          ),
                        ],
                      ),
                      child: pastAppts.isEmpty
                          ? const Text('No past sessions')
                          : Column(
                              children: pastAppts
                                  .map((a) => _AppointmentCard(
                                        appointment: a,
                                        studentName: studentMap[a.studentId] ??
                                            'Unknown',
                                        counsellorName:
                                            counsellorMap[a.counsellorId] ??
                                                'Unknown',
                                        onTap: () => _showAppointmentDetails(
                                          context,
                                          a,
                                          studentMap[a.studentId] ?? 'Unknown',
                                          counsellorMap[a.counsellorId] ??
                                              'Unknown',
                                        ),
                                      ))
                                  .toList(),
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAppointmentDetails(
    BuildContext context,
    Appointment appt,
    String studentName,
    String counsellorName,
  ) {
    widget.showCenteredDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appointment Details'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Student', studentName),
              _DetailRow('Counsellor', counsellorName),
              _DetailRow('Date', DateFormat('MMM dd, yyyy').format(appt.start)),
              _DetailRow('Time',
                  '${DateFormat('HH:mm').format(appt.start)} - ${DateFormat('HH:mm').format(appt.end)}'),
              _DetailRow('Status', appt.status.name),
              if (appt.topic?.isNotEmpty ?? false)
                _DetailRow('Topic', appt.topic!),
              if (appt.initialProblem?.isNotEmpty ?? false)
                _DetailRow('Problem', appt.initialProblem!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String studentName;
  final String counsellorName;
  final VoidCallback onTap;

  const _AppointmentCard({
    required this.appointment,
    required this.studentName,
    required this.counsellorName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.event,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text('$studentName with $counsellorName'),
        subtitle: Text(
          '${DateFormat('MMM dd, yyyy HH:mm').format(appointment.start)} • ${appointment.status}',
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// STUDENTS TAB
class _StudentsTab extends ConsumerStatefulWidget {
  final Future<T?> Function<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
  }) showCenteredDialog;

  const _StudentsTab({required this.showCenteredDialog});

  @override
  ConsumerState<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends ConsumerState<_StudentsTab> {
  String _search = '';
  String _filter = 'all'; // all, active, inactive

  @override
  Widget build(BuildContext context) {
    final studentsStream = ref.watch(_fsProvider).allStudents();

    return StreamBuilder<List<UserProfile>>(
      stream: studentsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var students = snapshot.data!;

        // Apply filter
        if (_filter == 'active') {
          students = students.where((s) => s.isActive).toList();
        } else if (_filter == 'inactive') {
          students = students.where((s) => !s.isActive).toList();
        }

        // Apply search
        if (_search.isNotEmpty) {
          final query = _search.toLowerCase();
          students = students.where((s) {
            return s.displayName.toLowerCase().contains(query) ||
                s.email.toLowerCase().contains(query);
          }).toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search by name or email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _filter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (v) => setState(() => _filter = v ?? 'all'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: students.isEmpty
                  ? const Center(child: Text('No students found'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: students.length,
                      itemBuilder: (context, i) {
                        final student = students[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(student.displayName[0].toUpperCase()),
                            ),
                            title: Text(student.displayName),
                            subtitle: Text(student.email),
                            trailing: Icon(
                              student.isActive
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color:
                                  student.isActive ? Colors.green : Colors.red,
                            ),
                            onTap: () => _showStudentDetails(student),
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

  void _showStudentDetails(UserProfile student) {
    widget.showCenteredDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Student Details'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Name', student.displayName),
              _DetailRow('Email', student.email),
              _DetailRow('Status', student.isActive ? 'Active' : 'Inactive'),
              _DetailRow('Role', student.role.name.toUpperCase()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (!student.isActive)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                await ref
                    .read(_fsProvider)
                    .updateUserProfile(student.uid, {'isActive': true});
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student activated')),
                  );
                }
              },
              child: const Text('Activate'),
            ),
          if (student.isActive)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                await ref
                    .read(_fsProvider)
                    .updateUserProfile(student.uid, {'isActive': false});
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student disabled')),
                  );
                }
              },
              child: const Text('Disable'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: ctx,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: const Text(
                      'Are you sure you want to delete this student? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(_fsProvider).deleteUserProfile(student.uid);
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student deleted')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// COUNSELLORS TAB
class _CounsellorsTab extends ConsumerStatefulWidget {
  final Future<T?> Function<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
  }) showCenteredDialog;

  const _CounsellorsTab({required this.showCenteredDialog});

  @override
  ConsumerState<_CounsellorsTab> createState() => _CounsellorsTabState();
}

class _CounsellorsTabState extends ConsumerState<_CounsellorsTab> {
  String _search = '';
  String _filter = 'all'; // all, active, inactive

  @override
  Widget build(BuildContext context) {
    final counsellorsStream = ref.watch(_fsProvider).counsellors();

    return StreamBuilder<List<UserProfile>>(
      stream: counsellorsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var counsellors = snapshot.data!;

        // Apply filter
        if (_filter == 'active') {
          counsellors = counsellors.where((c) => c.isActive).toList();
        } else if (_filter == 'inactive') {
          counsellors = counsellors.where((c) => !c.isActive).toList();
        }

        // Apply search
        if (_search.isNotEmpty) {
          final query = _search.toLowerCase();
          counsellors = counsellors.where((c) {
            return c.displayName.toLowerCase().contains(query) ||
                c.email.toLowerCase().contains(query);
          }).toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search by name or email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _filter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (v) => setState(() => _filter = v ?? 'all'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Counsellor'),
                    onPressed: () => _showAddCounsellorDialog(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: counsellors.isEmpty
                  ? const Center(child: Text('No counsellors found'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: counsellors.length,
                      itemBuilder: (context, i) {
                        final counsellor = counsellors[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green,
                              child:
                                  Text(counsellor.displayName[0].toUpperCase()),
                            ),
                            title: Text(counsellor.displayName),
                            subtitle: Text(counsellor.email),
                            trailing: Icon(
                              counsellor.isActive
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: counsellor.isActive
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            onTap: () => _showCounsellorDetails(counsellor),
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

  void _showCounsellorDetails(UserProfile counsellor) {
    final reviewsStream =
        ref.watch(_fsProvider).counsellorReviews(counsellor.uid);

    widget.showCenteredDialog(
      context: context,
      builder: (ctx) => StreamBuilder<List<Appointment>>(
        stream: reviewsStream,
        builder: (context, reviewSnapshot) {
          final reviews = reviewSnapshot.data ?? [];
          final reviewedAppointments = reviews
              .where((a) => a.studentRating != null && a.studentRating! > 0)
              .toList();
          final avgRating = reviewedAppointments.isEmpty
              ? 0.0
              : reviewedAppointments
                      .map((a) => a.studentRating!.toDouble())
                      .reduce((a, b) => a + b) /
                  reviewedAppointments.length;

          return AlertDialog(
            title: const Text('Counsellor Details'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow('Name', counsellor.displayName),
                    _DetailRow('Email', counsellor.email),
                    _DetailRow(
                        'Status', counsellor.isActive ? 'Active' : 'Inactive'),
                    _DetailRow('Role', counsellor.role.name.toUpperCase()),
                    const Divider(height: 24),
                    Text(
                      'Student Reviews',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (reviewedAppointments.isEmpty)
                      const Text('No reviews yet')
                    else ...[
                      Row(
                        children: [
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < avgRating.round()
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                ),
                              ),
                              Text(
                                '${reviewedAppointments.length} reviews',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: reviewedAppointments.length,
                          itemBuilder: (context, i) {
                            final appt = reviewedAppointments[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ...List.generate(
                                          5,
                                          (i) => Icon(
                                            i < (appt.studentRating ?? 0)
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          DateFormat('MMM dd, yyyy')
                                              .format(appt.start),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                    if (appt.studentComment?.isNotEmpty ??
                                        false) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        appt.studentComment!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddLeaveDialog(counsellor);
                },
                child: const Text('Add Leave'),
              ),
              if (!counsellor.isActive)
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    await ref
                        .read(_fsProvider)
                        .updateUserProfile(counsellor.uid, {'isActive': true});
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Counsellor activated')),
                      );
                    }
                  },
                  child: const Text('Activate'),
                ),
              if (counsellor.isActive)
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () async {
                    await ref
                        .read(_fsProvider)
                        .updateUserProfile(counsellor.uid, {'isActive': false});
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Counsellor disabled')),
                      );
                    }
                  },
                  child: const Text('Disable'),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: ctx,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Delete'),
                      content: const Text(
                          'Are you sure you want to delete this counsellor? This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref
                        .read(_fsProvider)
                        .deleteUserProfile(counsellor.uid);
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Counsellor deleted')),
                      );
                    }
                  }
                },
                child: const Text('Delete'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCounsellorDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final designationController = TextEditingController();
    final expertiseController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();

    widget.showCenteredDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Counsellor'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: designationController,
                decoration: const InputDecoration(
                  labelText: 'Designation',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expertiseController,
                decoration: const InputDecoration(
                  labelText: 'Expertise (comma-separated)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.psychology),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameController.dispose();
              emailController.dispose();
              designationController.dispose();
              expertiseController.dispose();
              phoneController.dispose();
              passwordController.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final designation = designationController.text.trim();
              final expertise = expertiseController.text.trim();
              final phone = phoneController.text.trim();
              final password = passwordController.text.trim();

              if (name.isEmpty ||
                  email.isEmpty ||
                  password.isEmpty ||
                  designation.isEmpty ||
                  expertise.isEmpty ||
                  phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              if (password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Password must be at least 6 characters')),
                );
                return;
              }

              try {
                final cred =
                    await ref.read(authServiceProvider).registerStudent(
                          email: email,
                          password: password,
                          displayName: name,
                        );

                // Update role to counsellor
                await ref.read(_fsProvider).updateUserProfile(
                  cred.user!.uid,
                  {
                    'role': 'counsellor',
                    'designation': designation,
                    'expertise': expertise,
                    'phoneNumber': phone,
                  },
                );

                nameController.dispose();
                emailController.dispose();
                designationController.dispose();
                expertiseController.dispose();
                phoneController.dispose();
                passwordController.dispose();
                Navigator.pop(ctx);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Counsellor added successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddLeaveDialog(UserProfile counsellor) {
    DateTimeRange? range;
    final reasonCtrl = TextEditingController();
    String leaveType = 'general';
    bool hasConflicts = false;
    List<Appointment> conflicts = [];

    widget.showCenteredDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Add Leave for ${counsellor.displayName}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: leaveType,
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'medical', child: Text('Medical')),
                    DropdownMenuItem(
                        value: 'personal', child: Text('Personal')),
                    DropdownMenuItem(
                        value: 'emergency', child: Text('Emergency')),
                  ],
                  onChanged: (v) => setState(() => leaveType = v ?? 'general'),
                  decoration: const InputDecoration(
                    labelText: 'Leave Type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    range == null
                        ? 'Select Date Range'
                        : '${DateFormat('MMM dd, yyyy').format(range!.start)} - ${DateFormat('MMM dd, yyyy').format(range!.end)}',
                  ),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: ctx,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                      initialDateRange: range,
                    );
                    if (picked != null) {
                      setState(() => range = picked);
                      // Check for conflicts
                      final fs = ref.read(_fsProvider);
                      conflicts = await fs.counsellorAppointmentsOverlapping(
                        counsellorId: counsellor.uid,
                        start: picked.start,
                        end: picked.end,
                      );
                      setState(() => hasConflicts = conflicts.isNotEmpty);
                    }
                  },
                ),
                if (hasConflicts) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Booking Conflicts Found',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${conflicts.length} appointment(s) exist during this period. Cannot add leave.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                reasonCtrl.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (range == null || hasConflicts)
                  ? null
                  : () async {
                      final fs = ref.read(_fsProvider);
                      await fs.addLeave(
                        userId: counsellor.uid,
                        startDate: range!.start,
                        endDate: range!.end,
                        reason: reasonCtrl.text.trim(),
                        leaveType: leaveType,
                      );
                      reasonCtrl.dispose();
                      Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Leave added for ${counsellor.displayName}')),
                        );
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// APPOINTMENTS TAB
class _AppointmentsTab extends ConsumerStatefulWidget {
  final Future<T?> Function<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
  }) showCenteredDialog;

  const _AppointmentsTab({required this.showCenteredDialog});

  @override
  ConsumerState<_AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends ConsumerState<_AppointmentsTab> {
  String _search = '';
  String _filter = 'all'; // all, 1 week, 1 month, 3 months

  @override
  Widget build(BuildContext context) {
    final appointmentsStream = ref.watch(_fsProvider).allAppointments();
    final studentsStream = ref.watch(_fsProvider).allStudents();
    final counsellorsStream = ref.watch(_fsProvider).counsellors();

    return StreamBuilder<List<Appointment>>(
      stream: appointmentsStream,
      builder: (context, apptSnap) {
        return StreamBuilder<List<UserProfile>>(
          stream: studentsStream,
          builder: (context, studentSnap) {
            return StreamBuilder<List<UserProfile>>(
              stream: counsellorsStream,
              builder: (context, counsellorSnap) {
                if (!apptSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var appointments = apptSnap.data!;
                final students = studentSnap.data ?? [];
                final counsellors = counsellorSnap.data ?? [];

                final studentMap = {
                  for (final s in students) s.uid: s.displayName
                };
                final counsellorMap = {
                  for (final c in counsellors) c.uid: c.displayName
                };

                // Apply time filter
                if (_filter != 'all') {
                  final now = DateTime.now();
                  DateTime cutoff;
                  switch (_filter) {
                    case '1 week':
                      cutoff = now.subtract(const Duration(days: 7));
                      break;
                    case '1 month':
                      cutoff = now.subtract(const Duration(days: 30));
                      break;
                    case '3 months':
                      cutoff = now.subtract(const Duration(days: 90));
                      break;
                    default:
                      cutoff = DateTime(2000);
                  }
                  appointments = appointments
                      .where((a) => a.start.isAfter(cutoff))
                      .toList();
                }

                // Apply search
                if (_search.isNotEmpty) {
                  final query = _search.toLowerCase();
                  appointments = appointments.where((a) {
                    final studentName =
                        (studentMap[a.studentId] ?? '').toLowerCase();
                    final counsellorName =
                        (counsellorMap[a.counsellorId] ?? '').toLowerCase();
                    return studentName.contains(query) ||
                        counsellorName.contains(query) ||
                        (a.topic?.toLowerCase().contains(query) ?? false);
                  }).toList();
                }

                // Sort by date
                appointments.sort((a, b) => b.start.compareTo(a.start));

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Search by student or counsellor',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (v) => setState(() => _search = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _filter,
                            items: const [
                              DropdownMenuItem(
                                  value: 'all', child: Text('All')),
                              DropdownMenuItem(
                                  value: '1 week', child: Text('Last Week')),
                              DropdownMenuItem(
                                  value: '1 month', child: Text('Last Month')),
                              DropdownMenuItem(
                                  value: '3 months',
                                  child: Text('Last 3 Months')),
                            ],
                            onChanged: (v) =>
                                setState(() => _filter = v ?? 'all'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: appointments.isEmpty
                          ? const Center(child: Text('No appointments found'))
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: appointments.length,
                              itemBuilder: (context, i) {
                                final appt = appointments[i];
                                final studentName =
                                    studentMap[appt.studentId] ?? 'Unknown';
                                final counsellorName =
                                    counsellorMap[appt.counsellorId] ??
                                        'Unknown';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.event,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    title: Text(
                                        '$studentName with $counsellorName'),
                                    subtitle: Text(
                                      '${DateFormat('MMM dd, yyyy HH:mm').format(appt.start)} • ${appt.status}',
                                    ),
                                    trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16),
                                    onTap: () => _showAppointmentDetails(
                                      appt,
                                      studentName,
                                      counsellorName,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAppointmentDetails(
    Appointment appt,
    String studentName,
    String counsellorName,
  ) {
    widget.showCenteredDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appointment Details'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Student', studentName),
              _DetailRow('Counsellor', counsellorName),
              _DetailRow('Date', DateFormat('MMM dd, yyyy').format(appt.start)),
              _DetailRow('Time',
                  '${DateFormat('HH:mm').format(appt.start)} - ${DateFormat('HH:mm').format(appt.end)}'),
              _DetailRow('Status', appt.status.name),
              if (appt.topic?.isNotEmpty ?? false)
                _DetailRow('Topic', appt.topic!),
              if (appt.initialProblem?.isNotEmpty ?? false)
                _DetailRow('Problem', appt.initialProblem!),
              if (appt.notes?.isNotEmpty ?? false)
                _DetailRow('Notes', appt.notes!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (appt.start.isAfter(DateTime.now()) &&
              appt.status != AppointmentStatus.cancelled &&
              appt.status != AppointmentStatus.completed)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showRescheduleDialog(appt, studentName, counsellorName);
              },
              child: const Text('Reschedule'),
            ),
        ],
      ),
    );
  }

  void _showRescheduleDialog(
    Appointment appt,
    String studentName,
    String counsellorName,
  ) {
    DateTime? newDate;
    TimeOfDay? newStartTime;
    TimeOfDay? newEndTime;
    bool isChecking = false;
    bool hasConflict = false;
    String conflictMessage = '';

    widget.showCenteredDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Reschedule Appointment'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Student: $studentName',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text('Counsellor: $counsellorName',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const Divider(height: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      newDate == null
                          ? 'Select New Date'
                          : DateFormat('MMM dd, yyyy').format(newDate!),
                      style: const TextStyle(fontSize: 14),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: appt.start,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          newDate = picked;
                          hasConflict = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            newStartTime == null
                                ? 'Start Time'
                                : newStartTime!.format(ctx),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(appt.start),
                            );
                            if (picked != null) {
                              setState(() {
                                newStartTime = picked;
                                hasConflict = false;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            newEndTime == null
                                ? 'End Time'
                                : newEndTime!.format(ctx),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(appt.end),
                            );
                            if (picked != null) {
                              setState(() {
                                newEndTime = picked;
                                hasConflict = false;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: isChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                          isChecking ? 'Checking...' : 'Check Availability'),
                      onPressed: (newDate == null ||
                              newStartTime == null ||
                              newEndTime == null ||
                              isChecking)
                          ? null
                          : () async {
                              setState(() {
                                isChecking = true;
                                hasConflict = false;
                              });

                              final newStart = DateTime(
                                newDate!.year,
                                newDate!.month,
                                newDate!.day,
                                newStartTime!.hour,
                                newStartTime!.minute,
                              );
                              final newEnd = DateTime(
                                newDate!.year,
                                newDate!.month,
                                newDate!.day,
                                newEndTime!.hour,
                                newEndTime!.minute,
                              );

                              if (newEnd.isBefore(newStart) ||
                                  newEnd.isAtSameMomentAs(newStart)) {
                                setState(() {
                                  isChecking = false;
                                  hasConflict = true;
                                  conflictMessage =
                                      'End time must be after start time';
                                });
                                return;
                              }

                              // Check counsellor availability
                              final fs = ref.read(_fsProvider);
                              final conflicts =
                                  await fs.counsellorAppointmentsOverlapping(
                                counsellorId: appt.counsellorId,
                                start: newStart,
                                end: newEnd,
                              );

                              final relevantConflicts = conflicts
                                  .where((a) => a.id != appt.id)
                                  .toList();

                              setState(() {
                                isChecking = false;
                                hasConflict = relevantConflicts.isNotEmpty;
                                conflictMessage = hasConflict
                                    ? 'Counsellor has ${relevantConflicts.length} appointment(s) during this time'
                                    : 'Time slot is available!';
                              });
                            },
                    ),
                  ),
                  if (conflictMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hasConflict
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        border: Border.all(
                          color: hasConflict ? Colors.red : Colors.green,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasConflict ? Icons.error : Icons.check_circle,
                            color: hasConflict ? Colors.red : Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              conflictMessage,
                              style: TextStyle(
                                color: hasConflict ? Colors.red : Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (newDate == null ||
                      newStartTime == null ||
                      newEndTime == null ||
                      hasConflict ||
                      conflictMessage.isEmpty)
                  ? null
                  : () async {
                      final newStart = DateTime(
                        newDate!.year,
                        newDate!.month,
                        newDate!.day,
                        newStartTime!.hour,
                        newStartTime!.minute,
                      );
                      final newEnd = DateTime(
                        newDate!.year,
                        newDate!.month,
                        newDate!.day,
                        newEndTime!.hour,
                        newEndTime!.minute,
                      );

                      await ref.read(_fsProvider).rescheduleAppointment(
                            appt.id,
                            newStart,
                            newEnd,
                          );

                      Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Appointment rescheduled successfully')),
                        );
                      }
                    },
              child: const Text('Reschedule'),
            ),
          ],
        ),
      ),
    );
  }
}

// LEAVE MANAGEMENT TAB
class _LeaveManagementTab extends ConsumerStatefulWidget {
  final Future<T?> Function<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
  }) showCenteredDialog;

  const _LeaveManagementTab({required this.showCenteredDialog});

  @override
  ConsumerState<_LeaveManagementTab> createState() =>
      _LeaveManagementTabState();
}

class _LeaveManagementTabState extends ConsumerState<_LeaveManagementTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(_fsProvider);

    return StreamBuilder<List<UserProfile>>(
      stream: firestore.counsellors(),
      builder: (context, counsellorSnap) {
        if (counsellorSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final counsellors = counsellorSnap.data ?? [];
        final idToName = {for (final c in counsellors) c.uid: c.displayName};

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search by counsellor name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: firestore.allLeaves(),
                builder: (context, leaveSnap) {
                  if (leaveSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final leaves = leaveSnap.data ?? [];

                  final q = _search.trim().toLowerCase();
                  final filtered = q.isEmpty
                      ? leaves
                      : leaves.where((l) {
                          final name =
                              (idToName[l['userId']] ?? '').toLowerCase();
                          return name.contains(q);
                        }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No leaves found'));
                  }

                  return ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final leave = filtered[i];
                      final start = DateTime.fromMillisecondsSinceEpoch(
                          leave['startDate'] as int);
                      final end = DateTime.fromMillisecondsSinceEpoch(
                          leave['endDate'] as int);
                      final reason = leave['reason'] as String? ?? '';
                      final leaveType =
                          leave['leaveType'] as String? ?? 'leave';
                      final counsellorName =
                          idToName[leave['userId']] ?? 'Unknown';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.event_busy,
                              color: Colors.orange),
                          title: Text(
                            '${DateFormat('MMM dd, yyyy').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}',
                          ),
                          subtitle: Text(
                              '$counsellorName • $leaveType${reason.isNotEmpty ? ' • $reason' : ''}'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _showLeaveDetails(leave, counsellorName),
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

  void _showLeaveDetails(Map<String, dynamic> leave, String counsellorName) {
    final start =
        DateTime.fromMillisecondsSinceEpoch(leave['startDate'] as int);
    final end = DateTime.fromMillisecondsSinceEpoch(leave['endDate'] as int);
    final reason = leave['reason'] as String? ?? 'No reason provided';
    final leaveType = leave['leaveType'] as String? ?? 'general';

    widget.showCenteredDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Details'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Counsellor', counsellorName),
              _DetailRow(
                  'Start Date', DateFormat('MMM dd, yyyy').format(start)),
              _DetailRow('End Date', DateFormat('MMM dd, yyyy').format(end)),
              _DetailRow('Leave Type', leaveType.toUpperCase()),
              _DetailRow('Reason', reason),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: ctx,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content:
                      const Text('Are you sure you want to delete this leave?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(_fsProvider).deleteLeave(leave['id'] as String);
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Leave deleted')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ADMIN PROFILE TAB
class _AdminProfileTab extends ConsumerStatefulWidget {
  final String userId;

  const _AdminProfileTab({required this.userId});

  @override
  ConsumerState<_AdminProfileTab> createState() => _AdminProfileTabState();
}

class _AdminProfileTabState extends ConsumerState<_AdminProfileTab> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    return StreamBuilder<UserProfile?>(
      stream: ref.watch(_fsProvider).userProfile(widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data;
        if (profile == null) {
          return const Center(child: Text('Profile not found'));
        }

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 4,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          profile.displayName[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 40, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ProfileField(label: 'Name', value: profile.displayName),
                    const SizedBox(height: 16),
                    _ProfileField(label: 'Email', value: profile.email),
                    const SizedBox(height: 16),
                    _ProfileField(
                        label: 'Role', value: profile.role.name.toUpperCase()),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Change Password',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _oldPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _changePassword,
                        child: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text('Change Password'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _changePassword() async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    try {
      await ref.read(authServiceProvider).changePassword(
            currentPassword: oldPassword,
            newPassword: newPassword,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

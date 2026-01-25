import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../student/community_forum_page.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout')),
        ],
      ),
    );
    final confirmed = confirm ?? false;
    if (confirmed) {
      final auth = ref.read(authServiceProvider);
      await auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
              Tab(text: 'Students', icon: Icon(Icons.school)),
              Tab(text: 'Counsellors', icon: Icon(Icons.group)),
              Tab(text: 'Appointments', icon: Icon(Icons.event)),
              Tab(text: 'Leave Management', icon: Icon(Icons.event_busy)),
              Tab(text: 'Community', icon: Icon(Icons.forum)),
              Tab(text: 'Profile', icon: Icon(Icons.person)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _PlaceholderTab(label: 'Students'),
            _PlaceholderTab(label: 'Counsellors'),
            _PlaceholderTab(label: 'Appointments'),
            _LeaveManagementTab(),
            CommunityForumPage(embedded: true),
            _AdminProfileTab(),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('Overview',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Summary widgets can go here.'),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$label tab coming soon'));
  }
}

class _AdminProfileTab extends ConsumerWidget {
  const _AdminProfileTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Email: ${user.email}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            onPressed: () => context
                .findAncestorStateOfType<_AdminDashboardPageState>()
                ?._logout(),
          ),
        ],
      ),
    );
  }
}

class _LeaveManagementTab extends ConsumerStatefulWidget {
  const _LeaveManagementTab();

  @override
  ConsumerState<_LeaveManagementTab> createState() =>
      _LeaveManagementTabState();
}

class _LeaveManagementTabState extends ConsumerState<_LeaveManagementTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreServiceProvider);

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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search by counsellor name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Leave'),
                    onPressed: () =>
                        _showAddLeaveDialog(context, idToName, counsellors),
                  ),
                ],
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

                  final q = _searchController.text.trim().toLowerCase();
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
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await ref
                                  .read(firestoreServiceProvider)
                                  .deleteLeave(leave['id'] as String);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Leave deleted')),
                              );
                            },
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

  Future<void> _showAddLeaveDialog(
    BuildContext context,
    Map<String, String> idToName,
    List<UserProfile> counsellors,
  ) async {
    if (counsellors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No counsellors available')),
      );
      return;
    }

    String? selectedId = counsellors.first.uid;
    DateTimeRange? range;
    final reasonCtrl = TextEditingController();
    String leaveType = 'general';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Leave for Counsellor'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedId,
                  items: counsellors
                      .map((c) => DropdownMenuItem(
                          value: c.uid, child: Text(c.displayName)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedId = v),
                  decoration: const InputDecoration(
                      labelText: 'Counsellor', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: leaveType,
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'medical', child: Text('Medical')),
                  ],
                  onChanged: (v) => setState(() => leaveType = v ?? 'general'),
                  decoration: const InputDecoration(
                      labelText: 'Leave Type', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(range == null
                            ? 'Pick date range'
                            : '${DateFormat('MMM dd, yyyy').format(range!.start)} - ${DateFormat('MMM dd, yyyy').format(range!.end)}'),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDateRangePicker(
                            context: ctx,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 2),
                            initialDateRange: range,
                          );
                          if (picked != null) setState(() => range = picked);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedId == null || range == null) return;
                final fs = ref.read(firestoreServiceProvider);
                final conflicts = await fs.counsellorAppointmentsOverlapping(
                  counsellorId: selectedId!,
                  start: range!.start,
                  end: range!.end,
                );
                if (conflicts.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Conflicts with existing bookings')),
                  );
                  return;
                }
                await fs.addLeave(
                  userId: selectedId!,
                  startDate: range!.start,
                  endDate: range!.end,
                  reason: reasonCtrl.text.trim(),
                  leaveType: leaveType,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Leave added for ${idToName[selectedId!]}')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    reasonCtrl.dispose();
  }
}

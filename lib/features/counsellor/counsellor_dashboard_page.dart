import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';

final _fsProvider = Provider((ref) => FirestoreService());

class CounsellorDashboardPage extends ConsumerStatefulWidget {
  const CounsellorDashboardPage({super.key});

  @override
  ConsumerState<CounsellorDashboardPage> createState() => _CounsellorDashboardPageState();
}

class _CounsellorDashboardPageState extends ConsumerState<CounsellorDashboardPage> {

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
      await ref.read(authServiceProvider).signOut();
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

    final tabs = [
      const _NextSessionsTab(),
      _AssignedStudentsTab(counsellorId: user.uid),
      _LeaveManagementTab(counsellorId: user.uid),
      _CounsellorProfileTab(userId: user.uid),
    ];

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Counsellor Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Next Sessions'),
              Tab(text: 'Assigned Students'),
              Tab(text: 'Leave Management'),
              Tab(text: 'Profile'),
            ],
          ),
        ),
        body: TabBarView(children: tabs),
      ),
    );
  }
}

// Tab 1: Next Sessions
class _NextSessionsTab extends ConsumerWidget {
  const _NextSessionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Center(child: Text('Not signed in'));

    final stream = ref.watch(_fsProvider).appointmentsForCounsellor(user.uid);

    return StreamBuilder<List<Appointment>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final appts = snapshot.data!;
        final upcoming = appts.where((a) => a.start.isAfter(DateTime.now())).toList();
        final past = appts.where((a) => a.start.isBefore(DateTime.now())).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Upcoming Sessions',
              child: upcoming.isEmpty
                  ? const Text('No upcoming sessions')
                  : Column(
                      children: upcoming
                          .map((a) => _SessionCard(
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
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Past Sessions',
              child: past.isEmpty
                  ? const Text('No past sessions')
                  : Column(
                      children: past
                          .map((a) => _SessionCard(
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
                                showFeedback: true,
                              ))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SessionCard extends ConsumerStatefulWidget {
  const _SessionCard({
    required this.appointment,
    required this.onUpdate,
    this.showFeedback = false,
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

  Future<void> _showDetailsDialog() async {
    final notesController = TextEditingController(text: widget.appointment.counsellorNotes);
    final planController = TextEditingController(text: widget.appointment.followUpPlan);
    final meetLinkController = TextEditingController(text: _meetLink);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Topic: ${widget.appointment.topic ?? "N/A"}'),
              const SizedBox(height: 8),
              Text('Session Type: ${widget.appointment.sessionType == SessionType.online ? "Online" : "Face-to-Face"}'),
              if (widget.appointment.initialProblem != null) ...[
                const SizedBox(height: 8),
                Text('Initial Problem:\n${widget.appointment.initialProblem}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
              if (widget.appointment.notes != null) ...[
                const SizedBox(height: 8),
                Text('Student Notes:\n${widget.appointment.notes}'),
              ],
              if (widget.appointment.sentiment != null) ...[
                const SizedBox(height: 8),
                Text('Sentiment: ${widget.appointment.sentiment} (${widget.appointment.riskLevel ?? "N/A"})'),
              ],
              const Divider(),
              if (widget.appointment.sessionType == SessionType.online) ...[
                TextField(
                  controller: meetLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Google Meet Link',
                    hintText: 'https://meet.google.com/xxx-xxxx-xxx',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Counsellor Notes'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: planController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Follow-up Plan'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _meetLink = meetLinkController.text.trim());
              widget.onUpdate(
                widget.appointment.status,
                notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                planController.text.trim().isEmpty ? null : planController.text.trim(),
                meetLinkController.text.trim().isEmpty ? null : meetLinkController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, h:mm a');
    return Card(
      child: ListTile(
        title: Text(widget.appointment.topic ?? 'Session'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(df.format(widget.appointment.start)),
            Text('Type: ${widget.appointment.sessionType == SessionType.online ? "Online" : "Face-to-Face"}'),
            if (widget.appointment.initialProblem != null)
              Text('Problem: ${widget.appointment.initialProblem}', maxLines: 1, overflow: TextOverflow.ellipsis),
            if (widget.appointment.sessionType == SessionType.online && _meetLink != null)
              Text('Meet: $_meetLink', maxLines: 1, overflow: TextOverflow.ellipsis),
            if (widget.showFeedback && widget.appointment.studentComment != null)
              Text('Student feedback: ${widget.appointment.studentComment}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.appointment.status.name),
            PopupMenuButton<AppointmentStatus>(
              onSelected: (status) => widget.onUpdate(status, null, null, null),
              itemBuilder: (_) => const [
                PopupMenuItem(value: AppointmentStatus.confirmed, child: Text('Confirm')),
                PopupMenuItem(value: AppointmentStatus.completed, child: Text('Mark done')),
                PopupMenuItem(value: AppointmentStatus.cancelled, child: Text('Cancel')),
              ],
            ),
          ],
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
    
    return StreamBuilder<List<UserProfile>>(
      stream: fs.assignedStudents(counsellorId),
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

  Future<void> _showStudentDetails(BuildContext context, WidgetRef ref) async {
    final fs = ref.read(_fsProvider);
    
    // Fetch risk flags, journals, moods
    final riskFlags = await fs.highRiskFlags(student.uid).first;
    final journals = await fs.journalEntries(student.uid).first;
    final moods = await fs.moodEntries(student.uid).first;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${student.displayName} Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${student.email}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              Text('Date of Birth: ${student.dateOfBirth ?? "N/A"}'),
              Text('Gender: ${student.gender ?? "N/A"}'),
              if (student.medicalConditions != null && student.medicalConditions!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Medical Conditions:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(student.medicalConditions!),
              ],
              const Divider(),
              if (riskFlags.isNotEmpty) ...[
                const Text('⚠️ Risk Flags:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ...riskFlags.map((flag) => Text('• ${flag['sentiment']} (${flag['riskLevel']}) - ${DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(flag['flaggedAt']))}')),
                const Divider(),
              ],
              if (journals.isNotEmpty) ...[
                const Text('Recent Journal Entries:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...journals.take(3).map((j) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${DateFormat('MMM d').format(j.createdAt)}: ${j.content.length > 50 ? "${j.content.substring(0, 50)}..." : j.content}'),
                    )),
                const Divider(),
              ],
              if (moods.isNotEmpty) ...[
                const Text('Recent Mood Entries:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...moods.take(5).map((m) => Text('${DateFormat('MMM d').format(m.timestamp)}: Score ${m.moodScore}/10 - ${m.note.length > 30 ? "${m.note.substring(0, 30)}..." : m.note}')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(student.displayName[0].toUpperCase())),
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
        onTap: () => _showStudentDetails(context, ref),
      ),
    );
  }
}

// Tab 3: Leave Management
class _LeaveManagementTab extends ConsumerWidget {
  const _LeaveManagementTab({required this.counsellorId});

  final String counsellorId;

  Future<void> _showAddLeaveDialog(BuildContext context, WidgetRef ref) async {
    DateTime? startDate;
    DateTime? endDate;
    String leaveType = 'medical';
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Leave'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: leaveType,
                  decoration: const InputDecoration(labelText: 'Leave Type'),
                  items: const [
                    DropdownMenuItem(value: 'medical', child: Text('Medical')),
                    DropdownMenuItem(value: 'personal', child: Text('Personal')),
                    DropdownMenuItem(value: 'vacation', child: Text('Vacation')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => leaveType = value);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(startDate != null ? DateFormat('MMM d, y').format(startDate!) : 'Not selected'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => startDate = picked);
                  },
                ),
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text(endDate != null ? DateFormat('MMM d, y').format(endDate!) : 'Not selected'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: startDate ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => endDate = picked);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason (optional)'),
                  maxLines: 2,
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
              onPressed: startDate != null && endDate != null
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Add Leave'),
            ),
          ],
        ),
      ),
    );

    if (result == true && startDate != null && endDate != null) {
      try {
        await ref.read(_fsProvider).addLeave(
          userId: counsellorId,
          startDate: startDate!,
          endDate: endDate!,
          reason: reasonController.text.trim(),
          leaveType: leaveType,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leave added successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

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
              child: ElevatedButton.icon(
                onPressed: () => _showAddLeaveDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add Leave'),
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
                        final startDate = DateTime.fromMillisecondsSinceEpoch(leave['startDate']);
                        final endDate = DateTime.fromMillisecondsSinceEpoch(leave['endDate']);
                        
                        return Card(
                          child: ListTile(
                            title: Text('${leave['leaveType']} Leave'),
                            subtitle: Text('${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)}\n${leave['reason'] ?? ""}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Leave'),
                                    content: const Text('Are you sure?'),
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
                                  await ref.read(_fsProvider).deleteLeave(leave['id']);
                                }
                              },
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
  }
}

// Tab 4: Profile
class _CounsellorProfileTab extends ConsumerStatefulWidget {
  const _CounsellorProfileTab({required this.userId});

  final String userId;

  @override
  ConsumerState<_CounsellorProfileTab> createState() => _CounsellorProfileTabState();
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
              decoration: const InputDecoration(labelText: 'Confirm New Password'),
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
                  const SnackBar(content: Text('Password must be at least 8 characters with 1 special character')),
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
                    const SnackBar(content: Text('Password changed successfully')),
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
    final auth = ref.read(authServiceProvider);
    
    try {
      await auth.updateDisplayName(_nameController.text.trim());
      await fs.updateUserProfile(
        uid: widget.userId,
        data: {
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
                    decoration: const InputDecoration(labelText: 'Email (read-only)'),
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

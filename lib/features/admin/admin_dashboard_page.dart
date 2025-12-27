import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/appointment.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';
import '../student/community_forum_page.dart';

final firestoreProvider = Provider((ref) => FirestoreService());

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);

    return PrimaryScaffold(
      title: 'Admin Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: () async {
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
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await authService.signOut();
            }
          },
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
                    label: 'Add Counsellor',
                    index: 1,
                    selected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1)),
                _TabButton(
                    label: 'Manage Students',
                    index: 2,
                    selected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2)),
                _TabButton(
                    label: 'Manage Counsellors',
                    index: 3,
                    selected: _selectedTab == 3,
                    onTap: () => setState(() => _selectedTab = 3)),
                _TabButton(
                    label: 'Appointments',
                    index: 4,
                    selected: _selectedTab == 4,
                    onTap: () => setState(() => _selectedTab = 4)),
                _TabButton(
                    label: 'Leave Management',
                    index: 5,
                    selected: _selectedTab == 5,
                    onTap: () => setState(() => _selectedTab = 5)),
                _TabButton(
                    label: 'Community',
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
              children: const [
                _OverviewTab(),
                _AddCounsellorTab(),
                _ManageStudentsTab(),
                _ManageCounsellorsTab(),
                _ManageAppointmentsTab(),
                _LeaveManagementTab(),
                CommunityForumPage(embedded: true),
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

  const _TabButton(
      {required this.label,
      required this.index,
      required this.selected,
      required this.onTap});

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

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);

    return ListView(
      children: [
        StreamBuilder<List<UserProfile>>(
          stream: firestore.allStudents(),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            return SectionCard(
              title: 'Students',
              child: Text('Total: $count students'),
            );
          },
        ),
        StreamBuilder<List<UserProfile>>(
          stream: firestore.counsellors(),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            return SectionCard(
              title: 'Counsellors',
              child: Text('Total: $count counsellors'),
            );
          },
        ),
        StreamBuilder<List<Appointment>>(
          stream: firestore.allAppointments(),
          builder: (context, snapshot) {
            final all = snapshot.data ?? [];
            final upcoming =
                all.where((a) => a.start.isAfter(DateTime.now())).length;
            return SectionCard(
              title: 'Appointments',
              child: Text('Total: ${all.length} (Upcoming: $upcoming)'),
            );
          },
        ),
      ],
    );
  }
}

class _AddCounsellorTab extends ConsumerStatefulWidget {
  const _AddCounsellorTab();

  @override
  ConsumerState<_AddCounsellorTab> createState() => _AddCounsellorTabState();
}

class _AddCounsellorTabState extends ConsumerState<_AddCounsellorTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _counsellorIdController = TextEditingController();
  final _designationController = TextEditingController();
  final _expertiseController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _counsellorIdController.dispose();
    _designationController.dispose();
    _expertiseController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createCounsellor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).createCounsellorWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            displayName: _nameController.text.trim(),
            counsellorId: _counsellorIdController.text.trim(),
            designation: _designationController.text.trim(),
            expertise: _expertiseController.text.trim(),
          );

      if (mounted) {
        // Simple success popup; keep admin logged in
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Counsellor Created'),
              ],
            ),
            content: Text(
              'Successfully created: ${_nameController.text.trim()}. The counsellor can now log in and will be prompted to change their temporary password.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        setState(() => _loading = false);
        _nameController.clear();
        _emailController.clear();
        _counsellorIdController.clear();
        _designationController.clear();
        _expertiseController.clear();
        _passwordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Add New Counsellor',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
                labelText: 'Full Name', border: OutlineInputBorder()),
            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
                labelText: 'Email', border: OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _counsellorIdController,
            decoration: const InputDecoration(
                labelText: 'Counsellor ID', border: OutlineInputBorder()),
            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _designationController,
            decoration: const InputDecoration(
                labelText: 'Designation', border: OutlineInputBorder()),
            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _expertiseController,
            decoration: const InputDecoration(
                labelText: 'Expertise', border: OutlineInputBorder()),
            maxLines: 3,
            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Temporary Password',
              border: OutlineInputBorder(),
              helperText: 'Counsellor must change on first login',
            ),
            obscureText: true,
            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _createCounsellor,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Create Counsellor'),
          ),
        ],
      ),
    );
  }
}

class _ManageStudentsTab extends ConsumerWidget {
  const _ManageStudentsTab();

  Future<void> _showStudentDetails(
      BuildContext context, WidgetRef ref, UserProfile student) async {
    final firestore = ref.read(firestoreProvider);

    // Fetch student's appointments with reviews
    final appointments =
        await firestore.appointmentsForStudent(student.uid).first;
    final reviewedAppointments = appointments
        .where((a) => a.studentRating != null || a.studentComment != null)
        .toList();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${student.displayName} - Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${student.email}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Student ID: ${student.studentId ?? "N/A"}'),
                Text('Phone: ${student.phoneNumber ?? "N/A"}'),
                Text('Date of Birth: ${student.dateOfBirth ?? "N/A"}'),
                Text('Gender: ${student.gender ?? "N/A"}'),
                if (student.counsellorId != null)
                  Text('Counsellor ID: ${student.counsellorId}'),
                const Divider(height: 24),

                // Medical Information
                const Text('Medical Information:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text('Blood Type: ${student.bloodType ?? "N/A"}'),
                Text('Allergies: ${student.allergies ?? "None"}'),
                if (student.medicalConditions != null &&
                    student.medicalConditions!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Medical Conditions: ${student.medicalConditions}'),
                ],
                Text('Emergency Contact: ${student.emergencyContact ?? "N/A"}'),
                Text(
                    'Emergency Phone: ${student.emergencyContactPhone ?? "N/A"}'),
                const Divider(height: 24),

                // Reviews Section
                Text('Session Reviews (${reviewedAppointments.length}):',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (reviewedAppointments.isEmpty)
                  const Text('No reviews yet',
                      style: TextStyle(color: Colors.grey))
                else
                  ...reviewedAppointments.map((appt) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                      DateFormat('MMM d, y').format(appt.start),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  if (appt.studentRating != null)
                                    Row(
                                      children: [
                                        ...List.generate(
                                            appt.studentRating!,
                                            (i) => const Icon(Icons.star,
                                                size: 16, color: Colors.amber)),
                                        ...List.generate(
                                            5 - appt.studentRating!,
                                            (i) => const Icon(Icons.star_border,
                                                size: 16, color: Colors.grey)),
                                      ],
                                    ),
                                ],
                              ),
                              if (appt.topic != null)
                                Text('Topic: ${appt.topic}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              if (appt.studentComment != null &&
                                  appt.studentComment!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(appt.studentComment!,
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic)),
                              ],
                              const SizedBox(height: 8),
                              // Approval Status
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: appt.isReviewApproved
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      appt.isReviewApproved
                                          ? Icons.check_circle
                                          : Icons.pending,
                                      color: appt.isReviewApproved
                                          ? Colors.green
                                          : Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      appt.isReviewApproved
                                          ? 'Approved'
                                          : 'Pending Approval',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: appt.isReviewApproved
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!appt.isReviewApproved)
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                        ),
                                        onPressed: () async {
                                          await firestore
                                              .updateAppointmentStatus(
                                            appointmentId: appt.id,
                                            status: appt.status,
                                          );
                                          // Update approval status
                                          await FirebaseFirestore.instance
                                              .collection('appointments')
                                              .doc(appt.id)
                                              .update(
                                                  {'isReviewApproved': true});
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            _showStudentDetails(
                                                context, ref, student);
                                          }
                                        },
                                        child: const Text('Approve',
                                            style: TextStyle(fontSize: 11)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
              ],
            ),
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
    final firestore = ref.watch(firestoreProvider);
    final authService = ref.watch(authServiceProvider);

    return StreamBuilder<List<UserProfile>>(
      stream: firestore.allStudents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = snapshot.data ?? [];
        if (students.isEmpty) {
          return const Center(child: Text('No students found'));
        }

        return ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, i) {
            final student = students[i];
            final isActive = student.isActive;

            return ListTile(
              leading: Icon(Icons.person,
                  color: isActive ? Colors.blue : Colors.grey),
              title: Text(student.displayName),
              subtitle:
                  Text('${student.email}\nID: ${student.studentId ?? "N/A"}'),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'details',
                    child: Text('View Details'),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(isActive ? 'Disable' : 'Enable'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'details') {
                    _showStudentDetails(context, ref, student);
                  } else if (value == 'toggle') {
                    await authService.toggleUserStatus(student.uid, !isActive);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isActive
                                ? 'Student disabled'
                                : 'Student enabled')),
                      );
                    }
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Student'),
                        content:
                            Text('Permanently delete ${student.displayName}?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await authService.deleteUserAccount(student.uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Student deleted')),
                        );
                      }
                    }
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ManageCounsellorsTab extends ConsumerWidget {
  const _ManageCounsellorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);
    final authService = ref.watch(authServiceProvider);

    return StreamBuilder<List<UserProfile>>(
      stream: firestore.counsellors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final counsellors = snapshot.data ?? [];
        if (counsellors.isEmpty) {
          return const Center(child: Text('No counsellors found'));
        }

        return ListView.builder(
          itemCount: counsellors.length,
          itemBuilder: (context, i) {
            final counsellor = counsellors[i];

            return ExpansionTile(
              leading: const Icon(Icons.psychology, color: Colors.purple),
              title: Text(counsellor.displayName),
              subtitle: Text(counsellor.email),
              trailing: IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'View Details',
                onPressed: () => _showCounsellorDetails(context, counsellor),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.block),
                            label: const Text('Disable'),
                            onPressed: () async {
                              await authService.toggleUserStatus(
                                  counsellor.uid, false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Counsellor disabled')),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text('Delete',
                                style: TextStyle(color: Colors.red)),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Counsellor'),
                                  content: Text(
                                      'Permanently delete ${counsellor.displayName}?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel')),
                                    ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await authService
                                    .deleteUserAccount(counsellor.uid);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Counsellor deleted')),
                                  );
                                }
                              }
                            },
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
      },
    );
  }

  void _showCounsellorDetails(BuildContext context, UserProfile counsellor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Counsellor Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                child: Text(
                  counsellor.displayName[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Name', value: counsellor.displayName),
              _DetailRow(label: 'Email', value: counsellor.email),
              if (counsellor.counsellorId != null)
                _DetailRow(
                    label: 'Counsellor ID', value: counsellor.counsellorId!),
              if (counsellor.designation != null)
                _DetailRow(
                    label: 'Designation', value: counsellor.designation!),
              if (counsellor.expertise != null)
                _DetailRow(label: 'Expertise', value: counsellor.expertise!),
              _DetailRow(
                label: 'Account Status',
                value: counsellor.isActive != false ? 'Active' : 'Inactive',
              ),
              _DetailRow(label: 'User ID', value: counsellor.uid),
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
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageAppointmentsTab extends ConsumerWidget {
  const _ManageAppointmentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);

    return StreamBuilder<List<Appointment>>(
      stream: firestore.allAppointments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data ?? [];
        if (appointments.isEmpty) {
          return const Center(child: Text('No appointments found'));
        }

        return ListView.builder(
          itemCount: appointments.length,
          itemBuilder: (context, i) {
            final apt = appointments[i];
            final isDup = apt.isDuplicate == true;

            return Card(
              color: isDup ? Colors.red.shade50 : null,
              child: ListTile(
                leading:
                    Icon(Icons.event, color: isDup ? Colors.red : Colors.blue),
                title: Text(
                    '${DateFormat('MMM dd, yyyy').format(apt.start)} at ${DateFormat('h:mm a').format(apt.start)}'),
                subtitle: Text(
                    'Status: ${apt.status.name}${isDup ? " (DUPLICATE)" : ""}'),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'reschedule', child: Text('Reschedule')),
                    const PopupMenuItem(
                        value: 'reassign', child: Text('Reassign Counsellor')),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await firestore.deleteAppointment(apt.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Appointment deleted')));
                      }
                    }
                    if (value == 'reschedule') {
                      DateTime? newStart = apt.start;
                      DateTime? newEnd = apt.end;
                      // Pick new date
                      final date = await showDatePicker(
                        context: context,
                        initialDate: apt.start,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date == null) return;
                      // Pick start time
                      final startTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(apt.start),
                      );
                      if (startTime == null) return;
                      // Pick end time
                      final endTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(apt.end),
                      );
                      if (endTime == null) return;

                      newStart = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        startTime.hour,
                        startTime.minute,
                      );
                      newEnd = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        endTime.hour,
                        endTime.minute,
                      );

                      await firestore.rescheduleAppointment(
                          apt.id, newStart, newEnd);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Appointment rescheduled')),
                        );
                      }
                    }
                    if (value == 'reassign') {
                      // Pick counsellor
                      final counsellors = await firestore.counsellors().first;
                      String? selectedId;
                      await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Reassign Counsellor'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: DropdownButtonFormField<String>(
                              value: selectedId,
                              items: counsellors
                                  .map((c) => DropdownMenuItem(
                                        value: c.uid,
                                        child: Text(c.displayName),
                                      ))
                                  .toList(),
                              onChanged: (v) => selectedId = v,
                              decoration: const InputDecoration(
                                labelText: 'Select counsellor',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                if (selectedId == null) return;
                                await firestore.reassignAppointment(
                                    apt.id, selectedId!);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Counsellor reassigned')),
                                  );
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LeaveManagementTab extends ConsumerWidget {
  const _LeaveManagementTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);

    return StreamBuilder<List<UserProfile>>(
      stream: firestore.counsellors(),
      builder: (context, snapshot) {
        final counsellors = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Leave for Counsellor'),
              onPressed: () => _showAddLeaveDialog(context, ref, counsellors),
            ),
            const SizedBox(height: 16),
            Text('Active Leaves',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...counsellors.map((counsellor) => ExpansionTile(
                  title: Text(counsellor.displayName),
                  subtitle: Text(counsellor.email),
                  children: [
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: firestore.userLeaves(counsellor.uid),
                      builder: (context, leaveSnapshot) {
                        final leaves = leaveSnapshot.data ?? [];
                        if (leaves.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No leaves scheduled'),
                          );
                        }

                        return Column(
                          children: leaves.map((leave) {
                            final startDate =
                                DateTime.fromMillisecondsSinceEpoch(
                                    leave['startDate'] as int);
                            final endDate = DateTime.fromMillisecondsSinceEpoch(
                                leave['endDate'] as int);
                            final reason = leave['reason'] as String;
                            final leaveType = leave['leaveType'] as String;

                            return ListTile(
                              leading: Icon(
                                leaveType == 'medical'
                                    ? Icons.medical_services
                                    : Icons.event_busy,
                                color: Colors.orange,
                              ),
                              title: Text(
                                  '${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}'),
                              subtitle: Text('$leaveType: $reason'),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  await firestore
                                      .deleteLeave(leave['id'] as String);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Leave deleted')),
                                    );
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                )),
          ],
        );
      },
    );
  }

  Future<void> _showAddLeaveDialog(BuildContext context, WidgetRef ref,
      List<UserProfile> counsellors) async {
    if (counsellors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No counsellors available')),
      );
      return;
    }

    String? selectedCounsellorId;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Select Counsellor'),
                  value: selectedCounsellorId,
                  items: counsellors
                      .map((c) => DropdownMenuItem(
                            value: c.uid,
                            child: Text(c.displayName),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedCounsellorId = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Leave Type'),
                  value: leaveType,
                  items: const [
                    DropdownMenuItem(
                        value: 'medical', child: Text('Medical Leave')),
                    DropdownMenuItem(
                        value: 'personal', child: Text('Personal Leave')),
                    DropdownMenuItem(
                        value: 'vacation', child: Text('Vacation')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => leaveType = value!),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(startDate == null
                      ? 'Select Start Date'
                      : 'Start: ${DateFormat('MMM dd, yyyy').format(startDate!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => startDate = date);
                  },
                ),
                ListTile(
                  title: Text(endDate == null
                      ? 'Select End Date'
                      : 'End: ${DateFormat('MMM dd, yyyy').format(endDate!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: startDate ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => endDate = date);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
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
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add Leave'),
            ),
          ],
        ),
      ),
    );

    if (result == true &&
        selectedCounsellorId != null &&
        startDate != null &&
        endDate != null) {
      try {
        await ref.read(firestoreProvider).addLeave(
              userId: selectedCounsellorId!,
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
}

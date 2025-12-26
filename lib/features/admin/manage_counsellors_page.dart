import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/appointment.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';

final _fsProvider = Provider((ref) => FirestoreService());
final _authProvider = Provider((ref) => AuthService());

class ManageCounsellorsPage extends ConsumerStatefulWidget {
  const ManageCounsellorsPage({super.key});

  @override
  ConsumerState<ManageCounsellorsPage> createState() => _ManageCounsellorsPageState();
}

class _ManageCounsellorsPageState extends ConsumerState<ManageCounsellorsPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _inviteCounsellor() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final uid = _email.text.trim(); // use email as deterministic id stub
      await ref.read(_authProvider).createCounsellor(
            email: _email.text.trim(),
            displayName: _name.text.trim(),
            uid: uid,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Counsellor record created. Create auth user via Console/Admin SDK.')),
        );
        _name.clear();
        _email.clear();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counsellorStream = ref.watch(_fsProvider).counsellors();
    final duplicateStream = ref.watch(_fsProvider).duplicateAppointments();

    return PrimaryScaffold(
      title: 'Manage counsellors',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Add counsellor (DB record)',
            child: Column(
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _sending ? null : _inviteCounsellor,
                  child: _sending ? const CircularProgressIndicator() : const Text('Create record'),
                ),
                const SizedBox(height: 8),
                const Text('Note: To create login credentials, use Firebase Console/Admin SDK, then the counsellor resets password on first login.'),
              ],
            ),
          ),
          SectionCard(
            title: 'Active counsellors',
            child: StreamBuilder<List<UserProfile>>(
              stream: counsellorStream,
              builder: (context, snapshot) {
                final list = snapshot.data ?? [];
                if (list.isEmpty) return const Text('None yet');
                return Column(
                  children: list
                      .map(
                        (c) => ListTile(
                          title: Text(c.displayName),
                          subtitle: Text(c.email),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => ref.read(_fsProvider).deleteUserProfile(c.uid),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          SectionCard(
            title: 'Duplicate bookings',
            child: StreamBuilder<List<Appointment>>(
              stream: duplicateStream,
              builder: (context, snapshot) {
                final dups = snapshot.data ?? [];
                if (dups.isEmpty) return const Text('No duplicates detected');
                return Column(
                  children: dups
                      .map((a) => ListTile(
                            title: Text(a.topic ?? 'Session'),
                            subtitle: Text('Student ${a.studentId} • ${DateTime.fromMillisecondsSinceEpoch(a.start.millisecondsSinceEpoch)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () => ref.read(_fsProvider).updateAppointmentStatus(
                                    appointmentId: a.id,
                                    status: AppointmentStatus.cancelled,
                                  ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

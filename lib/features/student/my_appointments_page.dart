import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';

final _fsProvider = Provider((ref) => FirestoreService());

class MyAppointmentsPage extends ConsumerWidget {
  const MyAppointmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const PrimaryScaffold(
        title: 'My appointments',
        body: Center(child: Text('Please sign in')),
      );
    }

    // Use appointmentsForUser so the same appointment shows for all participants
    final stream = ref.watch(_fsProvider).appointmentsForUser(user.uid);

    return PrimaryScaffold(
      title: 'My appointments',
      body: StreamBuilder<List<Appointment>>(
        stream: stream,
        builder: (context, snapshot) {
          final appts = snapshot.data ?? [];
          if (appts.isEmpty) {
            return const SectionCard(
              title: 'No appointments yet',
              child: Text('Book a slot to get started.'),
            );
          }

          return ListView.builder(
            itemCount: appts.length,
            itemBuilder: (context, index) {
              final a = appts[index];
              return Card(
                child: ListTile(
                  title: Text(a.topic ?? 'Session'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('MMM d, h:mm a').format(a.start)),
                      Text('Status: ${a.status.name}'),
                      if (a.notes != null) Text('Notes: ${a.notes}'),
                      if (a.isDuplicate)
                        const Text('Potential duplicate booking',
                            style: TextStyle(color: Colors.red)),
                      if (a.studentRating != null)
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                            Text('${a.studentRating}/5'),
                          ],
                        ),
                    ],
                  ),
                  trailing: a.status == AppointmentStatus.completed &&
                          a.studentRating == null
                      ? IconButton(
                          icon: const Icon(Icons.rate_review),
                          onPressed: () => _showRatingSheet(context, ref, a.id),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showRatingSheet(
      BuildContext context, WidgetRef ref, String appointmentId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        double rating = 5;
        final comment = TextEditingController();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Rate your session'),
                  Slider(
                    min: 1,
                    max: 5,
                    divisions: 4,
                    value: rating,
                    label: rating.toStringAsFixed(0),
                    onChanged: (v) => setSheetState(() => rating = v),
                  ),
                  TextField(
                    controller: comment,
                    decoration:
                        const InputDecoration(labelText: 'Comment (optional)'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(_fsProvider).submitRating(
                            appointmentId: appointmentId,
                            rating: rating.toInt(),
                            comment: comment.text.trim().isEmpty
                                ? null
                                : comment.text.trim(),
                          );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Submit'),
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

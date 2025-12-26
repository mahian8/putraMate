import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';

final _fsProvider = Provider((ref) => FirestoreService());

class CounsellorDashboardPage extends ConsumerWidget {
  const CounsellorDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const PrimaryScaffold(
        title: 'Counsellor dashboard',
        body: Center(child: Text('Please sign in')),
      );
    }

    final stream = ref.watch(_fsProvider).appointmentsForCounsellor(user.uid);

    return PrimaryScaffold(
      title: 'Counsellor dashboard',
      body: StreamBuilder<List<Appointment>>(
        stream: stream,
        builder: (context, snapshot) {
          final appts = snapshot.data ?? [];
          final upcoming = appts.where((a) => a.start.isAfter(DateTime.now())).toList();
          final past = appts.where((a) => a.start.isBefore(DateTime.now())).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Today & upcoming',
                child: upcoming.isEmpty
                    ? const Text('No upcoming sessions')
                    : Column(
                        children: upcoming
                            .map((a) => _AppointmentRow(
                                  appointment: a,
                                  onUpdate: (status) => ref
                                      .read(_fsProvider)
                                      .updateAppointmentStatus(
                                        appointmentId: a.id,
                                        status: status,
                                      ),
                                ))
                            .toList(),
                      ),
              ),
              SectionCard(
                title: 'Past sessions',
                child: past.isEmpty
                    ? const Text('No past sessions')
                    : Column(
                        children: past
                            .map((a) => _AppointmentRow(
                                  appointment: a,
                                  onUpdate: (status) => ref
                                      .read(_fsProvider)
                                      .updateAppointmentStatus(
                                        appointmentId: a.id,
                                        status: status,
                                      ),
                                  showFeedback: true,
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

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({
    required this.appointment,
    required this.onUpdate,
    this.showFeedback = false,
  });

  final Appointment appointment;
  final ValueChanged<AppointmentStatus> onUpdate;
  final bool showFeedback;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(appointment.topic ?? 'Session'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM d, h:mm a').format(appointment.start)),
            if (appointment.notes != null) Text('Note: ${appointment.notes}'),
            if (appointment.studentComment != null)
              Text('Student feedback: ${appointment.studentComment}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(appointment.status.name),
            PopupMenuButton<AppointmentStatus>(
              onSelected: onUpdate,
              itemBuilder: (_) => const [
                PopupMenuItem(value: AppointmentStatus.confirmed, child: Text('Confirm')),
                PopupMenuItem(value: AppointmentStatus.completed, child: Text('Mark done')),
                PopupMenuItem(value: AppointmentStatus.cancelled, child: Text('Cancel')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/appointment.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../common/common_widgets.dart';

class AppointmentDetailPage extends ConsumerWidget {
  const AppointmentDetailPage({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);
    final df = DateFormat('EEEE, MMM d, y \\at h:mm a');

    return PrimaryScaffold(
      title: 'Appointment Details',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Counsellor Info
            StreamBuilder<UserProfile?>(
              stream: fs.userProfile(appointment.counsellorId),
              builder: (context, snapshot) {
                final counsellor = snapshot.data;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        counsellor?.displayName.isNotEmpty == true
                            ? counsellor!.displayName[0].toUpperCase()
                            : 'C',
                      ),
                    ),
                    title: Text(
                      counsellor?.displayName ?? 'Counsellor',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(counsellor?.email ?? ''),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Session Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      context,
                      'Topic',
                      appointment.topic ?? 'General Session',
                    ),
                    _buildDetailRow(
                      context,
                      'Date & Time',
                      df.format(appointment.start),
                    ),
                    _buildDetailRow(
                      context,
                      'Status',
                      appointment.status.name.toUpperCase(),
                    ),
                    _buildDetailRow(
                      context,
                      'Type',
                      appointment.sessionType == SessionType.online
                          ? 'Online'
                          : 'Face-to-Face',
                    ),
                    if (appointment.initialProblem != null)
                      _buildDetailRow(
                        context,
                        'Problem',
                        appointment.initialProblem!,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Meet Link (if online and confirmed)
            if (appointment.sessionType == SessionType.online &&
                appointment.meetLink != null &&
                appointment.meetLink!.isNotEmpty)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.video_call,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Online Meeting Link',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse(appointment.meetLink!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  appointment.meetLink!,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.open_in_new,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click the link above to join the online session',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),

            // Counsellor Notes
            if (appointment.counsellorNotes != null &&
                appointment.counsellorNotes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Counsellor Notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(appointment.counsellorNotes!),
                    ],
                  ),
                ),
              ),
            ],

            // Follow-up Plan
            if (appointment.followUpPlan != null &&
                appointment.followUpPlan!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Follow-up Plan',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(appointment.followUpPlan!),
                    ],
                  ),
                ),
              ),
            ],

            // Your Review
            if (appointment.studentRating != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Review',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              Icons.star,
                              size: 20,
                              color: i < appointment.studentRating!
                                  ? Colors.amber
                                  : Colors.grey.shade300,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${appointment.studentRating}/5',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (appointment.studentComment != null &&
                          appointment.studentComment!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(appointment.studentComment!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// Route wrapper to support /student/appointment/:id via GoRouter
class AppointmentDetailRoutePage extends ConsumerWidget {
  const AppointmentDetailRoutePage({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);
    return StreamBuilder<Appointment?>(
      stream: fs.appointmentById(appointmentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PrimaryScaffold(
            title: 'Appointment Details',
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final appt = snapshot.data;
        if (appt == null) {
          return const PrimaryScaffold(
            title: 'Appointment Details',
            body: Center(child: Text('Appointment not found.')),
          );
        }
        return AppointmentDetailPage(appointment: appt);
      },
    );
  }
}

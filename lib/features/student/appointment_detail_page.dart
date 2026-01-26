import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final tf = DateFormat('h:mm a');
    final durationMinutes =
        appointment.end.difference(appointment.start).inMinutes;

    return PrimaryScaffold(
      title: 'Appointment Details',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header summary
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(DateFormat('MMM').format(appointment.start),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text('${appointment.start.day}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _statusChip(appointment.status, context),
                                  const SizedBox(width: 8),
                                  _typeChip(appointment.sessionType),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                df.format(appointment.start),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${tf.format(appointment.start)} - ${tf.format(appointment.end)} • $durationMinutes mins',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
                        trailing: appointment.sessionType == SessionType.online
                            ? const Icon(Icons.videocam_outlined)
                            : const Icon(Icons.meeting_room_outlined),
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
                        _sectionTitle(context, 'Session Information'),
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
                        _buildDetailRow(
                          context,
                          'Duration',
                          '$durationMinutes minutes',
                        ),
                        if (appointment.location != null &&
                            appointment.location!.isNotEmpty)
                          _buildDetailRow(
                            context,
                            'Location',
                            appointment.location!,
                          ),
                        if (appointment.initialProblem != null)
                          _buildDetailRow(
                            context,
                            'Reason',
                            appointment.initialProblem!,
                          ),
                        if (appointment.notes != null &&
                            appointment.notes!.isNotEmpty)
                          _buildDetailRow(
                            context,
                            'Notes you shared',
                            appointment.notes!,
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
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.video_call),
                                  label: const Text('Join meeting'),
                                  onPressed: () async {
                                    final raw = appointment.meetLink!.trim();
                                    final normalized = raw.startsWith('http')
                                        ? raw
                                        : 'https://$raw';
                                    final uri = Uri.tryParse(normalized);
                                    if (uri == null) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('Invalid meeting link')),
                                        );
                                      }
                                      return;
                                    }
                                    try {
                                      final launched = await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                      if (!launched) {
                                        await launchUrl(uri,
                                            mode: LaunchMode.platformDefault);
                                      }
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Could not open meeting link')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Copy link'),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: appointment.meetLink!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Link copied')),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.link, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    appointment.meetLink!,
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.open_in_new, size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Meeting link provided by counsellor.'),
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

                // Review Button (for completed sessions without review)
                if (appointment.status == AppointmentStatus.completed &&
                    appointment.studentRating == null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Write a Review'),
                      onPressed: () => _showReviewDialog(context, ref),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.amber.shade600,
                        foregroundColor: Colors.white,
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
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

  Widget _sectionTitle(BuildContext context, String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _statusChip(AppointmentStatus status, BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case AppointmentStatus.confirmed:
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = 'Confirmed';
        break;
      case AppointmentStatus.completed:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        label = 'Completed';
        break;
      case AppointmentStatus.cancelled:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = 'Cancelled';
        break;
      case AppointmentStatus.pending:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        label = 'Pending';
        break;
    }
    return Chip(
      backgroundColor: bg,
      label:
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
    );
  }

  Widget _typeChip(SessionType? type) {
    final isOnline = type == SessionType.online;
    return Chip(
      avatar: Icon(
        isOnline ? Icons.videocam : Icons.meeting_room,
        size: 16,
      ),
      label: Text(isOnline ? 'Online' : 'Face-to-Face'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
    );
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref) {
    int rating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rate this Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How would you rate this counselling session?'),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (i) => IconButton(
                        icon: Icon(
                          Icons.star,
                          size: 32,
                          color:
                              i < rating ? Colors.amber : Colors.grey.shade300,
                        ),
                        onPressed: () => setState(() => rating = i + 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '$rating / 5',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Any additional comments? (Optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    hintText: 'Share your feedback...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Create updated appointment with review
                  final updated = Appointment(
                    id: appointment.id,
                    studentId: appointment.studentId,
                    counsellorId: appointment.counsellorId,
                    start: appointment.start,
                    end: appointment.end,
                    status: appointment.status,
                    topic: appointment.topic,
                    location: appointment.location,
                    meetLink: appointment.meetLink,
                    notes: appointment.notes,
                    sentiment: appointment.sentiment,
                    sessionType: appointment.sessionType,
                    initialProblem: appointment.initialProblem,
                    riskLevel: appointment.riskLevel,
                    counsellorNotes: appointment.counsellorNotes,
                    followUpPlan: appointment.followUpPlan,
                    studentRating: rating,
                    studentComment: commentController.text.trim().isEmpty
                        ? null
                        : commentController.text.trim(),
                    isReviewApproved: appointment.isReviewApproved,
                    createdAt: appointment.createdAt,
                    updatedAt: DateTime.now(),
                  );
                  await ref
                      .read(firestoreServiceProvider)
                      .upsertAppointment(updated);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Review submitted successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error submitting review: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
              ),
              child: const Text('Submit Review'),
            ),
          ],
        ),
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

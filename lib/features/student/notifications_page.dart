import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_providers.dart';
import '../../router/app_router.dart';
import '../common/common_widgets.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final firestore = ref.watch(firestoreServiceProvider);

    if (user == null) {
      return const PrimaryScaffold(
        title: 'Notifications',
        body: Center(child: Text('Please sign in to view notifications.')),
      );
    }

    return PrimaryScaffold(
      title: 'Notifications',
      actions: [
        IconButton(
          tooltip: 'Delete all',
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete all notifications?'),
                content: const Text('This will remove all your notifications.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await firestore.deleteAllNotifications(user.uid);
            }
          },
          icon: const Icon(Icons.delete_forever, color: Colors.white),
        ),
        TextButton(
          onPressed: () async {
            await firestore.markAllNotificationsRead(user.uid);
          },
          child: const Text('Mark all read',
              style: TextStyle(color: Colors.white)),
        ),
      ],
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestore.notifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final message = item['message'] as String? ?? 'Notification';
              final read = item['read'] as bool? ?? false;
              final createdAtMs = item['createdAt'] as int? ?? 0;
              final meetLink = item['meetLink'] as String?;
              final type = item['type'] as String?;
              final appointmentId = item['appointmentId'] as String?;
              final notificationId = item['id'] as String?;
              final createdAt =
                  DateTime.fromMillisecondsSinceEpoch(createdAtMs);

              // Extract text without link if meetLink is in message
              String displayMessage = message;
              if (meetLink != null && message.contains(meetLink)) {
                displayMessage =
                    message.replaceAll(' Meet link: $meetLink', '');
              }

              return ListTile(
                onTap: () async {
                  if (notificationId != null) {
                    try {
                      await firestore.markNotificationRead(
                          user.uid, notificationId);
                    } catch (_) {
                      // ignore; UI will refresh on next stream emission
                    }
                  }
                  await _handleNotificationTap(
                    context,
                    type: type,
                    appointmentId: appointmentId,
                  );
                },
                leading: Icon(
                  read ? Icons.notifications_none : Icons.notifications_active,
                  color: read
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(displayMessage),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_formatDate(createdAt)),
                    if (meetLink != null && meetLink.isNotEmpty)
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse(meetLink);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Text(
                          'Join Session: $meetLink',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!read)
                      Text(
                        'NEW',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: notificationId == null
                          ? null
                          : () async {
                              await firestore.deleteNotification(
                                  user.uid, notificationId);
                            },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleNotificationTap(
    BuildContext context, {
    String? type,
    String? appointmentId,
  }) async {
    // If we have an appointmentId but no recognized type, still open details.
    if (type == null && appointmentId != null) {
      await context.pushNamed(
        AppRoute.appointmentDetail.name,
        pathParameters: {'id': appointmentId},
      );
      return;
    }

    if (type == null) return;

    switch (type) {
      case 'appointment_confirmed':
      case 'appointment_reminder':
      case 'review_counsellor':
        // Navigate to appointment detail page
        if (appointmentId != null) {
          await context.pushNamed(
            AppRoute.appointmentDetail.name,
            pathParameters: {'id': appointmentId},
          );
        }
        break;
      case 'add_progress_notes':
        // This is for counsellors, navigate to session notes
        if (appointmentId != null) {
          await context.pushNamed(
            AppRoute.sessionNotes.name,
            pathParameters: {'id': appointmentId},
          );
        }
        break;
      case 'mood_tracking_reminder':
        // Navigate to mood tracking page
        await context.pushNamed(AppRoute.studentMood.name);
        break;
      default:
        // Fallback: if appointmentId is present, navigate to its detail
        if (appointmentId != null) {
          await context.pushNamed(
            AppRoute.appointmentDetail.name,
            pathParameters: {'id': appointmentId},
          );
        }
        break;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

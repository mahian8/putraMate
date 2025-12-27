import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_providers.dart';
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
        TextButton(
          onPressed: () async {
            await firestore.markAllNotificationsRead(user.uid);
          },
          child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
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
              final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);

              return ListTile(
                leading: Icon(
                  read ? Icons.notifications_none : Icons.notifications_active,
                  color: read ? Colors.grey : Theme.of(context).colorScheme.primary,
                ),
                title: Text(message),
                subtitle: Text(_formatDate(createdAt)),
                trailing: read
                    ? null
                    : Text(
                        'NEW',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

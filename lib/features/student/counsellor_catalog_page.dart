import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_profile.dart';
import '../../router/app_router.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';
import 'counsellor_detail_page.dart';
import 'package:intl/intl.dart';

final _fsProvider = Provider((ref) => FirestoreService());

class CounsellorCatalogPage extends ConsumerWidget {
  const CounsellorCatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(_fsProvider).counsellors();

    return PrimaryScaffold(
      title: 'Counsellors',
      body: StreamBuilder<List<UserProfile>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final counsellors = snapshot.data ?? [];

          if (counsellors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No counsellors available yet'),
                  const SizedBox(height: 8),
                  const Text(
                    'Please ask your admin to add counsellors',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: counsellors.length,
            itemBuilder: (context, index) {
              final c = counsellors[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.email,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      // Status: inactive / on leave now / upcoming leave
                      Consumer(builder: (context, ref, _) {
                        final fs = ref.watch(_fsProvider);
                        if (!c.isActive) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text('Inactive',
                                style: TextStyle(color: Colors.redAccent)),
                          );
                        }
                        return StreamBuilder<List<Map<String, dynamic>>>(
                          stream: fs.userLeaves(c.uid),
                          builder: (context, snap) {
                            final nowMs = DateTime.now().millisecondsSinceEpoch;
                            final leaves = snap.data ?? [];
                            Map<String, dynamic>? active;
                            for (final l in leaves) {
                              final s = (l['startDate'] as int? ?? 0);
                              final e = (l['endDate'] as int? ?? 0);
                              if (s <= nowMs && e >= nowMs) {
                                active = l;
                                break;
                              }
                            }
                            if (active != null) {
                              final e = DateTime.fromMillisecondsSinceEpoch(
                                  active['endDate'] as int);
                              final type =
                                  (active['leaveType'] as String?) ?? 'leave';
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Out of service now • until ${DateFormat('MMM d, y').format(e)} ($type)',
                                  style:
                                      const TextStyle(color: Colors.redAccent),
                                ),
                              );
                            }
                            leaves.sort((a, b) => (a['startDate'] as int)
                                .compareTo(b['startDate'] as int));
                            final upcoming = leaves.firstWhere(
                                (l) => (l['startDate'] as int) >= nowMs,
                                orElse: () => {});
                            if (upcoming.isNotEmpty) {
                              final s = DateTime.fromMillisecondsSinceEpoch(
                                  upcoming['startDate'] as int);
                              final e = DateTime.fromMillisecondsSinceEpoch(
                                  upcoming['endDate'] as int);
                              final type =
                                  (upcoming['leaveType'] as String?) ?? 'leave';
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Leave scheduled: ${DateFormat('MMM d').format(s)} - ${DateFormat('MMM d, y').format(e)} ($type)',
                                  style: const TextStyle(color: Colors.orange),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        );
                      }),
                      const SizedBox(height: 12),
                      Consumer(builder: (context, ref, _) {
                        final fs = ref.watch(_fsProvider);
                        final isInactive = !c.isActive;
                        return StreamBuilder<List<Map<String, dynamic>>>(
                          stream: fs.userLeaves(c.uid),
                          builder: (context, snap) {
                            final nowMs = DateTime.now().millisecondsSinceEpoch;
                            final leaves = snap.data ?? [];
                            final onLeaveNow = leaves.any((l) {
                              final s = (l['startDate'] as int? ?? 0);
                              final e = (l['endDate'] as int? ?? 0);
                              return s <= nowMs && e >= nowMs;
                            });
                            final canBook = !isInactive && !onLeaveNow;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CounsellorDetailPage(counsellor: c),
                                    ),
                                  ),
                                  child: const Text('View Details'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: canBook
                                      ? () => context.pushNamed(
                                            AppRoute.booking.name,
                                            queryParameters: {
                                              'cid': c.uid,
                                              'cname': c.displayName,
                                            },
                                          )
                                      : null,
                                  child: const Text('Book'),
                                ),
                              ],
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

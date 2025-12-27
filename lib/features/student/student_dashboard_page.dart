import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../models/mood_entry.dart';
import '../../providers/auth_providers.dart';
import '../../router/app_router.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';

final firestoreProvider = Provider((ref) => FirestoreService());

class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  ConsumerState<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage> {
  int _currentPage = 0;
  final int _postsPerPage = 10;
  static final _random = Random();

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final user = ref.watch(authStateProvider).value;

    return userAsync.when(
      loading: () => const PrimaryScaffold(
        title: 'Dashboard',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PrimaryScaffold(
        title: 'Dashboard',
        body: Center(child: Text('Error: $e')),
      ),
      data: (profile) {
        if (user == null || profile == null) {
          return const PrimaryScaffold(
            title: 'Dashboard',
            body: Center(child: Text('Please sign in')),
          );
        }

        final firestoreService = ref.watch(firestoreProvider);
        // Fire a one-time reminder check after first frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          firestoreService.sendUpcomingReminderIfDue(user.uid);
          // Also auto-complete any sessions past end time by 30 minutes
          firestoreService.autoCompleteExpiredSessionsForUser(user.uid);
        });

        return PrimaryScaffold(
          title: 'Welcome, ${profile.displayName}',
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu),
              onSelected: (value) async {
                switch (value) {
                  case 'profile':
                    context.pushNamed(AppRoute.profile.name);
                    break;
                  case 'chat':
                    context.pushNamed(AppRoute.chatbot.name);
                    break;
                  case 'mood':
                    context.pushNamed(AppRoute.studentMood.name);
                    break;
                  case 'notifications':
                    context.pushNamed(AppRoute.notifications.name);
                    break;
                  case 'community':
                    context.pushNamed(AppRoute.forum.name);
                    break;
                  case 'logout':
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
                      await ref.read(authServiceProvider).signOut();
                      if (context.mounted) {
                        context.goNamed(AppRoute.login.name);
                      }
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(Icons.person, color: Colors.blue),
                    title: Text('Profile'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'chat',
                  child: ListTile(
                    leading: Icon(Icons.chat_bubble, color: Colors.purple),
                    title: Text('AI Chat'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'mood',
                  child: ListTile(
                    leading: Icon(Icons.mood, color: Colors.orange),
                    title: Text('Mood Track'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'notifications',
                  child: ListTile(
                    leading: Icon(Icons.notifications, color: Colors.amber),
                    title: Text('Notifications'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'community',
                  child: ListTile(
                    leading: Icon(Icons.forum, color: Colors.green),
                    title: Text('Community'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text('Logout'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
          body: ListView(
            children: [
              // Mood Check Reminder
              SectionCard(
                title: 'How are you feeling today?',
                trailing: Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.primary),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Track your daily mood to help us support you better.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => context.pushNamed(AppRoute.studentMood.name),
                      icon: const Icon(Icons.add_reaction),
                      label: const Text('Log Mood Now'),
                    ),
                  ],
                ),
              ),

              // Upcoming Appointments - DYNAMIC
              StreamBuilder<List<Appointment>>(
                stream: firestoreService.appointmentsForUser(user.uid),
                builder: (context, snapshot) {
                  final appointments = snapshot.data ?? [];
                  final upcoming = appointments
                      .where((a) => a.start.isAfter(DateTime.now()))
                      .take(3)
                      .toList();

                  return SectionCard(
                    title: 'Upcoming Sessions',
                    trailing: TextButton(
                      onPressed: () => context.pushNamed(AppRoute.appointments.name),
                      child: const Text('View All'),
                    ),
                    child: upcoming.isEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('No upcoming sessions scheduled.'),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => context.pushNamed(AppRoute.booking.name),
                                icon: const Icon(Icons.add),
                                label: const Text('Book a Session'),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              ...upcoming.map((apt) => _AppointmentTile(
                                    date: apt.start,
                                    counsellor: 'Counsellor',
                                    time: DateFormat('h:mm a').format(apt.start),
                                  )),
                              const Divider(),
                              TextButton.icon(
                                onPressed: () => context.pushNamed(AppRoute.booking.name),
                                icon: const Icon(Icons.add),
                                label: const Text('Book Another Session'),
                              ),
                            ],
                          ),
                  );
                },
              ),

              // Recent Mood Trend - DYNAMIC
              StreamBuilder<List<MoodEntry>>(
                stream: firestoreService.moodEntries(user.uid),
                builder: (context, snapshot) {
                  final moods = snapshot.data ?? [];
                  final recentMoods = moods.take(7).toList();
                  final now = DateTime.now();
                  final lastMoodAt = moods.isNotEmpty ? moods.first.timestamp : null;
                  final showReminder = lastMoodAt == null || now.difference(lastMoodAt).inHours >= 24;
                  final reminderMessages = [
                    'Hey there, how are you feeling today?',
                    'Just checking in. Want to log a quick mood?',
                    'You matter to us. Everything okay?',
                    'We are here for you. Share how you feel?',
                  ];
                  final reminderMsg = reminderMessages[_random.nextInt(reminderMessages.length)];

                  if (recentMoods.isEmpty) {
                    return SectionCard(
                      title: 'Your Mood This Week',
                      child: Column(
                        children: [
                          const Text('Start tracking your mood to see trends.'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => context.pushNamed(AppRoute.studentMood.name),
                            child: const Text('Log Your First Mood'),
                          ),
                        ],
                      ),
                    );
                  }

                  final avgMood = recentMoods.isEmpty
                      ? 0.0
                      : recentMoods.map((e) => e.moodScore).reduce((a, b) => a + b) /
                          recentMoods.length;
                  final moodSection = SectionCard(
                    title: 'Your Mood This Week',
                    trailing: TextButton(
                      onPressed: () => context.pushNamed(AppRoute.studentMood.name),
                      child: const Text('Details'),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(7, (i) {
                            if (i >= recentMoods.length) {
                              return Column(
                                children: [
                                  Container(
                                    height: 60,
                                    width: 36,
                                    alignment: Alignment.bottomCenter,
                                    child: Container(height: 0, width: 36),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('E').format(
                                      DateTime.now().subtract(Duration(days: 6 - i)),
                                    ),
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                ],
                              );
                            }
                            final mood = recentMoods.reversed.toList()[i];
                            return Column(
                              children: [
                                Container(
                                  height: 60,
                                  width: 36,
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    height: mood.moodScore * 6.0,
                                    decoration: BoxDecoration(
                                      color: _getMoodColor(mood.moodScore),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('E').format(mood.timestamp),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Average: ${avgMood.toStringAsFixed(1)}/10',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );

                  if (showReminder) {
                    return Column(
                      children: [
                        SectionCard(
                          title: 'Quick check-in',
                          trailing: const Icon(Icons.notifications_active, color: Colors.amber),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(reminderMsg),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => context.pushNamed(AppRoute.studentMood.name),
                                icon: const Icon(Icons.edit_note),
                                label: const Text('Log mood now'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        moodSection,
                      ],
                    );
                  }

                  return moodSection;
                },
              ),

              // Community Highlights - PAGINATED
              StreamBuilder(
                stream: ref.watch(firestoreProvider).communityPosts(),
                builder: (context, snapshot) {
                  final allPosts = snapshot.data ?? [];
                  final totalPages = (allPosts.length / _postsPerPage).ceil();
                  
                  if (totalPages == 0) {
                    return SectionCard(
                      title: 'Community Forum',
                      trailing: TextButton(
                        onPressed: () => context.pushNamed(AppRoute.forum.name),
                        child: const Text('Browse'),
                      ),
                      child: const Text('No posts yet. Be the first to share!'),
                    );
                  }

                  // Get posts for current page
                  final startIndex = _currentPage * _postsPerPage;
                  final endIndex = (startIndex + _postsPerPage > allPosts.length)
                      ? allPosts.length
                      : startIndex + _postsPerPage;
                  final paginatedPosts = allPosts.sublist(startIndex, endIndex);

                  return SectionCard(
                    title: 'Community Forum (Page ${_currentPage + 1} of ${totalPages > 0 ? totalPages : 1})',
                    trailing: TextButton(
                      onPressed: () => context.pushNamed(AppRoute.forum.name),
                      child: const Text('All Posts'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Forum posts list
                        ...paginatedPosts.map((post) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post.title,
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        post.content,
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'by ${post.authorName}',
                                            style: Theme.of(context).textTheme.labelSmall,
                                          ),
                                          Text(
                                            DateFormat('MMM d').format(post.createdAt),
                                            style: Theme.of(context).textTheme.labelSmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.favorite_border, size: 16),
                                          const SizedBox(width: 4),
                                          Text('${post.likes.length}', style: Theme.of(context).textTheme.labelSmall),
                                          const SizedBox(width: 16),
                                          Icon(Icons.comment_outlined, size: 16),
                                          const SizedBox(width: 4),
                                          Text('${post.commentCount}', style: Theme.of(context).textTheme.labelSmall),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )),
                        
                        // Pagination controls
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _currentPage > 0
                                  ? () => setState(() => _currentPage--)
                                  : null,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Previous'),
                            ),
                            Text(
                              'Page ${_currentPage + 1} of $totalPages',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            ElevatedButton.icon(
                              onPressed: _currentPage < totalPages - 1
                                  ? () => setState(() => _currentPage++)
                                  : null,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Next'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          fab: FloatingActionButton.extended(
            onPressed: () => context.pushNamed(AppRoute.counsellorCatalog.name),
            icon: const Icon(Icons.event),
            label: const Text('Book Counsellor'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }

  Color _getMoodColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.lightGreen;
    if (score >= 4) return Colors.orange;
    return Colors.red;
  }
}

class _AppointmentTile extends StatelessWidget {
  final DateTime date;
  final String counsellor;
  final String time;

  const _AppointmentTile({
    required this.date,
    required this.counsellor,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.event),
      title: Text(counsellor),
      subtitle: Text('${DateFormat('MMM d').format(date)} at $time'),
    );
  }
}


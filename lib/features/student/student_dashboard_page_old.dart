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

class StudentDashboardPage extends ConsumerWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        
        return PrimaryScaffold(
          title: 'Welcome, ${profile.displayName}',
          body: ListView(
            children: [
              // Quick Actions
              SectionCard(
                title: 'Quick Actions',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickActionChip(
                      icon: Icons.event,
                      label: 'Book Counsellor',
                      color: Colors.blue,
                      onTap: () => context.pushNamed(AppRoute.counsellorCatalog.name),
                    ),
                    _QuickActionChip(
                      icon: Icons.chat_bubble,
                      label: 'AI Chatbot',
                      color: Colors.purple,
                      onTap: () => context.pushNamed(AppRoute.chatbot.name),
                    ),
                    _QuickActionChip(
                      icon: Icons.mood,
                      label: 'Mood Track',
                      color: Colors.orange,
                      onTap: () => context.pushNamed(AppRoute.studentMood.name),
                    ),
                    _QuickActionChip(
                      icon: Icons.forum,
                      label: 'Community',
                      color: Colors.green,
                      onTap: () => context.pushNamed(AppRoute.forum.name),
                    ),
                    _QuickActionChip(
                      icon: Icons.book,
                      label: 'Journal',
                      color: Colors.teal,
                      onTap: () => context.pushNamed(AppRoute.studentJournal.name),
                    ),
                  ],
                ),
              ),
              
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
                  
                  return SectionCard(
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
                },
              ),
              
              // Community Highlights - DYNAMIC
              StreamBuilder(
                stream: ref.watch(firestoreProvider).communityPosts(),
                builder: (context, snapshot) {
                  final posts = snapshot.data ?? [];
                  final recentPosts = posts.take(2).toList();
                  
                  return SectionCard(
                    title: 'Community Forum',
                    trailing: TextButton(
                      onPressed: () => context.pushNamed(AppRoute.forum.name),
                      child: const Text('Browse'),
                    ),
                    child: recentPosts.isEmpty
                        ? const Text('No posts yet. Be the first to share!')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...recentPosts.map((post) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _ForumSnippet(
                                      title: post.title,
                                      author: post.authorName,
                                      replies: 0,
                                    ),
                                  )),
                            ],
                          ),
                  );
                },
              ),
            ],
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

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 20, color: color),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.date,
    required this.counsellor,
    required this.time,
  });

  final DateTime date;
  final String counsellor;
  final String time;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Text(DateFormat('d').format(date)),
      ),
      title: Text(counsellor),
      subtitle: Text('${DateFormat('MMM d, y').format(date)} at $time'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}

class _ForumSnippet extends StatelessWidget {
  const _ForumSnippet({
    required this.title,
    required this.author,
    required this.replies,
  });

  final String title;
  final String author;
  final int replies;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('by $author • $replies replies'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/appointment.dart';
import '../../models/mood_entry.dart';
import '../../providers/auth_providers.dart';
import '../../router/app_router.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';
import 'student_demo_modal.dart';

final firestoreProvider = Provider((ref) => FirestoreService());

class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  ConsumerState<StudentDashboardPage> createState() =>
      _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage> {
  int _currentPage = 0;
  final int _postsPerPage = 10;
  static final _random = Random();
  DateTime _calendarFocusedDay = DateTime.now();
  DateTime? _calendarSelectedDay;

  @override
  void initState() {
    super.initState();
    _calendarSelectedDay = DateTime.now();

    // Check if demo needs to be shown for first-time users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowDemo();
    });
  }

  void _checkAndShowDemo() {
    // Access the user profile from the widget build context
    final userAsync = ref.read(userProfileProvider);
    userAsync.whenData((profile) {
      if (profile != null &&
          profile.role.name == 'student' &&
          !profile.demoViewed) {
        // Show demo modal for first-time student
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const StudentDemoModal(),
        );
      }
    });
  }

  void _showBookingChoice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                child: Icon(Icons.schedule, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Book a session',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose how you want to proceed:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side:
                      BorderSide(color: scheme.primary.withValues(alpha: 0.25)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: scheme.primary.withValues(alpha: 0.12),
                    child: Icon(Icons.people_alt, color: scheme.primary),
                  ),
                  title: const Text('Browse counsellor catalog'),
                  subtitle: const Text('Pick a counsellor before booking'),
                  onTap: () {
                    context.pop();
                    context.pushNamed(AppRoute.counsellorCatalog.name);
                  },
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 16, color: scheme.primary),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: scheme.secondary.withValues(alpha: 0.25)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: scheme.secondary.withValues(alpha: 0.12),
                    child: Icon(Icons.bolt, color: scheme.secondary),
                  ),
                  title: const Text('Quick booking'),
                  subtitle: const Text('Jump straight to available slots'),
                  onTap: () {
                    context.pop();
                    context.pushNamed(AppRoute.booking.name);
                  },
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 16, color: scheme.secondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

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
          // Send mood tracking reminder if user hasn't logged mood in 24+ hours
          firestoreService.sendMoodTrackingReminderIfDue(user.uid);
        });

        return PrimaryScaffold(
          title: 'PutraMate',
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: const AssetImage('assets/images/PutraMate.png'),
            ),
          ),
          titleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PutraMate',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                'Welcome, ${profile.displayName}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            // Quick access: Notifications with unread badge
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: firestoreService.notifications(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Show loading indicator
                  return IconButton(
                    tooltip: 'Notifications',
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () =>
                        context.pushNamed(AppRoute.notifications.name),
                  );
                }

                if (snapshot.hasError) {
                  // Show error indicator
                  return IconButton(
                    tooltip: 'Notifications (Error)',
                    icon: const Icon(Icons.notifications_off),
                    onPressed: () =>
                        context.pushNamed(AppRoute.notifications.name),
                  );
                }

                final items = snapshot.data ?? const [];
                final unread =
                    items.where((n) => !(n['read'] as bool? ?? false)).length;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      icon: const Icon(Icons.notifications),
                      onPressed: () =>
                          context.pushNamed(AppRoute.notifications.name),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            // Quick access: Profile
            IconButton(
              tooltip: 'Profile',
              icon: const Icon(Icons.person),
              onPressed: () => context.pushNamed(AppRoute.profile.name),
            ),
            // Digital clock
            const DigitalClock(),
            // Menu
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
                      unawaited(ref.read(authServiceProvider).signOut());
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
                  value: 'notifications',
                  child: ListTile(
                    leading: Icon(Icons.notifications, color: Colors.amber),
                    title: Text('Notifications'),
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
              // Quick Access shortcuts
              SectionCard(
                title: 'Quick Access',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => context.pushNamed(AppRoute.profile.name),
                      icon: const Icon(Icons.person),
                      label: const Text('Profile'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.pushNamed(AppRoute.appointments.name),
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Appointments'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.pushNamed(AppRoute.notifications.name),
                      icon: const Icon(Icons.notifications),
                      label: const Text('Notifications'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showBookingChoice(context),
                      icon: const Icon(Icons.schedule),
                      label: const Text('Book Session'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.pushNamed(AppRoute.studentMood.name),
                      icon: const Icon(Icons.mood),
                      label: const Text('Mood Track'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.pushNamed(AppRoute.forum.name),
                      icon: const Icon(Icons.forum),
                      label: const Text('Community'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.pushNamed(AppRoute.chatbot.name),
                      icon: const Icon(Icons.chat_bubble),
                      label: const Text('AI Chat'),
                    ),
                  ],
                ),
              ),
              // Mood Check Reminder
              SectionCard(
                title: 'How are you feeling today?',
                trailing: Icon(Icons.notifications_active,
                    color: Theme.of(context).colorScheme.primary),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Track your daily mood to help us support you better.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.pushNamed(AppRoute.studentMood.name),
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
                      .toList();

                  // Group upcoming by day for calendar markers
                  final Map<DateTime, List<Appointment>> eventsByDay = {};
                  for (final apt in upcoming) {
                    final key = DateTime(
                        apt.start.year, apt.start.month, apt.start.day);
                    eventsByDay.putIfAbsent(key, () => []).add(apt);
                  }

                  final selectedEvents = _calendarSelectedDay == null
                      ? const <Appointment>[]
                      : eventsByDay[DateTime(
                              _calendarSelectedDay!.year,
                              _calendarSelectedDay!.month,
                              _calendarSelectedDay!.day)] ??
                          const <Appointment>[];

                  return SectionCard(
                    title: 'Upcoming Sessions',
                    trailing: TextButton(
                      onPressed: () =>
                          context.pushNamed(AppRoute.appointments.name),
                      child: const Text('View All'),
                    ),
                    child: Column(
                      children: [
                        TableCalendar<Appointment>(
                          firstDay:
                              DateTime.now().subtract(const Duration(days: 30)),
                          lastDay:
                              DateTime.now().add(const Duration(days: 180)),
                          focusedDay: _calendarFocusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_calendarSelectedDay, day),
                          eventLoader: (day) {
                            final key = DateTime(day.year, day.month, day.day);
                            return eventsByDay[key] ?? const <Appointment>[];
                          },
                          calendarFormat: CalendarFormat.twoWeeks,
                          availableCalendarFormats: const {
                            CalendarFormat.month: 'Month',
                            CalendarFormat.twoWeeks: '2 weeks',
                            CalendarFormat.week: 'Week',
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _calendarSelectedDay = selectedDay;
                              _calendarFocusedDay = focusedDay;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            _calendarFocusedDay = focusedDay;
                          },
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                          calendarStyle: CalendarStyle(
                            markerDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (selectedEvents.isNotEmpty)
                          ...selectedEvents.take(3).map(
                                (apt) => _AppointmentTile(appointment: apt),
                              )
                        else if (upcoming.isNotEmpty)
                          ...upcoming.take(3).map(
                                (apt) => _AppointmentTile(appointment: apt),
                              )
                        else
                          Column(
                            children: [
                              const Text('No upcoming sessions scheduled.'),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => _showBookingChoice(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Book a Session'),
                              ),
                            ],
                          ),
                        if (upcoming.isNotEmpty) ...[
                          const Divider(),
                          TextButton.icon(
                            onPressed: () => _showBookingChoice(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Book Another Session'),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              // Recent Session Notes (sorted by latest)
              StreamBuilder<List<Appointment>>(
                stream: firestoreService.appointmentsForUser(user.uid),
                builder: (context, snapshot) {
                  final appointments = snapshot.data ?? [];
                  final notes = appointments
                      .where((a) =>
                          (a.counsellorNotes != null &&
                              a.counsellorNotes!.isNotEmpty) ||
                          (a.followUpPlan != null &&
                              a.followUpPlan!.isNotEmpty))
                      .toList();
                  notes.sort((a, b) =>
                      (b.updatedAt ?? b.end).compareTo(a.updatedAt ?? a.end));

                  if (notes.isEmpty) {
                    return const SectionCard(
                      title: 'Recent Session Notes',
                      child: Text('No session notes yet.'),
                    );
                  }

                  return SectionCard(
                    title: 'Recent Session Notes',
                    trailing: TextButton(
                      onPressed: () =>
                          context.pushNamed(AppRoute.appointments.name),
                      child: const Text('View All'),
                    ),
                    child: Column(
                      children: [
                        ...notes.take(5).map((a) => ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              title: Text(DateFormat('MMM d, y • h:mm a')
                                  .format(a.end)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (a.counsellorNotes != null &&
                                      a.counsellorNotes!.isNotEmpty) ...[
                                    const Text('Counsellor Notes:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text(a.counsellorNotes!),
                                  ],
                                  if (a.followUpPlan != null &&
                                      a.followUpPlan!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    const Text('Follow-up Plan:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text(a.followUpPlan!),
                                  ],
                                ],
                              ),
                            )),
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
                  final lastMoodAt =
                      moods.isNotEmpty ? moods.first.timestamp : null;
                  final showReminder = lastMoodAt == null ||
                      now.difference(lastMoodAt).inHours >= 24;
                  final reminderMessages = [
                    'Hey there, how are you feeling today?',
                    'Just checking in. Want to log a quick mood?',
                    'You matter to us. Everything okay?',
                    'We are here for you. Share how you feel?',
                  ];
                  final reminderMsg = reminderMessages[
                      _random.nextInt(reminderMessages.length)];

                  if (recentMoods.isEmpty) {
                    return SectionCard(
                      title: 'Your Mood This Week',
                      child: Column(
                        children: [
                          const Text('Start tracking your mood to see trends.'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () =>
                                context.pushNamed(AppRoute.studentMood.name),
                            child: const Text('Log Your First Mood'),
                          ),
                        ],
                      ),
                    );
                  }

                  final avgMood = recentMoods.isEmpty
                      ? 0.0
                      : recentMoods
                              .map((e) => e.moodScore)
                              .reduce((a, b) => a + b) /
                          recentMoods.length;
                  final moodSection = SectionCard(
                    title: 'Your Mood This Week',
                    trailing: TextButton(
                      onPressed: () =>
                          context.pushNamed(AppRoute.studentMood.name),
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
                                      DateTime.now()
                                          .subtract(Duration(days: 6 - i)),
                                    ),
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
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
                          trailing: const Icon(Icons.notifications_active,
                              color: Colors.amber),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(reminderMsg),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => context
                                    .pushNamed(AppRoute.studentMood.name),
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
                  final endIndex =
                      (startIndex + _postsPerPage > allPosts.length)
                          ? allPosts.length
                          : startIndex + _postsPerPage;
                  final paginatedPosts = allPosts.sublist(startIndex, endIndex);

                  return SectionCard(
                    title:
                        'Community Forum (Page ${_currentPage + 1} of ${totalPages > 0 ? totalPages : 1})',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        post.content,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'by ${post.authorName}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall,
                                          ),
                                          Text(
                                            DateFormat('MMM d')
                                                .format(post.createdAt),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.favorite_border, size: 16),
                                          const SizedBox(width: 4),
                                          Text('${post.likes.length}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall),
                                          const SizedBox(width: 16),
                                          Icon(Icons.comment_outlined,
                                              size: 16),
                                          const SizedBox(width: 4),
                                          Text('${post.commentCount}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall),
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
  final Appointment appointment;

  const _AppointmentTile({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(appointment.start);
    final date = DateFormat('MMM d').format(appointment.start);
    final title = appointment.topic?.isNotEmpty == true
        ? appointment.topic!
        : 'Upcoming session';
    return ListTile(
      leading: const Icon(Icons.event_available),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$date at $time'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.pushNamed(
          AppRoute.appointmentDetail.name,
          pathParameters: {'id': appointment.id},
        );
      },
    );
  }
}

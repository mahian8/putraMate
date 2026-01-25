import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';
import '../../models/appointment.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';
import 'appointment_detail_page.dart';

final _fsProvider = Provider((ref) => FirestoreService());

class MyAppointmentsPage extends ConsumerStatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  ConsumerState<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends ConsumerState<MyAppointmentsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/student/dashboard');
          }
        },
      ),
      body: StreamBuilder<List<Appointment>>(
        stream: stream,
        builder: (context, snapshot) {
          final allAppts = snapshot.data ?? [];

          // Organize appointments by date
          final Map<DateTime, List<Appointment>> appointmentsByDate = {};
          for (var appt in allAppts) {
            final date =
                DateTime(appt.start.year, appt.start.month, appt.start.day);
            appointmentsByDate.putIfAbsent(date, () => []).add(appt);
          }

          // Separate past and upcoming appointments
          final now = DateTime.now();
          final pastAppts =
              allAppts.where((a) => a.start.isBefore(now)).toList();
          final upcomingAppts =
              allAppts.where((a) => a.start.isAfter(now)).toList();

          // Sort by date
          pastAppts
              .sort((a, b) => b.start.compareTo(a.start)); // Most recent first
          upcomingAppts
              .sort((a, b) => a.start.compareTo(b.start)); // Nearest first

          // Get appointments for selected day
          final selectedDayAppts = _selectedDay != null
              ? appointmentsByDate[DateTime(_selectedDay!.year,
                      _selectedDay!.month, _selectedDay!.day)] ??
                  []
              : [];

          if (allAppts.isEmpty) {
            return const SectionCard(
              title: 'No appointments yet',
              child: Text('Book a slot to get started.'),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Calendar View
                Card(
                  margin: const EdgeInsets.all(8),
                  child: TableCalendar(
                    firstDay:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    eventLoader: (day) {
                      final date = DateTime(day.year, day.month, day.day);
                      return appointmentsByDate[date] ?? [];
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),

                // Selected Day Appointments
                if (_selectedDay != null && selectedDayAppts.isNotEmpty) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Appointments on ${DateFormat('MMM d, yyyy').format(_selectedDay!)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ...selectedDayAppts
                      .map((a) => _buildAppointmentCard(context, ref, a)),
                  const Divider(height: 32),
                ],

                // Upcoming Appointments
                if (upcomingAppts.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.upcoming, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Upcoming Appointments (${upcomingAppts.length})',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
                  ...upcomingAppts
                      .take(5)
                      .map((a) => _buildAppointmentCard(context, ref, a)),
                ],

                const Divider(height: 32),

                // Past Appointments
                if (pastAppts.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.history, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Past Appointments (${pastAppts.length})',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
                  ...pastAppts
                      .take(5)
                      .map((a) => _buildAppointmentCard(context, ref, a)),
                ],

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppointmentCard(
      BuildContext context, WidgetRef ref, Appointment a) {
    final isPast = a.start.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: a.status == AppointmentStatus.completed
              ? Colors.green
              : a.status == AppointmentStatus.cancelled
                  ? Colors.red
                  : isPast
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
          child: Icon(
            a.status == AppointmentStatus.completed
                ? Icons.check
                : a.status == AppointmentStatus.cancelled
                    ? Icons.close
                    : Icons.calendar_today,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(a.topic ?? 'Session'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(DateFormat('MMM d, h:mm a').format(a.start)),
              ],
            ),
            Row(
              children: [
                Icon(
                  a.status == AppointmentStatus.completed
                      ? Icons.check_circle
                      : a.status == AppointmentStatus.cancelled
                          ? Icons.cancel
                          : Icons.schedule,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text('Status: ${a.status.name}'),
              ],
            ),
            if (a.sessionType == SessionType.online &&
                a.meetLink != null &&
                a.meetLink!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.video_call, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Meet link available',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            if (a.notes != null)
              Text('Notes: ${a.notes}', style: const TextStyle(fontSize: 12)),
            if (a.isDuplicate)
              const Text('Potential duplicate booking',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
            if (a.studentRating != null)
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
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
            : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AppointmentDetailPage(appointment: a),
            ),
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

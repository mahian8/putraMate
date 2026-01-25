import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/appointment.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../common/common_widgets.dart';
import 'counsellor_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

final firestoreProvider = Provider((ref) => FirestoreService());

// Stable provider for counsellor appointments stream - prevents auto-rebuild
final counsellorAppointmentsProvider =
    StreamProvider.family<List<Appointment>, String>(
  (ref, counsellorId) {
    return ref.watch(firestoreProvider).appointmentsForCounsellor(counsellorId);
  },
);

class BookingCalendarPage extends ConsumerStatefulWidget {
  const BookingCalendarPage(
      {super.key, this.counsellorId, this.counsellorName});

  final String? counsellorId;
  final String? counsellorName;

  @override
  ConsumerState<BookingCalendarPage> createState() =>
      _BookingCalendarPageState();
}

class _BookingCalendarPageState extends ConsumerState<BookingCalendarPage> {
  late String _selectedCounsellorId;
  late String _selectedCounsellorName;
  DateTime? _selectedDate;
  DateTime _focusedDay = DateTime.now();
  TimeOfDay? _selectedTime;
  List<String> _availabilityIssues = [];
  bool _checkingAvailability = false;
  final _topic = TextEditingController();
  final _notes = TextEditingController();
  final _initialProblem = TextEditingController();
  SessionType _sessionType = SessionType.online;
  bool _submitting = false;
  String? _selectedReason;
  final List<String> _reasonOptions = const [
    'Home sickness',
    'Academic stress',
    'Anxiety or panic',
    'Depression or low mood',
    'Relationships or family',
    'Career or future planning',
    'Sleep issues',
    'Self-esteem or confidence',
    'Other',
  ];
  final Map<String, Map<String, String>> _reasonTemplates = const {
    'Home sickness': {
      'initial': 'Feeling homesick and needing support',
      'topic': 'Homesickness support',
      'notes': 'Struggling being away from home and adapting.',
    },
    'Academic stress': {
      'initial': 'Academic stress and workload concerns',
      'topic': 'Academic stress and workload',
      'notes': 'Feeling overwhelmed with coursework, deadlines, or exams.',
    },
    'Anxiety or panic': {
      'initial': 'Managing anxiety or panic',
      'topic': 'Anxiety support',
      'notes': 'Experiencing anxiety symptoms and wants coping strategies.',
    },
    'Depression or low mood': {
      'initial': 'Low mood and motivation',
      'topic': 'Mood support',
      'notes': 'Feeling down or unmotivated, seeking support to cope.',
    },
    'Relationships or family': {
      'initial': 'Relationship or family concerns',
      'topic': 'Relationship/family support',
      'notes': 'Discussing relationship or family-related stress.',
    },
    'Career or future planning': {
      'initial': 'Career and future planning questions',
      'topic': 'Career and future planning',
      'notes': 'Looking for guidance on career or future decisions.',
    },
    'Sleep issues': {
      'initial': 'Sleep difficulties',
      'topic': 'Improving sleep habits',
      'notes': 'Having trouble sleeping and wants to improve sleep habits.',
    },
    'Self-esteem or confidence': {
      'initial': 'Self-esteem and confidence concerns',
      'topic': 'Building confidence',
      'notes': 'Wants to build confidence and address self-esteem concerns.',
    },
  };

  @override
  void initState() {
    super.initState();
    _selectedCounsellorId = widget.counsellorId ?? '';
    _selectedCounsellorName = widget.counsellorName ?? 'Select a Counsellor';
  }

  @override
  void dispose() {
    _topic.dispose();
    _notes.dispose();
    _initialProblem.dispose();
    super.dispose();
  }

  void _applyReasonDefaults(String? reason) {
    if (reason == null) return;
    final template = _reasonTemplates[reason];
    if (template != null) {
      _initialProblem.text = template['initial'] ?? reason;
      _topic.text = template['topic'] ?? '';
      _notes.text = template['notes'] ?? '';
    } else if (reason == 'Other') {
      _initialProblem.text = 'Other';
    }
  }

  bool _isSelectableDay(DateTime day) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    // Disable Sundays (7) and past dates
    return day.weekday != DateTime.sunday && !day.isBefore(todayStart);
  }

  List<_SlotInfo> _buildSlotsForDay(
    DateTime day,
    List<Appointment> booked,
  ) {
    // Disable entire day if Sunday
    if (day.weekday == DateTime.sunday) {
      return [];
    }

    // Filter booked appointments to only this specific day, excluding cancelled ones
    final bookedOnDay = booked.where((a) {
      // Exclude cancelled appointments - they're available again
      if (a.status == AppointmentStatus.cancelled) {
        return false;
      }
      final appointmentDay = DateTime(a.start.year, a.start.month, a.start.day);
      final targetDay = DateTime(day.year, day.month, day.day);
      return isSameDay(appointmentDay, targetDay);
    }).toList();

    final isOnline = _sessionType == SessionType.online;
    final startHour = isOnline ? 0 : 9;
    final endHour = isOnline ? 24 : 18;
    final slots = <_SlotInfo>[];
    final slotDuration = const Duration(minutes: 45);

    var cursor = DateTime(day.year, day.month, day.day, startHour);
    final endOfRange = DateTime(day.year, day.month, day.day, endHour);

    while (cursor.isBefore(endOfRange)) {
      final end = cursor.add(slotDuration);
      if (end.isAfter(endOfRange)) break;

      // Slot is available only if it doesn't overlap with any booked appointment on THIS day
      final isAvailable = !bookedOnDay
          .any((a) => cursor.isBefore(a.end) && end.isAfter(a.start));

      if (isAvailable) {
        slots.add(_SlotInfo(start: cursor, end: end));
      }

      cursor = cursor.add(slotDuration);
    }

    return slots;
  }

  Future<void> _checkAvailability() async {
    if (_selectedCounsellorId.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      return;
    }

    setState(() => _checkingAvailability = true);
    try {
      final start = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      final end = start.add(const Duration(minutes: 45));

      final now = DateTime.now();
      if (start.isBefore(now)) {
        setState(() => _availabilityIssues = ['You cannot book a past time.']);
        return;
      }

      if (_sessionType == SessionType.faceToFace &&
          (start.hour < 9 || start.hour >= 18)) {
        setState(() => _availabilityIssues = [
              'Face-to-face sessions run 9:00 AM - 6:00 PM.'
            ]);
        return;
      }

      final fs = FirestoreService();
      final issues = await fs.checkAvailability(
        counsellorId: _selectedCounsellorId,
        start: start,
        end: end,
      );

      setState(() => _availabilityIssues = issues);
    } catch (e) {
      print('Error checking availability: $e');
    } finally {
      setState(() => _checkingAvailability = false);
    }
  }

  Future<void> _selectCounsellor() async {
    final fs = FirestoreService();
    if (!mounted) return;

    await showDialog<UserProfile>(
      context: context,
      builder: (context) => StreamBuilder<List<UserProfile>>(
        stream: fs.counsellors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              title: const Text('Loading Counsellors'),
              content: const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasError) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text('Error loading counsellors: ${snapshot.error}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          final counsellors =
              (snapshot.data ?? []).where((c) => c.isActive).toList();
          if (counsellors.isEmpty) {
            return AlertDialog(
              title: const Text('No Counsellors'),
              content: const Text('No counsellors available at the moment'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          return _CounsellorSelectionDialog(
            counsellors: counsellors,
            selectedReasonText: _selectedReason ?? '',
            userProblem: _initialProblem.text,
            userTopic: _topic.text,
            userNotes: _notes.text,
            onSelected: (counsellor) {
              Navigator.pop(context);
              setState(() {
                _selectedCounsellorId = counsellor.uid;
                _selectedCounsellorName = counsellor.displayName;
                _availabilityIssues = [];
              });
              _checkAvailability();
            },
          );
        },
      ),
    );
  }

  void _showSuccessDialog(String appointmentId, DateTime start, DateTime end) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Appointment Booked!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                'Your appointment request has been sent successfully.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow('Counsellor', _selectedCounsellorName),
                    const Divider(),
                    _DetailRow(
                        'Date', DateFormat('EEE, MMM d, yyyy').format(start)),
                    const Divider(),
                    _DetailRow(
                      'Time',
                      '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}',
                    ),
                    const Divider(),
                    _DetailRow(
                        'Type',
                        _sessionType == SessionType.online
                            ? 'Online (Google Meet)'
                            : 'Face-to-Face'),
                    if (_selectedReason != null) ...[
                      const Divider(),
                      _DetailRow('Reason', _selectedReason!)
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Next Steps',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                '• The counsellor will review your request and confirm within 24 hours\n'
                '• You\'ll receive a notification once confirmed\n'
                '• Check your appointment details for more information',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              context.go('/student/dashboard');
            },
            child: const Text('Home'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              context.go('/student/appointments');
            },
            child: const Text('My Appointments'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please sign in')));
      return;
    }

    if (_selectedCounsellorId.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select counsellor, date, and time')),
      );
      return;
    }

    if (_initialProblem.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your initial problem')),
      );
      return;
    }

    // Check for availability issues
    if (_availabilityIssues.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot book: ${_availabilityIssues.join(' ')}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final start = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      final end = start.add(const Duration(minutes: 45));

      // Sentiment on notes
      String? sentiment;
      String? risk;
      if (_notes.text.trim().isNotEmpty) {
        final ai = GeminiService();
        final result = await ai.analyzeSentiment(_notes.text.trim());
        sentiment = result['sentiment'] as String?;
        risk = result['riskLevel'] as String?;
      }

      final fs = FirestoreService();
      final id = await fs.createAppointment(
        studentId: user.uid,
        counsellorId: _selectedCounsellorId,
        start: start,
        end: end,
        topic: _topic.text.trim().isEmpty ? null : _topic.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        sentiment: sentiment,
        riskLevel: risk,
        sessionType: _sessionType,
        initialProblem: _initialProblem.text.trim().isEmpty
            ? null
            : _initialProblem.text.trim(),
      );

      if (mounted) {
        _showSuccessDialog(id, start, end);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Book an appointment',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Counsellor Selection Card
          SectionCard(
            title: 'Step 1: Select Counsellor',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedCounsellorId.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Please select a counsellor',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedCounsellorName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _selectCounsellor,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Browse & Select Counsellor'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Booking Details Card
          SectionCard(
            title: 'Step 2: Schedule & Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedCounsellorId.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Select a counsellor to view available dates and times.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  )
                else
                  Consumer(builder: (context, ref, _) {
                    // Check if user is authenticated before fetching appointments
                    final authState = ref.watch(authStateProvider);

                    if (authState.value == null) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    // Use stable provider instead of creating stream on every rebuild
                    final appointmentsAsync = ref.watch(
                        counsellorAppointmentsProvider(_selectedCounsellorId));

                    return appointmentsAsync.when(
                      data: (booked) {
                        final Map<DateTime, List<Appointment>> apptsByDay = {};
                        for (final a in booked) {
                          final d = DateTime(
                              a.start.year, a.start.month, a.start.day);
                          apptsByDay.putIfAbsent(d, () => []).add(a);
                        }

                        final selectedDay = _selectedDate ?? DateTime.now();
                        final slots = _buildSlotsForDay(selectedDay, booked);
                        final now = DateTime.now();
                        final availableSlots = slots.where((s) {
                          if (isSameDay(selectedDay, now)) {
                            return s.start.isAfter(now);
                          }
                          return true;
                        }).toList();

                        // Check if Sunday is selected
                        final isSunday = selectedDay.weekday == DateTime.sunday;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pick a date',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: TableCalendar<Appointment>(
                                  firstDay: DateTime.now(),
                                  lastDay: DateTime.now()
                                      .add(const Duration(days: 90)),
                                  focusedDay: _selectedDate ?? _focusedDay,
                                  selectedDayPredicate: (day) =>
                                      isSameDay(_selectedDate, day),
                                  enabledDayPredicate: _isSelectableDay,
                                  eventLoader: (day) {
                                    final date =
                                        DateTime(day.year, day.month, day.day);
                                    return apptsByDay[date] ?? [];
                                  },
                                  onDaySelected: (day, focus) {
                                    setState(() {
                                      _selectedDate = day;
                                      _focusedDay = focus;
                                      _selectedTime = null;
                                      _availabilityIssues = [];
                                    });
                                  },
                                  calendarStyle: CalendarStyle(
                                    todayDecoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    selectedDecoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    markerDecoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    markersAlignment: Alignment.bottomCenter,
                                  ),
                                  headerStyle: const HeaderStyle(
                                      formatButtonVisible: false),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Available time slots (${_sessionType == SessionType.online ? 'Online: 24 hours' : 'Face-to-face: 9:00 AM - 6:00 PM'})',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            if (isSunday)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border: Border.all(color: Colors.red),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Sundays are closed. Please select a different day.',
                                  style: TextStyle(color: Colors.red),
                                ),
                              )
                            else if (availableSlots.isEmpty)
                              const Text('No available slots for this day.')
                            else
                              SizedBox(
                                height: 340,
                                child: ListView.separated(
                                  itemCount: availableSlots.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final slot = availableSlots[index];
                                    final isSelected = _selectedDate != null &&
                                        _selectedTime?.hour ==
                                            slot.start.hour &&
                                        _selectedTime?.minute ==
                                            slot.start.minute;
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedDate = selectedDay;
                                          _selectedTime = TimeOfDay(
                                            hour: slot.start.hour,
                                            minute: slot.start.minute,
                                          );
                                          _availabilityIssues = [];
                                        });
                                        _checkAvailability();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.green.shade100
                                              : Colors.green.shade50,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.green
                                                : Colors.green.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.schedule,
                                                color: Colors.green),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                '${DateFormat('h:mm a').format(slot.start)} - ${DateFormat('h:mm a').format(slot.end)}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                            if (isSelected)
                                              const Icon(Icons.check,
                                                  size: 16,
                                                  color: Colors.green),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, st) => Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unable to load available slots',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if ('$err'.contains('permission')) ...[
                              const Text(
                                  'Please check your internet connection and try again.',
                                  style: TextStyle(fontSize: 13)),
                            ] else ...[
                              Text('Error: $err',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry'),
                                onPressed: () {
                                  ref.invalidate(counsellorAppointmentsProvider(
                                      _selectedCounsellorId));
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                if (_checkingAvailability)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (_availabilityIssues.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              'Time Not Available',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._availabilityIssues.map((issue) => Text(
                              '• $issue',
                              style: TextStyle(color: Colors.red.shade700),
                            )),
                      ],
                    ),
                  ),
                if (_availabilityIssues.isEmpty &&
                    _selectedDate != null &&
                    _selectedTime != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Time slot is available',
                          style: TextStyle(
                              color: Colors.green, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SessionType>(
                  value: _sessionType,
                  decoration: const InputDecoration(labelText: 'Session Type'),
                  items: const [
                    DropdownMenuItem(
                        value: SessionType.online,
                        child: Text('Online (Google Meet)')),
                    DropdownMenuItem(
                        value: SessionType.faceToFace,
                        child: Text('Face-to-Face')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sessionType = value;
                        _selectedTime = null;
                        _availabilityIssues = [];
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'Reason for booking *',
                    hintText: 'Select the main reason',
                  ),
                  items: _reasonOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => _selectedReason = val);
                    _applyReasonDefaults(val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _initialProblem,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason details',
                    hintText: 'You can edit or add more detail',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _topic,
                  decoration: const InputDecoration(
                      labelText: 'Topic (auto-filled, editable)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText:
                          'Notes for counsellor (auto-filled, editable)'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (_submitting || _availabilityIssues.isNotEmpty)
                      ? null
                      : _submit,
                  child: _submitting
                      ? const CircularProgressIndicator()
                      : const Text('Send request'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotInfo {
  const _SlotInfo({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounsellorSelectionDialog extends ConsumerStatefulWidget {
  final List<UserProfile> counsellors;
  final Function(UserProfile) onSelected;
  final String selectedReasonText;
  final String userProblem;
  final String userTopic;
  final String userNotes;

  const _CounsellorSelectionDialog({
    required this.counsellors,
    required this.onSelected,
    required this.selectedReasonText,
    required this.userProblem,
    required this.userTopic,
    required this.userNotes,
  });

  @override
  ConsumerState<_CounsellorSelectionDialog> createState() =>
      _CounsellorSelectionDialogState();
}

class _CounsellorSelectionDialogState
    extends ConsumerState<_CounsellorSelectionDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<UserProfile> get _filteredCounsellors {
    if (_searchQuery.isEmpty) return widget.counsellors;
    final query = _searchQuery.toLowerCase();
    return widget.counsellors
        .where((c) =>
            c.displayName.toLowerCase().contains(query) ||
            c.email.toLowerCase().contains(query) ||
            (c.expertise?.toLowerCase().contains(query) ?? false))
        .toList();
  }

  Future<List<UserProfile>> _getAiRecommendedCounsellors() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      return widget.counsellors.take(3).toList();
    }

    final fs = ref.read(firestoreProvider);
    final gemini = GeminiService();

    // Pull signals: recent moods + past appointments
    final recentMoods = await fs.getRecentMoodEntries(user.uid);
    final pastAppointments = (await fs.appointmentsForUser(user.uid).first)
        .where((a) => a.end.isBefore(DateTime.now()))
        .toList();

    // Build AI prompt similar to catalogue page
    final moodContext = recentMoods.isEmpty
        ? 'No recent mood entries'
        : recentMoods
            .where((m) => m.timestamp
                .isAfter(DateTime.now().subtract(const Duration(days: 30))))
            .map((m) =>
                'Date: ${DateFormat('MMM d').format(m.timestamp)}, Mood: ${m.moodScore}/10, Note: ${m.note.isNotEmpty ? m.note : "none"}')
            .join('; ');

    final appointmentContext = pastAppointments.isEmpty
        ? 'No previous counselling sessions'
        : 'Had ${pastAppointments.length} previous sessions';

    final counsellorContext = widget.counsellors.map((c) {
      return '- ${c.displayName} (ID: ${c.uid}): '
          '${c.expertise ?? "General counselling"}, '
          '${c.designation ?? "Counsellor"}';
    }).join('\n');

    final userReason = widget.selectedReasonText.isNotEmpty
        ? widget.selectedReasonText
        : (widget.userProblem.isNotEmpty ? widget.userProblem : 'General');

    final prompt = '''
Based on the student's profile and stated reason, recommend the most suitable counsellors.

STUDENT INPUT:
Reason: $userReason
Additional notes: ${widget.userNotes}

Recent Mood History (last 30 days): $moodContext
Counselling History: $appointmentContext

AVAILABLE COUNSELLORS:
$counsellorContext

Provide recommendations as a JSON array with counsellor UIDs in priority order (most suitable first). Limit to top 3.
Respond ONLY with JSON like {"recommendations": ["uid1", "uid2"]}
''';

    try {
      final response = await gemini.sendMessage(prompt);
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;

      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonStr = response.substring(jsonStart, jsonEnd);
        final match =
            RegExp(r'"recommendations"\s*:\s*\[([^\]]+)\]').firstMatch(jsonStr);
        if (match != null) {
          final uidList = match.group(1);
          if (uidList != null) {
            final uids = uidList
                .split(',')
                .map((s) => s.trim().replaceAll('"', ''))
                .where((s) => s.isNotEmpty)
                .toList();
            final mapped =
                widget.counsellors.where((c) => uids.contains(c.uid)).toList();
            mapped.sort(
                (a, b) => uids.indexOf(a.uid).compareTo(uids.indexOf(b.uid)));
            if (mapped.isNotEmpty) return mapped.take(3).toList();
          }
        }
      }
    } catch (_) {
      // fall back below
    }

    // Fallback: heuristic similar to catalogue
    if (recentMoods.isNotEmpty) {
      final avgMood =
          recentMoods.map((m) => m.moodScore).reduce((a, b) => a + b) /
              recentMoods.length;
      final filtered = avgMood < 5
          ? widget.counsellors.where((c) {
              final exp = (c.expertise ?? '').toLowerCase();
              return exp.contains('mental') ||
                  exp.contains('depression') ||
                  exp.contains('anxiety');
            }).toList()
          : widget.counsellors;
      if (filtered.isNotEmpty) return filtered.take(3).toList();
    }

    return widget.counsellors.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Select a Counsellor'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 540),
        child: SizedBox(
          height: 500,
          width: double.maxFinite,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Browse'),
                  Tab(text: 'AI Recommendations'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Browse Tab
                    Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() => _searchQuery = val);
                          },
                          decoration: InputDecoration(
                            hintText: 'Search by name, email, or expertise...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _filteredCounsellors.isEmpty
                              ? Center(
                                  child: Text(
                                    _searchQuery.isEmpty
                                        ? 'No counsellors available'
                                        : 'No results found',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _filteredCounsellors.length,
                                  itemBuilder: (context, index) {
                                    final c = _filteredCounsellors[index];
                                    return _CounsellorListTile(
                                      counsellor: c,
                                      onSelected: () => widget.onSelected(c),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                    // AI Recommendations Tab
                    FutureBuilder<List<UserProfile>>(
                      future: _getAiRecommendedCounsellors(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        final recommended = snapshot.data ?? [];
                        return recommended.isEmpty
                            ? const Center(
                                child: Text('No recommendations available'),
                              )
                            : ListView.builder(
                                itemCount: recommended.length,
                                itemBuilder: (context, index) {
                                  final c = recommended[index];
                                  return _CounsellorListTile(
                                    counsellor: c,
                                    onSelected: () => widget.onSelected(c),
                                    isRecommended: true,
                                  );
                                },
                              );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _CounsellorListTile extends ConsumerWidget {
  final UserProfile counsellor;
  final VoidCallback onSelected;
  final bool isRecommended;

  const _CounsellorListTile({
    required this.counsellor,
    required this.onSelected,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreProvider);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        onTap: onSelected,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade200,
          child: Text(
            counsellor.displayName[0].toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                counsellor.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isRecommended)
              const Chip(
                label: Text('Recommended'),
                labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(counsellor.email, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: fs.userLeaves(counsellor.uid),
              builder: (context, snap) {
                final nowMs = DateTime.now().millisecondsSinceEpoch;
                if (!counsellor.isActive) {
                  return const Text(
                    'Inactive',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  );
                }

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
                  return Text(
                    'Out of service until ${DateFormat('MMM d').format(e)}',
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12),
                  );
                }

                leaves.sort((a, b) =>
                    (a['startDate'] as int).compareTo(b['startDate'] as int));
                final upcoming = leaves.firstWhere(
                    (l) => (l['startDate'] as int) >= nowMs,
                    orElse: () => {});
                if (upcoming.isNotEmpty) {
                  final s = DateTime.fromMillisecondsSinceEpoch(
                      upcoming['startDate'] as int);
                  return Text(
                    'Leave from ${DateFormat('MMM d').format(s)}',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  );
                }

                return const Text(
                  'Available',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                );
              },
            ),
            if (counsellor.expertise != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Chip(
                  label: Text(counsellor.expertise!),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
        trailing: TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CounsellorDetailPage(counsellor: counsellor),
              ),
            );
          },
          child: const Text('Details'),
        ),
      ),
    );
  }
}

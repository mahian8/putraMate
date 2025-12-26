import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/appointment.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../common/common_widgets.dart';
import 'counsellor_detail_page.dart';

class BookingCalendarPage extends ConsumerStatefulWidget {
  const BookingCalendarPage({super.key, this.counsellorId, this.counsellorName});

  final String? counsellorId;
  final String? counsellorName;

  @override
  ConsumerState<BookingCalendarPage> createState() => _BookingCalendarPageState();
}

class _BookingCalendarPageState extends ConsumerState<BookingCalendarPage> {
  late String _selectedCounsellorId;
  late String _selectedCounsellorName;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<String> _availabilityIssues = [];
  bool _checkingAvailability = false;
  final _topic = TextEditingController();
  final _notes = TextEditingController();
  final _initialProblem = TextEditingController();
  SessionType _sessionType = SessionType.online;
  bool _submitting = false;

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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _checkAvailability();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
      _checkAvailability();
    }
  }

  Future<void> _checkAvailability() async {
    if (_selectedCounsellorId.isEmpty || _selectedDate == null || _selectedTime == null) {
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

          final counsellors = snapshot.data ?? [];

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

          return AlertDialog(
            title: const Text('Select a Counsellor'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: counsellors.length,
                itemBuilder: (context, index) {
                  final c = counsellors[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            title: Text(c.displayName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.email),
                                if (c.expertise != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Chip(
                                      label: Text(c.expertise!),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(context, c);
                              setState(() {
                                _selectedCounsellorId = c.uid;
                                _selectedCounsellorName = c.displayName;
                                _availabilityIssues = [];
                              });
                              _checkAvailability();
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.info, size: 16),
                                label: const Text('View Details'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CounsellorDetailPage(counsellor: c),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
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

    if (_selectedCounsellorId.isEmpty || _selectedDate == null || _selectedTime == null) {
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
        initialProblem: _initialProblem.text.trim().isEmpty ? null : _initialProblem.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request sent to $_selectedCounsellorName'),
            action: risk == 'high' || risk == 'critical'
                ? SnackBarAction(label: 'Flagged', onPressed: () {})
                : null,
          ),
        );
        Navigator.of(context).pop(id);
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _selectedDate == null
                              ? 'Choose date'
                              : '${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule),
                        label: Text(
                          _selectedTime == null
                              ? 'Choose time'
                              : _selectedTime!.format(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                if (_availabilityIssues.isEmpty && _selectedDate != null && _selectedTime != null)
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
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SessionType>(
                  value: _sessionType,
                  decoration: const InputDecoration(labelText: 'Session Type'),
                  items: const [
                    DropdownMenuItem(value: SessionType.online, child: Text('Online (Google Meet)')),
                    DropdownMenuItem(value: SessionType.faceToFace, child: Text('Face-to-Face')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sessionType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _initialProblem,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Initial Problem / Reason for Booking *',
                    hintText: 'Please describe what you would like to discuss',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _topic,
                  decoration: const InputDecoration(labelText: 'Topic (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes for counsellor (sentiment-checked)'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (_submitting || _availabilityIssues.isNotEmpty) ? null : _submit,
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

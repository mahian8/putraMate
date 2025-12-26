import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/appointment.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../common/common_widgets.dart';

class BookingCalendarPage extends ConsumerStatefulWidget {
  const BookingCalendarPage({super.key, this.counsellorId, this.counsellorName});

  final String? counsellorId;
  final String? counsellorName;

  @override
  ConsumerState<BookingCalendarPage> createState() => _BookingCalendarPageState();
}

class _BookingCalendarPageState extends ConsumerState<BookingCalendarPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _topic = TextEditingController();
  final _notes = TextEditingController();
  final _initialProblem = TextEditingController();
  SessionType _sessionType = SessionType.online;
  bool _submitting = false;

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
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please sign in')));
      return;
    }

    final counsellorId = widget.counsellorId ?? '';
    final counsellorName = widget.counsellorName ?? 'Counsellor';

    if (counsellorId.isEmpty || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select counsellor, date, and time')),
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
        counsellorId: counsellorId,
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
            content: Text('Request sent to $counsellorName'),
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
    final counsellorName = widget.counsellorName ?? 'Counsellor';

    return PrimaryScaffold(
      title: 'Book with $counsellorName',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Pick a time',
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
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
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

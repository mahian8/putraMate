import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/journal_entry.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';

final firestoreProvider = Provider((ref) => FirestoreService());

class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({super.key});

  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  double _mood = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _addEntry() async {
    final user = ref.read(authStateProvider).value;
    if (user == null || _title.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final entry = JournalEntry(
        id: '',
        userId: user.uid,
        title: _title.text.trim(),
        content: _content.text.trim(),
        moodScore: _mood.toInt(),
        createdAt: DateTime.now(),
      );
      
      await ref.read(firestoreProvider).addJournalEntry(entry);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal entry saved!')),
        );
        setState(() {
          _title.clear();
          _content.clear();
          _mood = 5;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    
    if (user == null) {
      return const PrimaryScaffold(
        title: 'Journal',
        body: Center(child: Text('Please sign in')),
      );
    }

    final entriesStream = ref.watch(firestoreProvider).journalEntries(user.uid);

    return PrimaryScaffold(
      title: 'Journal',
      body: StreamBuilder<List<JournalEntry>>(
        stream: entriesStream,
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];
          
          return Column(
            children: [
              SectionCard(
                title: 'Add entry',
                child: Column(
                  children: [
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _content,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Reflection'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Mood'),
                        Expanded(
                          child: Slider(
                            min: 1,
                            max: 10,
                            divisions: 9,
                            value: _mood,
                            label: _mood.toStringAsFixed(0),
                            onChanged: (v) => setState(() => _mood = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _addEntry,
                      child: _isSubmitting
                          ? const CircularProgressIndicator()
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const EmptyState(message: 'No entries yet')
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Card(
                            child: ListTile(
                              title: Text(entry.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM d, y').format(entry.createdAt),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: Chip(label: Text('Mood ${entry.moodScore}')),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

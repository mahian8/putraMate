import 'package:flutter/material.dart';
import '../common/common_widgets.dart';

class SessionNotesPage extends StatefulWidget {
  const SessionNotesPage({super.key});

  @override
  State<SessionNotesPage> createState() => _SessionNotesPageState();
}

class _SessionNotesPageState extends State<SessionNotesPage> {
  final _notes = TextEditingController();
  final List<String> _saved = [];

  void _save() {
    if (_notes.text.isEmpty) return;
    setState(() {
      _saved.insert(0, _notes.text);
      _notes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Session notes',
      body: Column(
        children: [
          SectionCard(
            title: 'Add note',
            child: Column(
              children: [
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Summary'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _save, child: const Text('Save note')),
              ],
            ),
          ),
          Expanded(
            child: _saved.isEmpty
                ? const EmptyState(message: 'No notes yet')
                : ListView(
                    children: _saved
                        .map((text) => Card(child: ListTile(title: Text(text))))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../common/common_widgets.dart';

class AvailabilityEditorPage extends StatefulWidget {
  const AvailabilityEditorPage({super.key});

  @override
  State<AvailabilityEditorPage> createState() => _AvailabilityEditorPageState();
}

class _AvailabilityEditorPageState extends State<AvailabilityEditorPage> {
  final List<String> _slots = ['Mon 10:00', 'Tue 14:00'];
  final _controller = TextEditingController();

  void _add() {
    if (_controller.text.isEmpty) return;
    setState(() {
      _slots.add(_controller.text);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Availability',
      body: Column(
        children: [
          SectionCard(
            title: 'Add slot',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(labelText: 'e.g. Wed 15:00'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: _slots
                  .map((s) => Card(
                        child: ListTile(
                          title: Text(s),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() => _slots.remove(s)),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

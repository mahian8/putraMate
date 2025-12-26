import 'package:flutter/material.dart';
import '../common/common_widgets.dart';

class ResolveConflictsPage extends StatelessWidget {
  const ResolveConflictsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final conflicts = ['Student booked two slots', 'Counsellor double-booked'];
    return PrimaryScaffold(
      title: 'Resolve conflicts',
      body: ListView(
        children: conflicts
            .map((c) => Card(
                  child: ListTile(
                    title: Text(c),
                    trailing: ElevatedButton(onPressed: () {}, child: const Text('Resolve')),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

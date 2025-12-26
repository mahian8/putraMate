import 'package:flutter/material.dart';
import '../common/common_widgets.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = ['Login success', 'Booking created'];
    return PrimaryScaffold(
      title: 'System logs',
      body: ListView(
        children: logs
            .map((l) => Card(
                  child: ListTile(
                    title: Text(l),
                    subtitle: const Text('Limited view for privacy'),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

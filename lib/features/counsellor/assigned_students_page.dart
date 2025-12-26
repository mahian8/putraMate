import 'package:flutter/material.dart';
import '../common/common_widgets.dart';

class AssignedStudentsPage extends StatelessWidget {
  const AssignedStudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final students = ['Aina', 'Rahul', 'Mei'];
    return PrimaryScaffold(
      title: 'Assigned students',
      body: ListView(
        children: students
            .map((name) => Card(
                  child: ListTile(
                    title: Text(name),
                    subtitle: const Text('Mood trend: stable'),
                    trailing: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Insights'),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

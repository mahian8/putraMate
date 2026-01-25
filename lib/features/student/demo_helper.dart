import 'package:flutter/material.dart';
import 'student_demo_page.dart';

/// Helper widget to add a demo button to any page (for manual access)
class DemoAccessButton extends StatelessWidget {
  const DemoAccessButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton(
        mini: true,
        tooltip: 'Show Demo',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const StudentDemoPage(),
            ),
          );
        },
        child: const Icon(Icons.help_outline),
      ),
    );
  }
}

/// Example of how to use the demo manually
void showDemoExample(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const StudentDemoPage(),
    ),
  );
}

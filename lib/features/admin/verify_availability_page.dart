import 'package:flutter/material.dart';
import '../common/common_widgets.dart';

class VerifyAvailabilityPage extends StatelessWidget {
  const VerifyAvailabilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = ['Aisha - Mon 10:00', 'Daniel - Tue 14:00'];
    return PrimaryScaffold(
      title: 'Verify availability',
      body: ListView(
        children: items
            .map((i) => Card(
                  child: ListTile(
                    title: Text(i),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(onPressed: () {}, icon: const Icon(Icons.check, color: Colors.green)),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.close, color: Colors.red)),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

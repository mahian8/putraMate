import 'package:flutter/material.dart';
import '../common/common_widgets.dart';

class CommunityModerationPage extends StatelessWidget {
  const CommunityModerationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flagged = ['Post 1 flagged', 'Post 2 flagged'];
    return PrimaryScaffold(
      title: 'Community moderation',
      body: ListView(
        children: flagged
            .map((f) => Card(
                  child: ListTile(
                    title: Text(f),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(onPressed: () {}, icon: const Icon(Icons.visibility)),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline)),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

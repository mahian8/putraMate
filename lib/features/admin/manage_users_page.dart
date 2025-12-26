import 'package:flutter/material.dart';
import '../common/common_widgets.dart';
import '../../models/user_profile.dart';

class ManageUsersPage extends StatelessWidget {
  const ManageUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final users = [
      {'name': 'Aina', 'role': UserRole.student},
      {'name': 'Daniel', 'role': UserRole.counsellor},
      {'name': 'Admin', 'role': UserRole.admin},
    ];
    return PrimaryScaffold(
      title: 'Manage users',
      body: ListView(
        children: users
            .map((u) => Card(
                  child: ListTile(
                    title: Text(u['name'] as String),
                    subtitle: RoleBadge(role: u['role'] as UserRole),
                    trailing: PopupMenuButton<String>(
                      onSelected: (_) {},
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'student', child: Text('Set student')),
                        PopupMenuItem(value: 'counsellor', child: Text('Set counsellor')),
                        PopupMenuItem(value: 'admin', child: Text('Set admin')),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

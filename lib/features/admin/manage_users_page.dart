import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:html' as html;
import '../common/common_widgets.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

// Helper function to add HTML attributes to form fields
void _addFormFieldAttributes() {
  try {
    final inputs = html.document.querySelectorAll(
        'input[type="text"], input[type="email"], input[type="password"], input[type="date"]');
    for (var i = 0; i < inputs.length; i++) {
      final input = inputs[i] as html.InputElement;

      // Only add if not already present
      if (input.id.isEmpty) {
        input.id = 'field_$i';
      }
      if ((input.name?.isEmpty ?? true)) {
        input.name = 'field_$i';
      }

      // Add autocomplete attributes based on field type
      final placeholder = input.placeholder.toLowerCase();
      if (placeholder.contains('name')) {
        input.autocomplete = 'name';
      } else if (placeholder.contains('email')) {
        input.autocomplete = 'email';
      } else if (placeholder.contains('password')) {
        input.autocomplete = 'current-password';
      } else if (placeholder.contains('phone')) {
        input.autocomplete = 'tel';
      } else {
        input.autocomplete = 'off';
      }
    }
  } catch (e) {
    // Silently ignore if web APIs are not available
  }
}

final _fsProvider = Provider((ref) => FirestoreService());
final _authProvider = Provider((ref) => AuthService());

class ManageUsersPage extends ConsumerStatefulWidget {
  const ManageUsersPage({super.key});

  @override
  ConsumerState<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends ConsumerState<ManageUsersPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _studentId = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _gender = TextEditingController();
  final _bloodType = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Add HTML attributes to form fields when page loads
    Future.delayed(const Duration(milliseconds: 500), _addFormFieldAttributes);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _studentId.dispose();
    _phoneNumber.dispose();
    _dateOfBirth.dispose();
    _gender.dispose();
    _bloodType.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.trim().isEmpty ||
        _studentId.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please fill required fields (Name, Email, Password, Student ID)')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(_authProvider).createStudentWithPassword(
            email: _email.text.trim(),
            password: _password.text.trim(),
            displayName: _name.text.trim(),
            studentId: _studentId.text.trim(),
            phoneNumber: _phoneNumber.text.trim().isEmpty
                ? null
                : _phoneNumber.text.trim(),
            dateOfBirth: _dateOfBirth.text.trim().isEmpty
                ? null
                : _dateOfBirth.text.trim(),
            gender: _gender.text.trim().isEmpty ? null : _gender.text.trim(),
            bloodType:
                _bloodType.text.trim().isEmpty ? null : _bloodType.text.trim(),
          );

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                const Text('Success!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Student account created successfully!'),
                const SizedBox(height: 12),
                Text('Email: ${_email.text.trim()}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Name: ${_name.text.trim()}'),
                Text('Student ID: ${_studentId.text.trim()}'),
                const SizedBox(height: 12),
                const Text('The student can now log in with their credentials.',
                    style:
                        TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Clear form
        _name.clear();
        _email.clear();
        _password.clear();
        _studentId.clear();
        _phoneNumber.clear();
        _dateOfBirth.clear();
        _gender.clear();
        _bloodType.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentStream = ref.watch(_fsProvider).allStudents();

    return PrimaryScaffold(
      title: 'Manage Students',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Add Student',
            child: Column(
              children: [
                TextField(
                    controller: _name,
                    decoration:
                        const InputDecoration(labelText: 'Display Name *')),
                const SizedBox(height: 8),
                TextField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email *')),
                const SizedBox(height: 8),
                TextField(
                  controller: _password,
                  decoration:
                      const InputDecoration(labelText: 'Temporary Password *'),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                TextField(
                    controller: _studentId,
                    decoration:
                        const InputDecoration(labelText: 'Student ID *')),
                const SizedBox(height: 8),
                TextField(
                    controller: _phoneNumber,
                    decoration: const InputDecoration(
                        labelText: 'Phone Number (optional)')),
                const SizedBox(height: 8),
                TextField(
                  controller: _dateOfBirth,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth (optional)',
                    hintText: 'YYYY-MM-DD',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                    controller: _gender,
                    decoration:
                        const InputDecoration(labelText: 'Gender (optional)')),
                const SizedBox(height: 8),
                TextField(
                    controller: _bloodType,
                    decoration: const InputDecoration(
                        labelText: 'Blood Type (optional)')),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _sending ? null : _createStudent,
                  child: _sending
                      ? const CircularProgressIndicator()
                      : const Text('Create Student Account'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will create a complete student account with login credentials.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Active Students',
            child: StreamBuilder<List<UserProfile>>(
              stream: studentStream,
              builder: (context, snapshot) {
                final list = snapshot.data ?? [];
                if (list.isEmpty) return const Text('No students yet');
                return Column(
                  children: list
                      .map(
                        (s) => ListTile(
                          title: Text(s.displayName),
                          subtitle:
                              Text('${s.email} • ID: ${s.studentId ?? "N/A"}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RoleBadge(role: s.role),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Student'),
                                      content: Text(
                                          'Are you sure you want to delete ${s.displayName}? This will remove their account and all associated data.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && context.mounted) {
                                    try {
                                      await ref
                                          .read(_authProvider)
                                          .deleteUser(s.uid);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Student deleted successfully')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Error deleting student: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

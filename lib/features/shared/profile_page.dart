import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_providers.dart';
import '../common/common_widgets.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  bool _savingName = false;
  bool _changingPassword = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return PrimaryScaffold(
      title: 'Profile',
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) return const EmptyState(message: 'No profile');

          if (_nameController.text != profile.displayName) {
            _nameController.text = profile.displayName;
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: profile.email,
                  decoration: const InputDecoration(
                    labelText: 'Email (cannot change)',
                    border: OutlineInputBorder(),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    RoleBadge(role: profile.role),
                    const SizedBox(width: 8),
                    Text(profile.role.name.toUpperCase()),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _savingName
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save),
                    label: Text(_savingName ? 'Saving...' : 'Save Name'),
                    onPressed: _savingName
                        ? null
                        : () async {
                            final newName = _nameController.text.trim();
                            if (newName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Name cannot be empty')),
                              );
                              return;
                            }
                            setState(() => _savingName = true);
                            try {
                              await ref.read(authServiceProvider).updateDisplayName(newName);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Name updated')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to update name: $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _savingName = false);
                            }
                          },
                  ),
                ),
                const SizedBox(height: 24),
                Text('Personal Details', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _infoTile('Student ID', profile.studentId),
                _infoTile('Phone', profile.phoneNumber),
                _infoTile('Date of Birth', profile.dateOfBirth),
                _infoTile('Gender', profile.gender),
                const SizedBox(height: 8),
                Text('Medical Info', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _infoTile('Blood Type', profile.bloodType),
                _infoTile('Allergies', profile.allergies),
                _infoTile('Medical Conditions', profile.medicalConditions),
                _infoTile('Emergency Contact', profile.emergencyContact),
                _infoTile('Emergency Phone', profile.emergencyContactPhone),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: _changingPassword
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_reset),
                    label: Text(_changingPassword ? 'Updating...' : 'Change Password'),
                    onPressed: _changingPassword
                        ? null
                        : () => _showChangePasswordDialog(context),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                    onPressed: () async => ref.read(authServiceProvider).signOut(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile(String label, String? value) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value?.isNotEmpty == true ? value! : 'Not provided'),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
              ),
              TextField(
                controller: newController,
                obscureText: true,
                    decoration: const InputDecoration(labelText: 'New Password'),
              ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Use at least 8 characters and include a special character.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final currentPwd = currentController.text.trim();
    final newPwd = newController.text.trim();

    if (currentPwd.isEmpty || newPwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill both password fields')),
      );
      return;
    }

    final hasMinLength = newPwd.length >= 8;
    final hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\\/\[\];\'"'"'`~+=]').hasMatch(newPwd);
    if (!hasMinLength || !hasSpecialChar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters and include a special character.')),
      );
      return;
    }

    setState(() => _changingPassword = true);

    try {
      await ref
          .read(authServiceProvider)
          .changePassword(currentPassword: currentPwd, newPassword: newPwd);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change password: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../router/app_router.dart';
import '../common/common_widgets.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _studentId = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  final _bloodType = TextEditingController();
  final _allergies = TextEditingController();
  final _medicalConditions = TextEditingController();
  final _emergencyContact = TextEditingController();
  final _emergencyPhone = TextEditingController();
  
  String? _gender;
  bool _loading = false;
  String? _error;
  String? _passwordStrength;

  String _calculatePasswordStrength(String password) {
    if (password.isEmpty) return '';
    if (password.length < 6) return 'Weak: too short';
    
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasNumber = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:,.<>?]'));
    
    int strength = 0;
    if (hasUpper) strength++;
    if (hasLower) strength++;
    if (hasNumber) strength++;
    if (hasSpecial) strength++;
    
    if (strength < 2) return 'Weak: add uppercase, numbers, or special characters';
    if (strength == 2) return 'Fair: add numbers or special characters for better security';
    if (strength == 3) return 'Good: consider adding more variety';
    return 'Strong: excellent password';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _studentId.dispose();
    _phone.dispose();
    _dob.dispose();
    _bloodType.dispose();
    _allergies.dispose();
    _medicalConditions.dispose();
    _emergencyContact.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).registerStudent(
            email: _email.text.trim(),
            password: _password.text.trim(),
            displayName: _name.text.trim(),
            studentId: _studentId.text.trim(),
            phoneNumber: _phone.text.trim(),
            dateOfBirth: _dob.text.trim(),
            gender: _gender,
            bloodType: _bloodType.text.trim(),
            allergies: _allergies.text.trim(),
            medicalConditions: _medicalConditions.text.trim(),
            emergencyContact: _emergencyContact.text.trim(),
            emergencyContactPhone: _emergencyPhone.text.trim(),
          );
      if (mounted) context.goNamed(AppRoute.dashboard.name);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Create account',
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            Text('Student registration', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            
            // Personal Information
            Text('Personal Information', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name *'),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email *'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              onChanged: (v) => setState(() => _passwordStrength = _calculatePasswordStrength(v)),
              decoration: const InputDecoration(labelText: 'Password *'),
              validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
            ),
            if (_passwordStrength != null && _passwordStrength!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _passwordStrength!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _passwordStrength!.startsWith('Weak') 
                        ? Colors.red 
                        : _passwordStrength!.startsWith('Fair')
                        ? Colors.orange
                        : _passwordStrength!.startsWith('Good')
                        ? Colors.amber
                        : Colors.green,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _studentId,
              decoration: const InputDecoration(labelText: 'Student ID *'),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone number *'),
              keyboardType: TextInputType.phone,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dob,
              decoration: const InputDecoration(
                labelText: 'Date of birth (YYYY-MM-DD) *',
                hintText: '2000-01-15',
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'Gender *'),
              items: ['Male', 'Female', 'Other', 'Prefer not to say']
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _gender = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            
            // Medical Information
            Text('Medical Information', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bloodType,
              decoration: const InputDecoration(
                labelText: 'Blood type (optional)',
                hintText: 'e.g. A+, O-, B+',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _allergies,
              decoration: const InputDecoration(
                labelText: 'Allergies (optional)',
                hintText: 'List any allergies',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _medicalConditions,
              decoration: const InputDecoration(
                labelText: 'Medical conditions (optional)',
                hintText: 'Any conditions we should know',
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            
            // Emergency Contact
            Text('Emergency Contact', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyContact,
              decoration: const InputDecoration(labelText: 'Emergency contact name *'),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyPhone,
              decoration: const InputDecoration(labelText: 'Emergency contact phone *'),
              keyboardType: TextInputType.phone,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading ? const CircularProgressIndicator() : const Text('Sign up'),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    );
  }
}

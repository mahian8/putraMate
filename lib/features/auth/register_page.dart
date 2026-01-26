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
  final _allergiesOther = TextEditingController();
  final _medicalConditions = TextEditingController();
  final _emergencyContact = TextEditingController();
  final _emergencyPhone = TextEditingController();

  String? _gender;
  String? _bloodType;
  String? _allergies;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  // Password validation states
  bool get _hasMinLength => _password.text.length >= 8;
  bool get _hasUpperCase => _password.text.contains(RegExp(r'[A-Z]'));
  bool get _hasSpecialChar =>
      _password.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _studentId.dispose();
    _phone.dispose();
    _dob.dispose();
    _allergiesOther.dispose();
    _medicalConditions.dispose();
    _emergencyContact.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasMinLength || !_hasUpperCase || !_hasSpecialChar) {
      setState(() => _error = 'Password must meet all requirements');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final allergiesText = _allergies == 'Other'
          ? _allergiesOther.text.trim()
          : _allergies ?? '';

      await ref.read(authServiceProvider).registerStudent(
            email: _email.text.trim(),
            password: _password.text.trim(),
            displayName: _name.text.trim(),
            studentId: _studentId.text.trim(),
            phoneNumber: _phone.text.trim(),
            dateOfBirth: _dob.text.trim(),
            gender: _gender,
            bloodType: _bloodType ?? '',
            allergies: allergiesText,
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

  Widget _buildPasswordRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Create account',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                shrinkWrap: true,
                children: [
                  Text('Student Registration',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        border: Border.all(
                            color: Theme.of(context).colorScheme.error),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),

                  // Personal Information
                  Text('Personal Information',
                      style: Theme.of(context).textTheme.titleMedium),
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
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Required';
                      // Prevent students from registering with admin/counselor domains
                      final email = v!.toLowerCase();
                      if (email.endsWith('@admin.com') ||
                          email.endsWith('@upm.com') ||
                          email.endsWith('@counselor.com')) {
                        return 'This email domain is reserved for staff. Use your student email.';
                      }
                      // Basic email format validation
                      if (!email.contains('@') || !email.contains('.')) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  _buildPasswordRequirement(
                      'Minimum 8 characters', _hasMinLength),
                  _buildPasswordRequirement(
                      'One uppercase letter', _hasUpperCase),
                  _buildPasswordRequirement(
                      'One special character', _hasSpecialChar),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _studentId,
                    decoration:
                        const InputDecoration(labelText: 'Student ID *'),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    decoration:
                        const InputDecoration(labelText: 'Phone number *'),
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
                  Text('Medical Information',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _bloodType,
                    decoration: const InputDecoration(
                      labelText: 'Blood type (optional)',
                    ),
                    items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) => setState(() => _bloodType = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _allergies,
                    decoration: const InputDecoration(
                      labelText: 'Allergies (optional)',
                    ),
                    items: [
                      'None',
                      'Peanuts',
                      'Shellfish',
                      'Dairy',
                      'Eggs',
                      'Soy',
                      'Wheat',
                      'Pollen',
                      'Dust',
                      'Pet dander',
                      'Medications',
                      'Other'
                    ]
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChanged: (v) => setState(() => _allergies = v),
                  ),
                  if (_allergies == 'Other') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _allergiesOther,
                      decoration: const InputDecoration(
                        labelText: 'Specify allergy',
                        hintText: 'Please describe your allergy',
                      ),
                      validator: (v) => (v?.isEmpty ?? true)
                          ? 'Please specify the allergy'
                          : null,
                    ),
                  ],
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
                  Text('Emergency Contact',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emergencyContact,
                    decoration: const InputDecoration(
                        labelText: 'Emergency contact name *'),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emergencyPhone,
                    decoration: const InputDecoration(
                        labelText: 'Emergency contact phone *'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Sign up'),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Back to login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Registration Dialog for Login Page
class RegisterDialog extends ConsumerStatefulWidget {
  const RegisterDialog({super.key});

  @override
  ConsumerState<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends ConsumerState<RegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _studentId = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  final _allergiesOther = TextEditingController();
  final _medicalConditions = TextEditingController();
  final _emergencyContact = TextEditingController();
  final _emergencyPhone = TextEditingController();

  String? _gender;
  String? _bloodType;
  String? _allergies;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  // Password validation states
  bool get _hasMinLength => _password.text.length >= 8;
  bool get _hasUpperCase => _password.text.contains(RegExp(r'[A-Z]'));
  bool get _hasSpecialChar =>
      _password.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _studentId.dispose();
    _phone.dispose();
    _dob.dispose();
    _allergiesOther.dispose();
    _medicalConditions.dispose();
    _emergencyContact.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasMinLength || !_hasUpperCase || !_hasSpecialChar) {
      setState(() => _error = 'Password must meet all requirements');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final allergiesText = _allergies == 'Other'
          ? _allergiesOther.text.trim()
          : _allergies ?? '';

      await ref.read(authServiceProvider).registerStudent(
            email: _email.text.trim(),
            password: _password.text.trim(),
            displayName: _name.text.trim(),
            studentId: _studentId.text.trim(),
            phoneNumber: _phone.text.trim(),
            dateOfBirth: _dob.text.trim(),
            gender: _gender,
            bloodType: _bloodType ?? '',
            allergies: allergiesText,
            medicalConditions: _medicalConditions.text.trim(),
            emergencyContact: _emergencyContact.text.trim(),
            emergencyContactPhone: _emergencyPhone.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop(true); // Close dialog on success
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildPasswordRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            shrinkWrap: true,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Student Registration',
                      style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    border:
                        Border.all(color: Theme.of(context).colorScheme.error),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),

              // Personal Information
              Text('Personal Information',
                  style: Theme.of(context).textTheme.titleMedium),
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
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              _buildPasswordRequirement('Minimum 8 characters', _hasMinLength),
              _buildPasswordRequirement('One uppercase letter', _hasUpperCase),
              _buildPasswordRequirement(
                  'One special character', _hasSpecialChar),
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
              Text('Medical Information',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _bloodType,
                decoration: const InputDecoration(
                  labelText: 'Blood type (optional)',
                ),
                items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => _bloodType = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _allergies,
                decoration: const InputDecoration(
                  labelText: 'Allergies (optional)',
                ),
                items: [
                  'None',
                  'Peanuts',
                  'Shellfish',
                  'Dairy',
                  'Eggs',
                  'Soy',
                  'Wheat',
                  'Pollen',
                  'Dust',
                  'Pet dander',
                  'Medications',
                  'Other'
                ]
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (v) => setState(() => _allergies = v),
              ),
              if (_allergies == 'Other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _allergiesOther,
                  decoration: const InputDecoration(
                    labelText: 'Specify allergy',
                    hintText: 'Please describe your allergy',
                  ),
                  validator: (v) => (v?.isEmpty ?? true)
                      ? 'Please specify the allergy'
                      : null,
                ),
              ],
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
              Text('Emergency Contact',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emergencyContact,
                decoration: const InputDecoration(
                    labelText: 'Emergency contact name *'),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emergencyPhone,
                decoration: const InputDecoration(
                    labelText: 'Emergency contact phone *'),
                keyboardType: TextInputType.phone,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Sign up'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

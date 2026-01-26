import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();
  final _studentId = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _bloodType = TextEditingController();

  bool _showVerificationFields = false;
  bool _sent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _studentId.dispose();
    _phoneNumber.dispose();
    _dateOfBirth.dispose();
    _bloodType.dispose();
    super.dispose();
  }

  Future<void> _verifyDetails() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email address');
      return;
    }

    if (!_showVerificationFields) {
      // Check if email exists before showing verification fields
      setState(() {
        _error = null;
        _loading = true;
      });

      try {
        final firestoreService = FirestoreService();
        final exists =
            await firestoreService.checkUserExistsByEmail(_email.text.trim());

        if (!exists) {
          setState(() {
            _error =
                'No account found with this email address. Please check your email or create a new account.';
            _loading = false;
          });
          return;
        }

        setState(() {
          _showVerificationFields = true;
          _loading = false;
        });
      } catch (e) {
        setState(() {
          _error = 'Error checking email: ${e.toString()}';
          _loading = false;
        });
      }
      return;
    }

    // Validate all fields
    if (_studentId.text.trim().isEmpty ||
        _phoneNumber.text.trim().isEmpty ||
        _dateOfBirth.text.trim().isEmpty ||
        _bloodType.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in all verification fields');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final firestoreService = FirestoreService();
      final user = await firestoreService.verifyUserDetailsByEmail(
        email: _email.text.trim(),
        studentId: _studentId.text.trim(),
        phoneNumber: _phoneNumber.text.trim(),
        dateOfBirth: _dateOfBirth.text.trim(),
        bloodType: _bloodType.text.trim(),
      );

      if (user == null) {
        setState(() {
          _error =
              'Verification failed. Please check your details and try again.';
          _loading = false;
        });
        return;
      }

      // Verification successful, send reset email
      await ref.read(authServiceProvider).resetPassword(_email.text.trim());

      setState(() {
        _sent = true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Forgot password',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Please provide your information to verify your identity.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.error),
                ),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ),
          if (_sent)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Verification Successful!',
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        'A password reset email has been sent to ${_email.text.trim()}. Please check your inbox and spam folder.',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          TextField(
            controller: _email,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              hintText: 'your.email@example.com',
              prefixIcon: Icon(Icons.email),
            ),
            enabled: !_loading && !_sent,
            keyboardType: TextInputType.emailAddress,
          ),
          if (_showVerificationFields && !_sent) ...[
            const SizedBox(height: 16),
            const Text(
              'Verification Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _studentId,
              decoration: const InputDecoration(
                labelText: 'Student ID',
                border: OutlineInputBorder(),
                hintText: 'Enter your student ID',
                prefixIcon: Icon(Icons.badge),
              ),
              enabled: !_loading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneNumber,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                hintText: 'Enter your phone number',
                prefixIcon: Icon(Icons.phone),
              ),
              enabled: !_loading,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dateOfBirth,
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                border: OutlineInputBorder(),
                hintText: 'YYYY-MM-DD',
                prefixIcon: Icon(Icons.cake),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              enabled: !_loading,
              readOnly: true,
              onTap: _selectDate,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _bloodType.text.isEmpty ? null : _bloodType.text,
              decoration: const InputDecoration(
                labelText: 'Blood Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bloodtype),
              ),
              items: const [
                DropdownMenuItem(value: 'A+', child: Text('A+')),
                DropdownMenuItem(value: 'A-', child: Text('A-')),
                DropdownMenuItem(value: 'B+', child: Text('B+')),
                DropdownMenuItem(value: 'B-', child: Text('B-')),
                DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                DropdownMenuItem(value: 'O+', child: Text('O+')),
                DropdownMenuItem(value: 'O-', child: Text('O-')),
              ],
              onChanged: _loading
                  ? null
                  : (value) => setState(() => _bloodType.text = value ?? ''),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading || _sent ? null : _verifyDetails,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_showVerificationFields
                    ? 'Verify & Send Reset Link'
                    : 'Continue'),
          ),
        ],
      ),
    );
  }
}

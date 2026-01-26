import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:html' as html;
import '../../models/appointment.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';

final _fsProvider = Provider((ref) => FirestoreService());
final _authProvider = Provider((ref) => AuthService());

// Helper function to add HTML attributes to form fields
void _addFormFieldAttributes() {
  try {
    final inputs = html.document.querySelectorAll(
        'input[type="text"], input[type="email"], input[type="password"]');
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
      } else if (placeholder.contains('id')) {
        input.autocomplete = 'off';
      }
    }
  } catch (e) {
    // Silently ignore if web APIs are not available
  }
}

class ManageCounsellorsPage extends ConsumerStatefulWidget {
  const ManageCounsellorsPage({super.key});

  @override
  ConsumerState<ManageCounsellorsPage> createState() =>
      _ManageCounsellorsPageState();
}

class _ManageCounsellorsPageState extends ConsumerState<ManageCounsellorsPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _counsellorId = TextEditingController();
  final _designation = TextEditingController();
  final _expertise = TextEditingController();
  bool _sending = false;
  bool _hasInvalidEmailDomain = false; // Track if email doesn't have @upm.com

  // Email domain validation - MUST be @upm.com for counselors
  bool get _isEmailValid {
    final email = _email.text.toLowerCase().trim();
    if (email.isEmpty) return true; // Empty is ok (form validator handles it)

    // SECURITY: Counselor emails MUST use @upm.com domain
    // This is a critical security requirement to prevent role confusion
    if (!email.endsWith('@upm.com')) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    // Real-time email domain validation
    _email.addListener(() {
      setState(() {
        _hasInvalidEmailDomain = !_isEmailValid;
      });
    });
    // Add HTML attributes to form fields when page loads
    Future.delayed(const Duration(milliseconds: 500), _addFormFieldAttributes);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _counsellorId.dispose();
    _designation.dispose();
    _expertise.dispose();
    super.dispose();
  }

  Future<void> _createCounsellor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      // Create counsellor account (stored in users collection with role='counsellor')
      await ref.read(_authProvider).createCounsellorWithPassword(
            email: _email.text.trim(),
            password: _password.text.trim(),
            displayName: _name.text.trim(),
            counsellorId: _counsellorId.text.trim(),
            designation: _designation.text.trim(),
            expertise: _expertise.text.trim(),
          );

      if (mounted) {
        // Clear form first
        _name.clear();
        _email.clear();
        _password.clear();
        _counsellorId.clear();
        _designation.clear();
        _expertise.clear();

        // Show success dialog - stays on same page
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 40),
                const SizedBox(width: 12),
                const Text('Counsellor Created!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New counsellor account has been created successfully.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('✓ Stored in Firestore database',
                          style: TextStyle(color: Colors.green[800])),
                      Text('✓ Role: counsellor (explicitly set)',
                          style: TextStyle(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold)),
                      Text('✓ Email domain: @upm.com verified',
                          style: TextStyle(color: Colors.green[800])),
                      Text('✓ Role verified after creation',
                          style: TextStyle(color: Colors.green[800])),
                      Text('✓ Can login immediately',
                          style: TextStyle(color: Colors.green[800])),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ℹ️ IMPORTANT: Check Browser Console',
                          style: TextStyle(
                              color: Colors.blue[900],
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('• Look for verification logs',
                          style:
                              TextStyle(color: Colors.blue[800], fontSize: 12)),
                      Text('• Confirms role = "counsellor"',
                          style:
                              TextStyle(color: Colors.blue[800], fontSize: 12)),
                      Text('• Shows full document data',
                          style:
                              TextStyle(color: Colors.blue[800], fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The counsellor will appear in the list below.',
                  style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Add HTML attributes to new form fields after dialog closes
                  Future.delayed(const Duration(milliseconds: 100),
                      _addFormFieldAttributes);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red[600], size: 32),
                const SizedBox(width: 12),
                const Text('Error'),
              ],
            ),
            content: Text('Failed to create counsellor account:\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counsellorStream = ref.watch(_fsProvider).counsellors();
    final duplicateStream = ref.watch(_fsProvider).duplicateAppointments();

    return PrimaryScaffold(
      title: 'Counsellor Management',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // NEW COUNSELOR FORM SECTION
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[800]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_add, color: Colors.white, size: 32),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add New Counsellor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create counsellor account with full access',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Form Content
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber[100],
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.amber[400]!, width: 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user,
                                  color: Colors.amber[800], size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Role: COUNSELLOR',
                                style: TextStyle(
                                  color: Colors.amber[900],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Full Name
                        TextFormField(
                          controller: _name,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Full Name *',
                            labelStyle:
                                TextStyle(color: Colors.white.withOpacity(0.8)),
                            hintText: 'e.g., Dr. Ahmad Abdullah',
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.5)),
                            prefixIcon: Icon(Icons.person,
                                color: Colors.white.withOpacity(0.7)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 2),
                            ),
                          ),
                          validator: (v) => v?.trim().isEmpty ?? true
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: _email,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Email Address * (MUST be @upm.com)',
                            labelStyle:
                                TextStyle(color: Colors.white.withOpacity(0.8)),
                            hintText: 'counsellor@upm.com',
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.5)),
                            prefixIcon: Icon(Icons.email,
                                color: Colors.white.withOpacity(0.7)),
                            errorText: _hasInvalidEmailDomain
                                ? '🔒 SECURITY: Counselor emails MUST use @upm.com domain'
                                : null,
                            errorMaxLines: 2,
                            errorStyle: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            suffixIcon: _hasInvalidEmailDomain
                                ? const Icon(Icons.error,
                                    color: Colors.redAccent)
                                : _email.text.isNotEmpty && _isEmailValid
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.greenAccent)
                                    : null,
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 2),
                            ),
                            helperText:
                                'Only @upm.com emails can be counselors',
                            helperStyle: TextStyle(
                                color: Colors.amber[300],
                                fontWeight: FontWeight.w500),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true)
                              return 'Email is required';

                            final email = v!.trim().toLowerCase();

                            // STRICT VALIDATION: MUST be @upm.com domain
                            if (!email.endsWith('@upm.com')) {
                              return '🔒 SECURITY ERROR: Counselor accounts MUST use @upm.com domain.\nThis is required to ensure proper role assignment.';
                            }

                            if (!email.contains('@') || !email.contains('.')) {
                              return 'Invalid email format';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextFormField(
                          controller: _password,
                          style: const TextStyle(color: Colors.white),
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Temporary Password *',
                            labelStyle:
                                TextStyle(color: Colors.white.withOpacity(0.8)),
                            hintText: 'Min. 6 characters',
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.5)),
                            prefixIcon: Icon(Icons.lock,
                                color: Colors.white.withOpacity(0.7)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 2),
                            ),
                            helperText:
                                'User can change this after first login',
                            helperStyle:
                                TextStyle(color: Colors.white.withOpacity(0.6)),
                          ),
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true)
                              return 'Password is required';
                            if (v!.length < 6)
                              return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Counsellor ID
                        TextFormField(
                          controller: _counsellorId,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Counsellor ID *',
                            labelStyle:
                                TextStyle(color: Colors.white.withOpacity(0.8)),
                            hintText: 'e.g., CNS001',
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.5)),
                            prefixIcon: Icon(Icons.badge,
                                color: Colors.white.withOpacity(0.7)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 2),
                            ),
                          ),
                          validator: (v) => v?.trim().isEmpty ?? true
                              ? 'Counsellor ID is required'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Designation
                        TextFormField(
                          controller: _designation,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Designation *',
                            labelStyle:
                                TextStyle(color: Colors.white.withOpacity(0.8)),
                            hintText: 'e.g., Senior Counsellor',
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.5)),
                            prefixIcon: Icon(Icons.work,
                                color: Colors.white.withOpacity(0.7)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 2),
                            ),
                          ),
                          validator: (v) => v?.trim().isEmpty ?? true
                              ? 'Designation is required'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Expertise
                        TextFormField(
                          controller: _expertise,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Expertise Areas *',
                            labelStyle:
                                TextStyle(color: Colors.white.withOpacity(0.8)),
                            hintText:
                                'e.g., Anxiety, Depression, Career Guidance',
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.5)),
                            prefixIcon: Icon(Icons.psychology,
                                color: Colors.white.withOpacity(0.7)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 2),
                            ),
                            helperText: 'Separate multiple areas with commas',
                            helperStyle:
                                TextStyle(color: Colors.white.withOpacity(0.6)),
                          ),
                          maxLines: 2,
                          validator: (v) => v?.trim().isEmpty ?? true
                              ? 'Expertise is required'
                              : null,
                        ),
                        const SizedBox(height: 28),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: (_sending || _hasInvalidEmailDomain)
                                ? null
                                : _createCounsellor,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue[700],
                              disabledBackgroundColor:
                                  Colors.white.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 8,
                            ),
                            icon: _sending
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.blue[700]!),
                                    ),
                                  )
                                : _hasInvalidEmailDomain
                                    ? const Icon(Icons.block,
                                        size: 24, color: Colors.red)
                                    : const Icon(Icons.add_circle_outline,
                                        size: 24),
                            label: Text(
                              _sending
                                  ? 'Creating Counsellor...'
                                  : _hasInvalidEmailDomain
                                      ? 'Invalid Email Domain'
                                      : 'Create Counsellor Account',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // COUNSELLORS LIST SECTION
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.group,
                          color: Theme.of(context).primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'All Counsellors',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<UserProfile>>(
                    stream: counsellorStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final counsellors = snapshot.data ?? [];

                      if (counsellors.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.person_off,
                                    size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  'No counsellors yet',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: counsellors.map((counsellor) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                child: Text(
                                  counsellor.displayName
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                counsellor.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(counsellor.email),
                                  if (counsellor.designation?.isNotEmpty ??
                                      false)
                                    Text(
                                      counsellor.designation!,
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete counsellor',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      title: const Text('Delete Counsellor?'),
                                      content: Text(
                                        'Are you sure you want to delete ${counsellor.displayName}?\n\nThis will permanently remove:\n• Their account\n• All their data\n• Access to the system',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true && context.mounted) {
                                    try {
                                      await ref
                                          .read(_authProvider)
                                          .deleteUser(counsellor.uid);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '${counsellor.displayName} deleted successfully'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // DUPLICATE BOOKINGS
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: Colors.orange[700], size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Duplicate Bookings',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<Appointment>>(
                    stream: duplicateStream,
                    builder: (context, snapshot) {
                      final dups = snapshot.data ?? [];

                      if (dups.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green[600]),
                              const SizedBox(width: 12),
                              const Text('No duplicate bookings detected'),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: dups.map((appointment) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            color: Colors.orange[50],
                            child: ListTile(
                              leading: Icon(Icons.error_outline,
                                  color: Colors.orange[700]),
                              title: Text(appointment.topic ?? 'Session'),
                              subtitle: Text(
                                'Student ${appointment.studentId} • ${DateTime.fromMillisecondsSinceEpoch(appointment.start.millisecondsSinceEpoch)}',
                              ),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.cancel, color: Colors.red),
                                tooltip: 'Cancel appointment',
                                onPressed: () => ref
                                    .read(_fsProvider)
                                    .updateAppointmentStatus(
                                      appointmentId: appointment.id,
                                      status: AppointmentStatus.cancelled,
                                    ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

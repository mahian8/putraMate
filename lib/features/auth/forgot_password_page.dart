import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_providers.dart';
import '../common/common_widgets.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _sent = false;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).resetPassword(_email.text.trim());
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Forgot password',
      body: ListView(
        children: [
          Text('We will email you a reset link.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_sent)
            Text('Email sent!', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _submit, child: const Text('Send reset link')),
        ],
      ),
    );
  }
}

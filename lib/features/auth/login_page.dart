import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../router/app_router.dart';
import '../../features/common/common_widgets.dart';
import '../../models/user_profile.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Please enter both email and password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await ref
          .read(authServiceProvider)
          .signIn(_email.text.trim(), _password.text.trim());

      // Determine destination using stored role; force admin for known admin email if profile missing.
      final profile = await ref
          .read(authServiceProvider)
          .profileStream(cred.user!.uid)
          .first;

      final email = cred.user?.email?.toLowerCase();
      final forcedAdmin = email?.endsWith('@admin.com') ?? false;
      final role =
          forcedAdmin ? UserRole.admin : (profile?.role ?? UserRole.student);

      if (!mounted) return;

      // Use direct paths to avoid router redirect conflicts
      switch (role) {
        case UserRole.admin:
          context.go('/admin/dashboard');
          break;
        case UserRole.counsellor:
          context.go('/counsellor/dashboard');
          break;
        case UserRole.student:
          context.go('/student/dashboard');
          break;
      }
    } catch (e) {
      // Extract clean error message by removing "Exception: " prefix
      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring(11);
      }
      setState(() => _error = errorMsg);
      print('✗ Login error: $errorMsg');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Welcome back',
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/images/upmbg.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Contrast overlay to improve readability over the background image
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          ),
          ListView(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    ClipOval(
                      child: Container(
                        height: 120,
                        width: 120,
                        color: Colors.white,
                        child: Image.asset(
                          'assets/images/PutraMate.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.favorite,
                              size: 72,
                              color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Sign in to continue',
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            border: Border.all(
                                color: Theme.of(context).colorScheme.error),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Theme.of(context).colorScheme.error),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                          controller: _email,
                          decoration:
                              const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const CircularProgressIndicator()
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () =>
                            context.pushNamed(AppRoute.register.name),
                        child: const Text('Create student account'),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.pushNamed(AppRoute.forgotPassword.name),
                        child: const Text('Forgot password?'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

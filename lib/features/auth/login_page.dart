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
  String _selectedRole = 'student';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _selectedRole = 'student';
  }

  void _selectRole(String role) => setState(() => _selectedRole = role);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await ref.read(authServiceProvider).signIn(_email.text.trim(), _password.text.trim());

      // Determine destination using stored role; force admin for known admin email if profile missing.
      final profile = await ref
          .read(authServiceProvider)
          .profileStream(cred.user!.uid)
          .first;

      final email = cred.user?.email?.toLowerCase();
      final forcedAdmin = email == 'admin@admin.com';
      final role = forcedAdmin ? UserRole.admin : (profile?.role ?? UserRole.student);
      
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
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                       errorBuilder: (_, __, ___) => const Icon(Icons.favorite, size: 72, color: Colors.red),
                     ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Sign in to continue', style: Theme.of(context).textTheme.titleLarge),
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [scheme.primary.withValues(alpha: 0.08), scheme.secondary.withValues(alpha: 0.06)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.2), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose role to log in', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _RolePill(
                        label: 'Student',
                        icon: Icons.school,
                        isSelected: _selectedRole == 'student',
                        onTap: () => _selectRole('student'),
                      ),
                      _RolePill(
                        label: 'Counsellor',
                        icon: Icons.psychology,
                        isSelected: _selectedRole == 'counsellor',
                        onTap: () => _selectRole('counsellor'),
                      ),
                      _RolePill(
                        label: 'Admin',
                        icon: Icons.admin_panel_settings,
                        isSelected: _selectedRole == 'admin',
                        onTap: () => _selectRole('admin'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const CircularProgressIndicator() : const Text('Sign in'),
          ),
          const SizedBox(height: 16),
          if (_selectedRole == 'student')
            TextButton(
              onPressed: () => context.pushNamed(AppRoute.register.name),
              child: const Text('Create student account'),
            ),
          TextButton(
            onPressed: () => context.pushNamed(AppRoute.forgotPassword.name),
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

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label, required this.isSelected, required this.onTap, required this.icon});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: FilterChip(
        avatar: Icon(icon, size: 18, color: isSelected ? scheme.primary : scheme.onSurface),
        label: Text(label),
        selected: isSelected,
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primary.withValues(alpha: 0.2),
        side: BorderSide(
          color: isSelected ? scheme.primary : scheme.outline.withValues(alpha: 0.4),
          width: isSelected ? 2 : 1,
        ),
        labelStyle: TextStyle(
          color: isSelected ? scheme.primary : scheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../models/user_profile.dart';

class PrimaryScaffold extends StatelessWidget {
  const PrimaryScaffold({super.key, required this.title, this.actions, required this.body, this.fab});
  final String title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    final footerText = 'All rights reserved by PutraMate (UPM) ${DateTime.now().year}';
    return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: fab,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(child: body),
              const SizedBox(height: 12),
              Text(
                footerText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, color: Theme.of(context).colorScheme.primary, size: 48),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});
  final UserRole role;

  Color _color(UserRole role, ColorScheme scheme) {
    switch (role) {
      case UserRole.admin:
        return scheme.error;
      case UserRole.counsellor:
        return scheme.tertiary;
      case UserRole.student:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      backgroundColor: _color(role, scheme).withValues(alpha: 0.12),
      labelStyle: TextStyle(color: _color(role, scheme), fontWeight: FontWeight.w700),
      label: Text(role.name.toUpperCase()),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_profile.dart';

class PrimaryScaffold extends StatelessWidget {
  const PrimaryScaffold({
    super.key,
    required this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    required this.body,
    this.fab,
    this.maxContentWidth = 900,
    this.contentPadding = const EdgeInsets.all(12),
  });
  final String title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget body;
  final Widget? fab;
  final double maxContentWidth;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final footerText =
        'All rights reserved by PutraMate (UPM) ${DateTime.now().year}';
    final canPop = Navigator.of(context).canPop();
    final defaultLeading = leading ??
        (canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null);
    return Scaffold(
      appBar: AppBar(
        leading: defaultLeading,
        title: titleWidget ?? Text(title),
        actions: actions,
      ),
      floatingActionButton: fab,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Padding(
                    padding: contentPadding,
                    child: body,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                footerText,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard(
      {super.key, required this.title, required this.child, this.trailing});
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
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
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
          Icon(Icons.chat_bubble_outline,
              color: Theme.of(context).colorScheme.primary, size: 48),
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
      labelStyle:
          TextStyle(color: _color(role, scheme), fontWeight: FontWeight.w700),
      label: Text(role.name.toUpperCase()),
    );
  }
}

// Simple digital clock for AppBars
class DigitalClock extends StatefulWidget {
  const DigitalClock({super.key});

  @override
  State<DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock> {
  late String _time;
  late final DateFormat _df;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _df = DateFormat('HH:mm:ss');
    _time = _df.format(DateTime.now());
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration _) {
    final now = DateTime.now();
    final t = _df.format(now);
    if (t != _time && mounted) {
      setState(() => _time = t);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        _time,
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
    );
  }
}

// Lightweight ticker using WidgetsBinding
class Ticker {
  Ticker(this.onTick);
  final void Function(Duration) onTick;
  bool _running = false;
  late final Stopwatch _sw = Stopwatch();

  void start() {
    if (_running) return;
    _running = true;
    _sw.start();
    WidgetsBinding.instance.scheduleFrameCallback(_tick);
  }

  void _tick(Duration timeStamp) {
    if (!_running) return;
    onTick(_sw.elapsed);
    WidgetsBinding.instance.scheduleFrameCallback(_tick);
  }

  void dispose() {
    _running = false;
    _sw.stop();
  }
}

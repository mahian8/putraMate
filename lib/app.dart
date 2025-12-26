import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class PutraMateApp extends ConsumerWidget {
  const PutraMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseInit = ref.watch(firebaseAppProvider);

    return firebaseInit.when(
      loading: () => _buildInitApp(const _InitScaffold('Initialising Firebase...')),
      error: (e, _) => _buildInitApp(_InitScaffold('Firebase error: $e')),
      data: (_) {
        final router = ref.watch(routerProvider);
        return _buildRouterApp(router);
      },
    );
  }

  Widget _buildRouterApp(GoRouter router) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'PutraMate',
        theme: AppTheme.light(),
        routerConfig: router,
      );

  Widget _buildInitApp(Widget home) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PutraMate',
        theme: AppTheme.light(),
        home: home,
      );
}

class _InitScaffold extends StatelessWidget {
  const _InitScaffold(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(message)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_profile.dart';
import '../../router/app_router.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';

final _fsProvider = Provider((ref) => FirestoreService());

class CounsellorCatalogPage extends ConsumerWidget {
  const CounsellorCatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(_fsProvider).counsellors();

    return PrimaryScaffold(
      title: 'Counsellors',
      body: StreamBuilder<List<UserProfile>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final counsellors = snapshot.data ?? [];

          if (counsellors.isEmpty) {
            return const EmptyState(message: 'No counsellors available yet');
          }

          return ListView.builder(
            itemCount: counsellors.length,
            itemBuilder: (context, index) {
              final c = counsellors[index];
              return Card(
                child: ListTile(
                  title: Text(c.displayName),
                  subtitle: Text(c.email),
                  trailing: ElevatedButton(
                    onPressed: () => context.pushNamed(
                      AppRoute.booking.name,
                      queryParameters: {
                        'cid': c.uid,
                        'cname': c.displayName,
                      },
                    ),
                    child: const Text('Book'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

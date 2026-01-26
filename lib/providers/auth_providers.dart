import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../firebase_options.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

final firebaseAppProvider = FutureProvider<FirebaseApp>((ref) async {
  return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return const Stream.empty();
  return ref.watch(authServiceProvider).profileStream(authState.uid);
});

final currentRoleProvider = Provider<UserRole?>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  return profile?.role;
});

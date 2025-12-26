import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);

      // Fetch role for logging
      String? role;
      try {
        final doc = await _firestore.collection('users').doc(cred.user?.uid).get();
        role = (doc.data()?['role'] as String?);
        
        // Auto-create admin profile if logging in as admin@admin.com and no profile exists
        if (email.toLowerCase() == 'admin@admin.com' && (!doc.exists || role != 'admin')) {
          await _firestore.collection('users').doc(cred.user?.uid).set({
            'uid': cred.user?.uid,
            'email': email,
            'displayName': 'Admin',
            'role': 'admin',
          }, SetOptions(merge: true));
          role = 'admin';
        }
      } catch (_) {}

      try {
        await _firestore.collection('loginEvents').add({
          'uid': cred.user?.uid,
          'email': email,
          if (role != null) 'role': role,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (_) {}

      return cred;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw 'User not found. Please check your email or create a new account.';
      } else if (e.code == 'wrong-password') {
        throw 'Incorrect password. Please try again.';
      } else if (e.code == 'invalid-email') {
        throw 'Invalid email address.';
      } else if (e.code == 'user-disabled') {
        throw 'This account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        throw 'Too many login attempts. Please try again later.';
      }
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email);

  Future<UserCredential> registerStudent({
    required String email,
    required String password,
    required String displayName,
    String? studentId,
    String? phoneNumber,
    String? dateOfBirth,
    String? gender,
    String? bloodType,
    String? allergies,
    String? medicalConditions,
    String? emergencyContact,
    String? emergencyContactPhone,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user?.updateDisplayName(displayName);
    await _firestore.collection('users').doc(cred.user!.uid).set(
      UserProfile(
        uid: cred.user!.uid,
        email: email,
        displayName: displayName,
        role: UserRole.student,
        studentId: studentId,
        phoneNumber: phoneNumber,
        dateOfBirth: dateOfBirth,
        gender: gender,
        bloodType: bloodType,
        allergies: allergies,
        medicalConditions: medicalConditions,
        emergencyContact: emergencyContact,
        emergencyContactPhone: emergencyContactPhone,
      ).toJson(),
      SetOptions(merge: true),
    );
    return cred;
  }

  Future<void> createCounsellor({
    required String email,
    required String displayName,
    required String uid,
  }) async {
    await _firestore.collection('users').doc(uid).set(
      UserProfile(
        uid: uid,
        email: email,
        displayName: displayName,
        role: UserRole.counsellor,
      ).toJson(),
      SetOptions(merge: true),
    );
  }

  // Admin: Create counsellor with temporary password
  Future<String> createCounsellorWithPassword({
    required String email,
    required String password,
    required String displayName,
    required String counsellorId,
    required String designation,
    required String expertise,
  }) async {
    // Create auth account
    final userCred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = userCred.user!.uid;

    // Create Firestore profile
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': 'counsellor',
      'counsellorId': counsellorId,
      'designation': designation,
      'expertise': expertise,
      'requirePasswordChange': true,
      'isActive': true,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    return uid;
  }

  Stream<UserProfile?> profileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromJson(doc.data() ?? {});
    });
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) throw 'Not signed in';

    await user.updateDisplayName(displayName);
    await _firestore.collection('users').doc(user.uid).set(
          {'displayName': displayName},
          SetOptions(merge: true),
        );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw 'Not signed in';
    final email = user.email;
    if (email == null) throw 'Missing email for this account';

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
    
    // Clear password change requirement
    await _firestore.collection('users').doc(user.uid).update({
      'requirePasswordChange': false,
    });
  }

  // Admin: Toggle user active status
  Future<void> toggleUserStatus(String uid, bool isActive) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': isActive,
    });
  }

  // Admin: Delete user account completely
  Future<void> deleteUserAccount(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
    // Note: Deleting from Firebase Auth requires Admin SDK
  }
}

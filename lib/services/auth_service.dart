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
      print('✓ Auth successful for: $email');

      // Fetch role for logging
      String? role;
      try {
        final doc = await _firestore.collection('users').doc(cred.user?.uid).get();
        print('✓ User doc fetched: exists=${doc.exists}');
        role = (doc.data()?['role'] as String?);
        print('✓ Role fetched: $role');
        
        // Auto-create admin profile if logging in with @admin.com domain and no profile exists
        if (email.toLowerCase().endsWith('@admin.com') && (!doc.exists || role != 'admin')) {
          print('→ Creating admin profile...');
          await _firestore.collection('users').doc(cred.user?.uid).set({
            'uid': cred.user?.uid,
            'email': email,
            'displayName': email.split('@')[0],
            'role': 'admin',
          }, SetOptions(merge: true));
          role = 'admin';
          print('✓ Admin profile created');
        }
      } catch (e) {
        print('✗ Error fetching/creating user profile: $e');
      }

      try {
        print('→ Adding login event...');
        await _firestore.collection('loginEvents').add({
          'uid': cred.user?.uid,
          'email': email,
          if (role != null) 'role': role,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('✓ Login event added successfully');
      } catch (e) {
        print('✗ Error logging login event: $e');
      }

      print('✓ Sign in complete for: $email');
      return cred;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw 'User not found. Please check your email or create a new account.';
      } else if (e.code == 'wrong-password') {
        throw 'Incorrect password. Please try again.';
      } else if (e.code == 'invalid-credential') {
        throw 'Invalid email or password. Please try again.';
      } else if (e.code == 'invalid-email') {
        throw 'Invalid email address.';
      } else if (e.code == 'user-disabled') {
        throw 'This account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        throw 'Too many login attempts. Please try again later.';
      }
      print('✗ Unhandled Firebase error code: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> resetPassword(String email) async {
    try {
      print('→ Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      print('✓ Password reset email sent successfully');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw 'Email not found. Please check your email address.';
      } else if (e.code == 'invalid-email') {
        throw 'Invalid email address format.';
      } else if (e.code == 'too-many-requests') {
        throw 'Too many reset requests. Please try again later.';
      }
      print('✗ Password reset error: ${e.message}');
      throw 'Failed to send reset email: ${e.message}';
    } catch (e) {
      print('✗ Unexpected error sending reset email: $e');
      throw 'Error sending reset email: $e';
    }
  }

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
    // Save current admin credentials
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not signed in as admin';
    final adminEmail = currentUser.email!;
    
    print('→ Creating counsellor account for: $email');
    
    // Create auth account for counsellor (this will sign us in as the counsellor)
    final userCred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = userCred.user!.uid;
    
    print('✓ Auth account created: $uid');

    // Create Firestore profile for counsellor
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
    
    print('✓ Firestore profile created');

    // Sign out the newly created counsellor
    await _auth.signOut();
    print('→ Signed out counsellor, admin will need to re-authenticate');
    
    // Note: Admin will be signed out and redirected to login
    // The admin dashboard should handle this gracefully
    
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

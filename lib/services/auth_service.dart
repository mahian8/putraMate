import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  String currentUserUid() => _auth.currentUser?.uid ?? '';

  Future<UserCredential> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      print('✓ Auth successful for: $email');

      // Fetch role for logging
      String? role;
      bool isActive = true;
      try {
        final doc =
            await _firestore.collection('users').doc(cred.user?.uid).get();
        print('✓ User doc fetched: exists=${doc.exists}');
        role = (doc.data()?['role'] as String?);
        isActive = (doc.data()?['isActive'] as bool?) ?? true;
        print('✓ Role fetched: $role');
        print('✓ isActive fetched: $isActive');

        // Block login for disabled accounts
        if (role == 'counsellor' && !isActive) {
          print('✗ Counsellor account disabled, blocking login');
          await _auth.signOut();
          throw 'This counsellor account has been disabled by admin.';
        }

        if (role == 'student' && !isActive) {
          print('✗ Student account disabled, blocking login');
          await _auth.signOut();
          throw 'This student account has been disabled by admin.';
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
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
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

  // ========== ADMIN CREATES COUNSELOR ==========
  // Domain & Role Assignment Policy:
  //   @admin.com  → System admin only (cannot be used elsewhere)
  //   @upm.com    → Counselor ONLY (admin creates with this domain)
  //   Personal    → Students ONLY (blocks @admin.com & @upm.com)
  //
  // Role Handling:
  //   - Role is EXPLICITLY set to 'counsellor' in Firestore
  //   - Role is verified after creation
  //   - Auto-corrected if mismatch detected
  //   - Students CANNOT register with @upm.com (validation in register_page.dart)
  //
  // Session Management:
  //   - Uses REST API (no session created)
  //   - Admin remains logged in throughout
  //   - Verified before, during, and after creation
  // =============================================
  Future<String> createCounsellorWithPassword({
    required String email,
    required String password,
    required String displayName,
    required String counsellorId,
    required String designation,
    required String expertise,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not signed in as admin';

    final adminEmail = currentUser.email;
    final adminUid = currentUser.uid;
    if (adminEmail == null) throw 'Admin email not found';

    // SECURITY CHECK: Enforce @upm.com domain for counselor accounts
    final emailLower = email.toLowerCase().trim();
    if (!emailLower.endsWith('@upm.com')) {
      print(
          '✗ SECURITY VIOLATION: Attempted to create counselor with non-@upm.com domain: $email');
      throw 'SECURITY ERROR: Counselor accounts MUST use @upm.com domain. This is a critical security requirement to prevent role confusion.';
    }

    print('→ Creating counsellor via REST API: $email');
    print('→ Email domain: ${email.split('@').last} ✓ VALID (@upm.com)');
    print('→ Role to assign: counsellor (EXPLICIT)');
    print('→ Admin session: $adminEmail (UID: $adminUid)');

    // Step 1: Create Firebase Auth user via REST API (no session created)
    // This method ensures admin remains logged in throughout the process
    final createUrl =
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=AIzaSyBp1H8RE4Qv8yTR1iREgH8eLqOmLS_WNqk';
    final createResponse = await http.post(
      Uri.parse(createUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        'returnSecureToken': false, // Don't create a session
      }),
    );

    if (createResponse.statusCode != 200) {
      final error = json.decode(createResponse.body);
      print('✗ REST API error: ${error['error']}');
      throw 'Failed to create counsellor account: ${error['error']['message']}';
    }

    final createData = json.decode(createResponse.body);
    final uid = createData['localId'] as String;
    print('✓ Counsellor auth account created via REST: $uid');

    // Step 2: Verify admin session is still intact
    await Future.delayed(const Duration(milliseconds: 100));
    final stillAdmin = _auth.currentUser;
    if (stillAdmin == null || stillAdmin.uid != adminUid) {
      print('⚠️ Admin session lost! Attempting to recover...');
      throw 'Error: Admin session was compromised. Please refresh and try again.';
    }
    print('✓ Admin session still intact: ${stillAdmin.email}');

    // Step 3: Create Firestore profile with EXPLICIT counsellor role
    // CRITICAL: The role MUST be 'counsellor' - this determines:
    //   - Which dashboard they access (counselor dashboard, not student)
    //   - What features/permissions they have
    //   - How they appear in the system
    // NOTE: Role is NOT inferred from email domain - it's explicitly set here
    final counsellorData = {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role':
          'counsellor', // ✓ EXPLICITLY AND DIRECTLY ASSIGNED TO 'counsellor'
      'counsellorId': counsellorId,
      'designation': designation,
      'expertise': expertise,
      'requirePasswordChange': true,
      'isActive': true,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    print('→ Creating Firestore profile with EXPLICIT role: counsellor');
    print('→ UID for new counsellor: $uid');
    print('→ Data being written: $counsellorData');

    await _firestore.collection('users').doc(uid).set(
          counsellorData,
          SetOptions(merge: false), // Completely overwrite, don't merge
        );
    print('✓ Firestore profile created');

    // CRITICAL: Add delay to ensure Firestore write is fully committed
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 4: Verify the role was set correctly
    print('→ Step 4: Verifying role was set correctly...');
    final verifyDoc = await _firestore.collection('users').doc(uid).get();
    if (!verifyDoc.exists) {
      print('✗ CRITICAL ERROR: Firestore document was not created!');
      throw 'Error: Firestore document was not created';
    }

    final verifyData = verifyDoc.data();
    final verifyRole = verifyData?['role'];
    print('✓ Document exists: true');
    print('✓ Full document data: $verifyData');
    print('✓ Role field value: $verifyRole');

    if (verifyRole != 'counsellor') {
      print('⚠️ CRITICAL SECURITY ISSUE: Role mismatch detected!');
      print('   Expected: counsellor');
      print('   Got: $verifyRole');
      print('   Attempting to correct...');
      // Try to fix it
      await _firestore
          .collection('users')
          .doc(uid)
          .update({'role': 'counsellor'});
      print('✓ Role corrected to counsellor');

      // Verify the correction
      await Future.delayed(const Duration(milliseconds: 300));
      final reVerifyDoc = await _firestore.collection('users').doc(uid).get();
      final reVerifyRole = reVerifyDoc.data()?['role'];
      print('✓ Re-verified role after correction: $reVerifyRole');

      if (reVerifyRole != 'counsellor') {
        print(
            '✗ CRITICAL: Unable to set counsellor role! This is a security violation!');
        throw 'CRITICAL ERROR: Unable to set counsellor role. Role is: $reVerifyRole';
      }
    } else {
      print('✓ Role verification PASSED: counsellor role is correctly set');
    }

    // Step 5: Final admin session check
    final finalAdmin = _auth.currentUser;
    if (finalAdmin?.uid != adminUid) {
      throw 'Error: Admin session was lost';
    }
    print('✓ Final check: Admin still logged in as ${finalAdmin?.email}');

    return uid;
  }

  // Admin: Create student with password (without changing admin session)
  Future<String> createStudentWithPassword({
    required String email,
    required String password,
    required String displayName,
    required String studentId,
    String? phoneNumber,
    String? dateOfBirth,
    String? gender,
    String? bloodType,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not signed in as admin';

    // Save admin's email to re-authenticate later
    final adminEmail = currentUser.email;
    if (adminEmail == null) throw 'Admin email not found';

    print('→ Creating student account for: $email');
    print('→ Current admin: $adminEmail');

    // Use Identity Toolkit REST API to create user without affecting SDK session
    final apiKey = 'AIzaSyBp1H8RE4Qv8yTR1iREgH8eLqOmLS_WNqk';
    final uri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken':
            false, // Don't return token to avoid session switching
      }),
    );

    if (resp.statusCode != 200) {
      print(
          '✗ Failed to create user via REST: ${resp.statusCode} ${resp.body}');
      throw 'Failed to create student: ${resp.body}';
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final uid = data['localId'] as String;
    print('✓ Auth account created via REST: $uid');

    // Check if admin session is still intact
    final currentAdmin = _auth.currentUser;
    print('→ Verifying admin session...');
    print('  Admin before: $adminEmail');
    print('  Current user: ${currentAdmin?.email ?? "null"}');

    // Create Firestore profile for student
    final studentData = {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': 'student',
      'studentId': studentId,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      if (gender != null) 'gender': gender,
      if (bloodType != null) 'bloodType': bloodType,
      'requirePasswordChange': true,
      'isActive': true,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    print('→ Creating Firestore profile with role: ${studentData['role']}');
    await _firestore.collection('users').doc(uid).set(
          studentData,
          SetOptions(merge: false), // Don't merge, completely overwrite
        );

    print('✓ Firestore profile created with role: student');

    // Verify the role was set correctly
    final verifyDoc = await _firestore.collection('users').doc(uid).get();
    final verifyRole = verifyDoc.data()?['role'];
    print('✓ Verified role in database: $verifyRole');

    // Final check that admin is still logged in
    final finalCheck = _auth.currentUser;
    print('→ Final session check:');
    print('  Current user: ${finalCheck?.email ?? "null"}');
    print('  Is admin still logged in: ${finalCheck?.email == adminEmail}');

    if (finalCheck?.email != adminEmail) {
      print('⚠️ WARNING: Admin session was compromised!');
      throw 'Session error: Admin was logged out during account creation. Please try again.';
    }

    // Keep admin session intact; do NOT sign out
    return uid;
  }

  // Admin: Delete user completely (Auth + Firestore)
  Future<void> deleteUser(String uid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not signed in as admin';

    print('→ Deleting user: $uid');

    try {
      // Delete Firestore profile first
      await _firestore.collection('users').doc(uid).delete();
      print('✓ Firestore profile deleted');

      // Delete from Firebase Auth using Admin REST API
      final apiKey = 'AIzaSyBp1H8RE4Qv8yTR1iREgH8eLqOmLS_WNqk';
      final idToken = await currentUser.getIdToken();

      final uri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$apiKey');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'localId': uid,
        }),
      );

      if (resp.statusCode == 200) {
        print('✓ Auth account deleted');
      } else {
        print(
            '⚠ Auth deletion failed but continuing: ${resp.statusCode} ${resp.body}');
        // Don't throw error - Firestore deletion is more important
      }
    } catch (e) {
      print('✗ Error deleting user: $e');
      rethrow;
    }
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

  // Reset password without current password (for forgot password flow)
  Future<void> resetPasswordWithVerification({
    required String email,
    required String newPassword,
  }) async {
    try {
      // Get user by email to get their UID
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isEmpty) {
        throw 'No user found with this email address.';
      }

      // We need to use Firebase Admin REST API to update password without knowing current password
      // For now, we'll use the password reset email method as a fallback
      // In production, you should implement this using Firebase Admin SDK on backend

      // Alternative: Create a custom token and sign in to update password
      // This requires Firebase Admin SDK running on a backend server

      throw 'Password reset not fully implemented. Please use email reset link.';
    } catch (e) {
      print('Error in resetPasswordWithVerification: $e');
      rethrow;
    }
  }
}

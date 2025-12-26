import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';
import '../models/forum_post.dart';
import '../models/journal_entry.dart';
import '../models/message.dart';
import '../models/mood_entry.dart';
import '../models/user_profile.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Mood tracking
  Stream<List<MoodEntry>> moodEntries(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('moods')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MoodEntry.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<void> addMoodEntry(MoodEntry entry) {
    return _firestore
        .collection('users')
        .doc(entry.userId)
        .collection('moods')
        .add(entry.toJson());
  }

  Stream<List<JournalEntry>> journalEntries(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('journals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => JournalEntry.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<void> addJournalEntry(JournalEntry entry) {
    return _firestore
        .collection('users')
        .doc(entry.userId)
        .collection('journals')
        .add(entry.toJson());
  }

  Stream<List<Appointment>> appointmentsForUser(String userId) {
    return _firestore
        .collection('appointments')
        .where('participants', arrayContains: userId)
        .orderBy('start', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Appointment.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Appointment>> appointmentsForCounsellor(String counsellorId) {
    return _firestore
        .collection('appointments')
        .where('counsellorId', isEqualTo: counsellorId)
        .orderBy('start')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Appointment.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Appointment>> appointmentsForStudent(String studentId) {
    return _firestore
        .collection('appointments')
        .where('studentId', isEqualTo: studentId)
        .orderBy('start', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Appointment.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<void> upsertAppointment(Appointment appointment) {
    return _firestore.collection('appointments').doc(appointment.id).set({
      ...appointment.toJson(),
      'participants': [appointment.studentId, appointment.counsellorId],
    }, SetOptions(merge: true));
  }

  Future<String> createAppointment({
    required String studentId,
    required String counsellorId,
    required DateTime start,
    required DateTime end,
    String? topic,
    String? notes,
    String? sentiment,
    String? riskLevel,
    SessionType? sessionType,
    String? initialProblem,
  }) async {
    final docRef = _firestore.collection('appointments').doc();

    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    // Check if counsellor is on leave during this time (single-range query, filter in memory)
    final leaveQuery = await _firestore
        .collection('leaves')
        .where('userId', isEqualTo: counsellorId)
        .where('startDate', isLessThanOrEqualTo: endMs)
        .get();

    final onLeave = leaveQuery.docs.any((doc) {
      final data = doc.data();
      final leaveEnd = (data['endDate'] as num?)?.toInt() ?? 0;
      return leaveEnd >= startMs;
    });

    if (onLeave) {
      throw 'Counsellor is on leave during this time. Please choose another date or counsellor.';
    }

    // Detect duplicates/overlaps for counsellor or student during same window (single-range query, filter in memory)
    final conflictQuery = await _firestore
        .collection('appointments')
        .where('counsellorId', isEqualTo: counsellorId)
        .where('start', isLessThan: endMs)
        .get();

    final hasCounsellorConflict = conflictQuery.docs.any((doc) {
      final data = doc.data();
      final apptEnd = (data['end'] as num?)?.toInt() ?? 0;
      return apptEnd > startMs;
    });

    final studentConflictQuery = await _firestore
        .collection('appointments')
        .where('studentId', isEqualTo: studentId)
        .where('start', isLessThan: endMs)
        .get();

    final hasStudentConflict = studentConflictQuery.docs.any((doc) {
      final data = doc.data();
      final apptEnd = (data['end'] as num?)?.toInt() ?? 0;
      return apptEnd > startMs;
    });

    final isDuplicate = hasCounsellorConflict || hasStudentConflict;

    final appointment = Appointment(
      id: docRef.id,
      studentId: studentId,
      counsellorId: counsellorId,
      start: start,
      end: end,
      status: AppointmentStatus.pending,
      topic: topic,
      notes: notes,
      sentiment: sentiment,
      riskLevel: riskLevel,
      isDuplicate: isDuplicate,
      createdAt: DateTime.now(),
      sessionType: sessionType,
      initialProblem: initialProblem,
    );

    await upsertAppointment(appointment);
    return docRef.id;
  }

  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required AppointmentStatus status,
    String? counsellorNotes,
    String? followUpPlan,
    String? meetLink,
  }) async {
    await _firestore.collection('appointments').doc(appointmentId).set({
      'status': status.name,
      if (counsellorNotes != null) 'counsellorNotes': counsellorNotes,
      if (followUpPlan != null) 'followUpPlan': followUpPlan,
      if (meetLink != null) 'meetLink': meetLink,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));

    // If session completed, send review notifications
    if (status == AppointmentStatus.completed) {
      final appt =
          await _firestore.collection('appointments').doc(appointmentId).get();
      if (appt.exists) {
        final data = appt.data()!;
        final studentId = data['studentId'] as String;
        final counsellorId = data['counsellorId'] as String;

        // Notify student to review counsellor
        await _firestore
            .collection('users')
            .doc(studentId)
            .collection('notifications')
            .add({
          'title': 'Session Completed',
          'message': 'Please review your session and rate your counsellor',
          'appointmentId': appointmentId,
          'type': 'review_counsellor',
          'read': false,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        // Notify counsellor to comment on progress
        await _firestore
            .collection('users')
            .doc(counsellorId)
            .collection('notifications')
            .add({
          'title': 'Session Completed',
          'message': 'Please add progress notes for the student',
          'appointmentId': appointmentId,
          'type': 'add_progress_notes',
          'read': false,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
  }

  Future<void> submitRating({
    required String appointmentId,
    required int rating,
    String? comment,
  }) {
    return _firestore.collection('appointments').doc(appointmentId).set({
      'studentRating': rating,
      if (comment != null) 'studentComment': comment,
      'status': AppointmentStatus.completed.name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  Stream<List<Appointment>> duplicateAppointments() {
    return _firestore
        .collection('appointments')
        .where('isDuplicate', isEqualTo: true)
        .orderBy('start')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Appointment.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<List<UserProfile>> counsellors() {
    print('→ Fetching counsellors list...');
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.counsellor.name)
        .snapshots()
        .map((snap) {
      print('✓ Counsellors query returned ${snap.docs.length} documents');
      return snap.docs.map((doc) {
        print('  - Counsellor: ${doc.data()['displayName']} (${doc.id})');
        return UserProfile.fromJson(doc.data());
      }).toList();
    });
  }

  Future<void> deleteUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).delete();
  }

  // Admin: Get all students
  Stream<List<UserProfile>> allStudents() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.student.name)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => UserProfile.fromJson(doc.data())).toList());
  }

  // Admin: Get all appointments
  Stream<List<Appointment>> allAppointments() {
    return _firestore
        .collection('appointments')
        .orderBy('start', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Appointment.fromJson(doc.data(), doc.id))
            .toList());
  }

  // Admin: Reassign appointment to different counsellor
  Future<void> reassignAppointment(
      String appointmentId, String newCounsellorId) {
    return _firestore.collection('appointments').doc(appointmentId).update({
      'counsellorId': newCounsellorId,
      'participants': FieldValue.arrayUnion([newCounsellorId]),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Admin: Update appointment date/time
  Future<void> rescheduleAppointment(
      String appointmentId, DateTime newStart, DateTime newEnd) {
    return _firestore.collection('appointments').doc(appointmentId).update({
      'start': newStart.millisecondsSinceEpoch,
      'end': newEnd.millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Admin: Delete appointment
  Future<void> deleteAppointment(String appointmentId) {
    return _firestore.collection('appointments').doc(appointmentId).delete();
  }

  // Leave management
  Future<void> addLeave({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required String leaveType, // 'medical', 'personal', etc.
  }) {
    return _firestore.collection('leaves').add({
      'userId': userId,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'reason': reason,
      'leaveType': leaveType,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Stream<List<Map<String, dynamic>>> userLeaves(String userId) {
    return _firestore
        .collection('leaves')
        .where('userId', isEqualTo: userId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> deleteLeave(String leaveId) {
    return _firestore.collection('leaves').doc(leaveId).delete();
  }

  Stream<List<ForumPost>> communityPosts() {
    return _firestore
        .collection('forum')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ForumPost.fromJson(doc.data(), doc.id))
            .toList());
  }

  // Notifications
  Stream<List<Map<String, dynamic>>> notifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final batch = _firestore.batch();
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
  }

  Future<void> addForumPost(ForumPost post) {
    return _firestore.collection('forum').add(post.toJson());
  }

  Future<void> likeForumPost(String postId, String userId) async {
    final docRef = _firestore.collection('forum').doc(postId);
    return docRef.update({
      'likes': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> unlikeForumPost(String postId, String userId) async {
    final docRef = _firestore.collection('forum').doc(postId);
    return docRef.update({
      'likes': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> addForumComment({
    required String postId,
    required String userId,
    required String userName,
    required String content,
  }) async {
    final commentRef =
        _firestore.collection('forum').doc(postId).collection('comments').doc();

    await commentRef.set({
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Increment comment count on post
    await _firestore.collection('forum').doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  Stream<List<Map<String, dynamic>>> forumComments(String postId) {
    return _firestore
        .collection('forum')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Stream<List<ChatMessage>> chatMessages(String threadId) {
    return _firestore
        .collection('chats')
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatMessage.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<void> sendMessage(String threadId, ChatMessage message) {
    return _firestore
        .collection('chats')
        .doc(threadId)
        .collection('messages')
        .add(message.toJson());
  }

  Future<void> addLoginEvent({
    required String uid,
    required String email,
    String? role,
  }) {
    return _firestore.collection('loginEvents').add({
      'uid': uid,
      'email': email,
      if (role != null) 'role': role,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Chat history
  Stream<List<Map<String, dynamic>>> chatHistory(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('chatHistory')
        .orderBy('timestamp', descending: false)
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Future<void> saveChatMessage({
    required String userId,
    required String sender,
    required String text,
    Map<String, dynamic>? sentiment,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('chatHistory')
        .add({
      'sender': sender,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      if (sentiment != null) 'sentiment': sentiment,
    });
  }

  // Flag high-risk students for counsellor review
  Future<void> flagHighRiskStudent({
    required String studentId,
    required String studentName,
    required String riskLevel,
    required String sentiment,
    required String message,
  }) {
    return _firestore.collection('highRiskFlags').add({
      'studentId': studentId,
      'studentName': studentName,
      'riskLevel': riskLevel,
      'sentiment': sentiment,
      'lastMessage': message,
      'flaggedAt': DateTime.now().millisecondsSinceEpoch,
      'resolved': false,
    });
  }

  // Get high-risk flags for counsellors to review
  Stream<List<Map<String, dynamic>>> highRiskStudents(String counsellorId) {
    return _firestore
        .collection('highRiskFlags')
        .where('resolved', isEqualTo: false)
        .orderBy('flaggedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  // Mark flag as resolved
  Future<void> resolveHighRiskFlag(String flagId) {
    return _firestore.collection('highRiskFlags').doc(flagId).update({
      'resolved': true,
      'resolvedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Get high-risk flags for a specific student
  Stream<List<Map<String, dynamic>>> highRiskFlags(String studentId) {
    return _firestore
        .collection('highRiskFlags')
        .where('studentId', isEqualTo: studentId)
        .orderBy('flaggedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  // Get students assigned to a specific counsellor
  Stream<List<UserProfile>> assignedStudents(String counsellorId) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('counsellorId', isEqualTo: counsellorId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserProfile.fromJson({...doc.data(), 'uid': doc.id}))
            .toList());
  }

  // Check if a time slot is available for a counsellor (before booking)
  Future<List<String>> checkAvailability({
    required String counsellorId,
    required DateTime start,
    required DateTime end,
  }) async {
    final conflicts = <String>[];

    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    // Check for leave conflicts (single-range query, filter endDate in memory)
    final leaveQuery = await _firestore
        .collection('leaves')
        .where('userId', isEqualTo: counsellorId)
        .where('startDate', isLessThanOrEqualTo: endMs)
        .get();

    final onLeave = leaveQuery.docs.any((doc) {
      final data = doc.data();
      final leaveEnd = (data['endDate'] as num?)?.toInt() ?? 0;
      return leaveEnd >= startMs;
    });

    if (onLeave) {
      conflicts.add('Counsellor is on leave during this time.');
    }

    // Check for appointment conflicts (single-range query, filter end in memory)
    final appointmentQuery = await _firestore
        .collection('appointments')
        .where('counsellorId', isEqualTo: counsellorId)
        .where('start', isLessThan: endMs)
        .get();

    final hasConflict = appointmentQuery.docs.any((doc) {
      final data = doc.data();
      final apptEnd = (data['end'] as num?)?.toInt() ?? 0;
      return apptEnd > startMs;
    });

    if (hasConflict) {
      conflicts.add('Counsellor already has an appointment at this time.');
    }

    return conflicts;
  }

  // Update user profile
  Future<void> updateUserProfile(
      {required String uid, required Map<String, dynamic> data}) {
    return _firestore.collection('users').doc(uid).update(data);
  }

  // Get user profile stream
  Stream<UserProfile?> userProfile(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromJson({...snap.data()!, 'uid': snap.id});
    });
  }
}

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
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => Appointment.fromJson(doc.data(), doc.id))
              .toList();
          // Sort by start time descending to mimic previous orderBy without requiring an index
          list.sort((a, b) => b.start.compareTo(a.start));
          return list;
        });
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

  // Fetch all completed appointments with reviews for a counsellor (visible to all students)
  Stream<List<Appointment>> counsellorReviews(String counsellorId) {
    return _firestore
        .collection('appointments')
        .where('counsellorId', isEqualTo: counsellorId)
        .orderBy('start', descending: true)
        .snapshots()
        .map((snap) {
          final appts = snap.docs
              .map((doc) => Appointment.fromJson(doc.data(), doc.id))
              .where((a) => (a.studentRating != null && a.studentRating! > 0) ||
                            (a.studentComment != null))
              .toList();

          // Debug: log what we received to help trace visibility
          try {
            print('✓ counsellorReviews for $counsellorId: ${appts.length} items');
            for (final a in appts) {
              print('  - appt ${a.id} student=${a.studentId} rating=${a.studentRating} commentExists=${a.studentComment != null}');
            }
          } catch (_) {}

          return appts;
        });
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

  // Counsellor view of a single student's sessions (security-friendly: counsellorId filter)
  Stream<List<Appointment>> appointmentsForStudentAndCounsellor(
      {required String studentId, required String counsellorId}) {
    return _firestore
        .collection('appointments')
        .where('studentId', isEqualTo: studentId)
        .where('counsellorId', isEqualTo: counsellorId)
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

    // Check if counsellor is on leave during this time (equality query, filter window in memory)
    final leaveQuery = await _firestore
        .collection('leaves')
        .where('userId', isEqualTo: counsellorId)
        .get();

    final onLeave = leaveQuery.docs.any((doc) {
      final data = doc.data();
      final leaveStart = (data['startDate'] as num?)?.toInt() ?? 0;
      final leaveEnd = (data['endDate'] as num?)?.toInt() ?? 0;
      return leaveStart <= endMs && leaveEnd >= startMs;
    });

    if (onLeave) {
      throw 'Counsellor is on leave during this time. Please choose another date or counsellor.';
    }

    // Detect duplicates/overlaps for counsellor or student during same window (equality query, filter window in memory)
    final conflictQuery = await _firestore
        .collection('appointments')
        .where('counsellorId', isEqualTo: counsellorId)
        .get();

    final hasCounsellorConflict = conflictQuery.docs.any((doc) {
      final data = doc.data();
      final apptStart = (data['start'] as num?)?.toInt() ?? 0;
      final apptEnd = (data['end'] as num?)?.toInt() ?? 0;
      return apptStart < endMs && apptEnd > startMs;
    });

    final studentConflictQuery = await _firestore
        .collection('appointments')
        .where('studentId', isEqualTo: studentId)
        .get();

    final hasStudentConflict = studentConflictQuery.docs.any((doc) {
      final data = doc.data();
      final apptStart = (data['start'] as num?)?.toInt() ?? 0;
      final apptEnd = (data['end'] as num?)?.toInt() ?? 0;
      return apptStart < endMs && apptEnd > startMs;
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

    // Ensure student profile reflects counsellor assignment for visibility
    try {
      await _firestore.collection('users').doc(studentId).set({
        'counsellorId': counsellorId,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-blocking: ignore any profile write failure
    }
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

    // Fetch appointment to notify parties
    final apptSnap = await _firestore.collection('appointments').doc(appointmentId).get();
    final data = apptSnap.data() ?? {};
    final studentId = data['studentId'] as String?;
    final counsellorId = data['counsellorId'] as String?;
    // Read start time if needed for future flows

    // Notify on confirmation
    if (status == AppointmentStatus.confirmed && studentId != null) {
      await _firestore
          .collection('users')
          .doc(studentId)
          .collection('notifications')
          .add({
        'title': 'Appointment Confirmed',
        'message': 'Your session has been confirmed.',
        'appointmentId': appointmentId,
        'type': 'appointment_confirmed',
        'read': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // If session completed, send review notifications
    if (status == AppointmentStatus.completed) {
      if (studentId != null && counsellorId != null) {

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
              'createdAt': DateTime.now().millisecondsSinceEpoch,
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
              'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
  }

  /// Send a reminder notification to the student 5 minutes before start time.
  /// Marks `studentReminderSent: true` on the appointment to avoid duplicates.
  Future<void> sendUpcomingReminderIfDue(String userId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fiveMinMs = 5 * 60 * 1000;
    final snap = await _firestore
        .collection('appointments')
        .where('participants', arrayContains: userId)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final start = (data['start'] as num?)?.toInt();
      final studentId = data['studentId'] as String?;
      final reminderSent = data['studentReminderSent'] as bool? ?? false;
      final statusStr = data['status'] as String? ?? 'pending';
      if (start == null || studentId == null) continue;
      final isConfirmed = statusStr == AppointmentStatus.confirmed.name || statusStr == AppointmentStatus.pending.name;
      final timeToStart = start - now;
      if (!reminderSent && isConfirmed && timeToStart > 0 && timeToStart <= fiveMinMs && studentId == userId) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
          'title': 'Upcoming Session',
          'message': 'Your session starts in 5 minutes.',
          'appointmentId': doc.id,
          'type': 'appointment_reminder',
          'read': false,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
        await doc.reference.update({'studentReminderSent': true});
      }
    }
  }

  /// Auto-complete sessions 30 minutes after end time for the given user.
  /// This runs client-side and respects security rules (only updates sessions
  /// where the current user is student or counsellor).
  Future<void> autoCompleteExpiredSessionsForUser(String userId,
      {Duration grace = const Duration(minutes: 30)}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final graceMs = grace.inMilliseconds;
    final snap = await _firestore
        .collection('appointments')
        .where('participants', arrayContains: userId)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final statusStr = data['status'] as String? ?? 'pending';
      final endMs = (data['end'] as num?)?.toInt() ?? 0;
      if (endMs <= 0) continue;

      final isActive = statusStr == AppointmentStatus.confirmed.name ||
          statusStr == AppointmentStatus.pending.name;
      final pastWithGrace = now >= (endMs + graceMs);

      if (isActive && pastWithGrace) {
        await updateAppointmentStatus(
          appointmentId: doc.id,
          status: AppointmentStatus.completed,
        );
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

  // Reviews moderation
  Stream<List<Appointment>> pendingReviews() {
    return _firestore
        .collection('appointments')
        .where('isReviewApproved', isEqualTo: false)
        .orderBy('start', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Appointment.fromJson(doc.data(), doc.id))
            .where((a) => a.studentRating != null ||
                (a.studentComment != null && a.studentComment!.isNotEmpty))
            .toList());
  }

  Future<void> approveReview(String appointmentId) {
    return _firestore
        .collection('appointments')
        .doc(appointmentId)
        .update({'isReviewApproved': true, 'updatedAt': DateTime.now().millisecondsSinceEpoch});
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

  // Alternative: derive assigned students from appointments for reliability
  Stream<List<UserProfile>> assignedStudentsFromAppointments(
      String counsellorId) {
    return _firestore
        .collection('appointments')
        .where('counsellorId', isEqualTo: counsellorId)
        .snapshots()
        .asyncMap((snap) async {
      final ids = snap.docs
          .map((d) => (d.data()['studentId'] as String?))
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();
      final profiles = <UserProfile>[];
      for (final id in ids) {
        final doc = await _firestore.collection('users').doc(id!).get();
        if (doc.exists) {
          profiles.add(UserProfile.fromJson({...doc.data()!, 'uid': doc.id}));
        }
      }
      return profiles;
    });
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

    // Check for leave conflicts (equality query, filter window in memory)
    final leaveQuery = await _firestore
        .collection('leaves')
        .where('userId', isEqualTo: counsellorId)
        .get();

    final onLeave = leaveQuery.docs.any((doc) {
      final data = doc.data();
      final leaveStart = (data['startDate'] as num?)?.toInt() ?? 0;
      final leaveEnd = (data['endDate'] as num?)?.toInt() ?? 0;
      return leaveStart <= endMs && leaveEnd >= startMs;
    });

    if (onLeave) {
      conflicts.add('Counsellor is on leave during this time.');
    }

    // Check for appointment conflicts (equality query, filter window in memory)
    final appointmentQuery = await _firestore
        .collection('appointments')
        .where('counsellorId', isEqualTo: counsellorId)
        .get();

    final hasConflict = appointmentQuery.docs.any((doc) {
      final data = doc.data();
      final apptStart = (data['start'] as num?)?.toInt() ?? 0;
      final apptEnd = (data['end'] as num?)?.toInt() ?? 0;
      return apptStart < endMs && apptEnd > startMs;
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

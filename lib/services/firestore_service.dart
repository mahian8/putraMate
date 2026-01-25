import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../models/forum_post.dart';
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

  /// Get recent mood entries for Gemini context (last 7 days)
  Future<List<MoodEntry>> getRecentMoodEntries(String userId) async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('moods')
        .where('timestamp', isGreaterThan: sevenDaysAgo.millisecondsSinceEpoch)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();
    return snapshot.docs
        .map((doc) => MoodEntry.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<void> addMoodEntry(MoodEntry entry) {
    return _firestore
        .collection('users')
        .doc(entry.userId)
        .collection('moods')
        .add(entry.toJson());
  }

  /// Get counselors whose expertise matches problem keywords
  Future<List<UserProfile>> getCounselorsByExpertise(
      List<String> keywords) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'counsellor')
        .where('isActive', isEqualTo: true)
        .get();

    final counselors =
        snapshot.docs.map((doc) => UserProfile.fromJson(doc.data())).toList();

    // Filter and score by expertise match
    final scored = counselors
        .map((c) {
          final expertise = c.expertise?.toLowerCase() ?? '';
          var score = 0;
          for (final keyword in keywords) {
            if (expertise.contains(keyword.toLowerCase())) {
              score++;
            }
          }
          return {'counselor': c, 'score': score};
        })
        .where((item) => item['score'] as int > 0)
        .toList();

    // Sort by score descending
    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    return scored.map((item) => item['counselor'] as UserProfile).toList();
  }

  /// Get available time slots for a counselor (next N days, excluding weekends)
  Future<List<DateTime>> getCounselorAvailableSlots(String counselorId,
      {int days = 7}) async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final windowEnd = now.add(Duration(days: days));
    final windowEndMs = windowEnd.millisecondsSinceEpoch;
    const maxSlots = 12; // stop early once we have enough slots to show
    final slots = <DateTime>[];

    // Check appointments and leaves for this counselor (only upcoming window)
    final appointmentsQuery = _firestore
        .collection('appointments')
        .where('counsellorId', isEqualTo: counselorId)
        .where('start', isGreaterThan: nowMs)
        .where('start', isLessThanOrEqualTo: windowEndMs)
        .orderBy('start');

    final leavesQuery = _firestore
        .collection('leaves')
        .where('userId', isEqualTo: counselorId)
        .where('endDate', isGreaterThan: nowMs);

    final results = await Future.wait([
      appointmentsQuery.get(),
      leavesQuery.get(),
    ]);

    final appointmentsSnapshot = results[0];
    final leavesSnapshot = results[1];

    // Parse bookings and leaves
    final bookedTimes = appointmentsSnapshot.docs.where((doc) {
      final status = doc['status'] as String?;
      // Exclude cancelled appointments - they're available again
      return status != 'cancelled';
    }).map((doc) {
      final data = doc.data();
      return {
        'start': (data['start'] as num?)?.toInt() ?? 0,
        'end': (data['end'] as num?)?.toInt() ?? 0,
      };
    }).toList();

    final leavePeriods = leavesSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'start': (data['startDate'] as num?)?.toInt() ?? 0,
        'end': (data['endDate'] as num?)?.toInt() ?? 0,
      };
    }).toList();

    // Generate slots for next N days, excluding weekends, and stop early when enough found
    DateTime current =
        DateTime(now.year, now.month, now.day, 9, 0); // Start at 9 AM
    final endDate = windowEnd;

    while (current.isBefore(endDate) && slots.length < maxSlots) {
      // Skip weekends (Saturday=6, Sunday=7)
      if (current.weekday != 6 && current.weekday != 7) {
        // Generate 45-minute slots from 9 AM to 5 PM
        if (current.hour < 17) {
          final slotStart = current.millisecondsSinceEpoch;
          final slotEnd =
              current.add(const Duration(minutes: 45)).millisecondsSinceEpoch;

          // Check if slot is available (not booked and not on leave)
          final isBooked = bookedTimes.any((booking) =>
              booking['start']! < slotEnd && booking['end']! > slotStart);

          final isOnLeave = leavePeriods.any((leave) =>
              leave['start']! <= slotStart && leave['end']! >= slotEnd);

          if (!isBooked &&
              !isOnLeave &&
              current.isAfter(now.add(Duration(hours: 1)))) {
            slots.add(current);
          }

          current = current.add(const Duration(minutes: 45));
        } else {
          current =
              DateTime(current.year, current.month, current.day + 1, 9, 0);
        }
      } else {
        current = current.add(const Duration(days: 1));
        current = DateTime(current.year, current.month, current.day, 9, 0);
      }
    }

    return slots;
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
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => Appointment.fromJson(doc.data(), doc.id))
          .where((a) => a.status != AppointmentStatus.cancelled)
          .toList();
      // Sort by start time in code instead of Firestore (avoids index requirement)
      list.sort((a, b) => a.start.compareTo(b.start));
      return list;
    });
  }

  Future<List<Appointment>> appointmentsForCounsellorOnce(
      String counsellorId) async {
    final snap = await _firestore
        .collection('appointments')
        .where('counsellorId', isEqualTo: counsellorId)
        .get();
    return snap.docs
        .map((doc) => Appointment.fromJson(doc.data(), doc.id))
        .where((a) => a.status != AppointmentStatus.cancelled)
        .toList();
  }

  Future<List<Appointment>> counsellorAppointmentsOverlapping({
    required String counsellorId,
    required DateTime start,
    required DateTime end,
  }) async {
    final appts = await appointmentsForCounsellorOnce(counsellorId);
    return appts
        .where((a) => a.end.isAfter(start) && a.start.isBefore(end))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  // Fetch all completed appointments with reviews for a counsellor (visible to all students)
  // Uses allAppointments to bypass any participant filtering and ensure universal visibility
  Stream<List<Appointment>> counsellorReviews(String counsellorId) {
    return _firestore
        .collection('appointments')
        .where('counsellorId', isEqualTo: counsellorId)
        .snapshots()
        .map((snap) {
      final appts = snap.docs
          .map((doc) => Appointment.fromJson(doc.data(), doc.id))
          .where((a) =>
              (a.studentRating != null && a.studentRating! > 0) ||
              (a.studentComment != null && a.studentComment!.isNotEmpty))
          .toList();

      // Sort by most recent first
      appts.sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(2000))
          .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(2000)));

      // Debug: log what we received to help trace visibility
      try {
        print('✓ counsellorReviews for $counsellorId: ${appts.length} items');
        for (final a in appts) {
          print(
              '  - appt ${a.id} student=${a.studentId} rating=${a.studentRating} status=${a.status.name}');
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

  // Fetch a single appointment by id
  Stream<Appointment?> appointmentById(String appointmentId) {
    return _firestore
        .collection('appointments')
        .doc(appointmentId)
        .snapshots()
        .map((doc) =>
            doc.exists ? Appointment.fromJson(doc.data()!, doc.id) : null);
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

    // Block booking if counsellor account is inactive
    final counsellorDoc =
        await _firestore.collection('users').doc(counsellorId).get();
    final counsellorData = counsellorDoc.data() ?? {};
    final counsellorActive = counsellorData['isActive'] as bool? ?? true;
    if (!counsellorActive) {
      throw 'Counsellor account is inactive. Please choose another counsellor.';
    }

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

    // Flag high-risk student to counsellor NOW that they've booked
    if ((riskLevel == 'high' || riskLevel == 'critical') && sentiment != null) {
      try {
        final studentDoc =
            await _firestore.collection('users').doc(studentId).get();
        final studentData = studentDoc.data() ?? {};
        final studentName = studentData['displayName'] as String? ?? 'Student';

        await flagHighRiskStudent(
          studentId: studentId,
          studentName: studentName,
          riskLevel: riskLevel!,
          sentiment: sentiment,
          message:
              initialProblem ?? 'High-risk sentiment detected during booking',
        );
      } catch (_) {
        // Non-blocking: ignore flagging failure
      }
    }

    // Also flag if mood pattern was critical
    if (riskLevel == null &&
        initialProblem != null &&
        initialProblem.contains('mood')) {
      try {
        final moodEntries = await getRecentMoodEntries(studentId);
        if (moodEntries.isNotEmpty) {
          final moodMap = moodEntries
              .map((m) => {
                    'moodScore': m.moodScore,
                    'note': m.note,
                    'timestamp': m.timestamp.millisecondsSinceEpoch,
                  })
              .toList();

          if (moodMap.isNotEmpty) {
            final scores =
                moodMap.map((m) => m['moodScore'] as int? ?? 5).toList();
            final avgScore = scores.reduce((a, b) => a + b) / scores.length;
            if (avgScore <= 3) {
              final studentDoc =
                  await _firestore.collection('users').doc(studentId).get();
              final studentData = studentDoc.data() ?? {};
              final studentName =
                  studentData['displayName'] as String? ?? 'Student';

              await flagHighRiskStudent(
                studentId: studentId,
                studentName: studentName,
                riskLevel: 'high',
                sentiment: 'concerning',
                message:
                    'Critical mood pattern detected: Multiple low mood entries this week',
              );
            }
          }
        }
      } catch (_) {
        // Non-blocking
      }
    }

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
    final apptSnap =
        await _firestore.collection('appointments').doc(appointmentId).get();
    final data = apptSnap.data() ?? {};
    final studentId = data['studentId'] as String?;
    final counsellorId = data['counsellorId'] as String?;
    // Read start time if needed for future flows

    // Notify on confirmation
    if (status == AppointmentStatus.confirmed && studentId != null) {
      String message = 'Your session has been confirmed.';
      if (meetLink != null && meetLink.isNotEmpty) {
        message += ' Meet link: $meetLink';
      }
      await _firestore
          .collection('users')
          .doc(studentId)
          .collection('notifications')
          .add({
        'title': 'Appointment Confirmed',
        'message': message,
        'appointmentId': appointmentId,
        'type': 'appointment_confirmed',
        'read': false,
        'meetLink': meetLink,
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

  /// Update appointment with location field (for face-to-face sessions)
  Future<void> updateAppointmentWithLocation({
    required String appointmentId,
    required AppointmentStatus status,
    String? counsellorNotes,
    String? followUpPlan,
    String? meetLink,
    String? location,
  }) async {
    await _firestore.collection('appointments').doc(appointmentId).set({
      'status': status.name,
      if (counsellorNotes != null) 'counsellorNotes': counsellorNotes,
      if (followUpPlan != null) 'followUpPlan': followUpPlan,
      if (meetLink != null) 'meetLink': meetLink,
      if (location != null) 'location': location,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));

    // If location provided and pending, send notification
    final apptSnap =
        await _firestore.collection('appointments').doc(appointmentId).get();
    final data = apptSnap.data() ?? {};
    final studentId = data['studentId'] as String?;

    if (location != null && location.isNotEmpty && studentId != null) {
      await _firestore
          .collection('users')
          .doc(studentId)
          .collection('notifications')
          .add({
        'title': 'Meeting Location Added',
        'message':
            'Your counsellor has provided the meeting location: $location',
        'appointmentId': appointmentId,
        'type': 'location_added',
        'read': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Submit reschedule request for admin review
  Future<void> submitRescheduleRequest({
    required String appointmentId,
    required String counsellorId,
    required String studentId,
    required DateTime oldStart,
    required DateTime newStart,
    required DateTime newEnd,
    required String reason,
  }) async {
    // Create reschedule request document
    await _firestore.collection('reschedule_requests').add({
      'appointmentId': appointmentId,
      'counsellorId': counsellorId,
      'studentId': studentId,
      'oldStart': oldStart.millisecondsSinceEpoch,
      'newStart': newStart.millisecondsSinceEpoch,
      'newEnd': newEnd.millisecondsSinceEpoch,
      'reason': reason,
      'status': 'pending', // pending, approved, rejected
      'requestedAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Notify student
    await _firestore
        .collection('users')
        .doc(studentId)
        .collection('notifications')
        .add({
      'title': 'Reschedule Request',
      'message':
          'Your counsellor has requested to reschedule your appointment. Awaiting admin approval.',
      'appointmentId': appointmentId,
      'type': 'reschedule_requested',
      'read': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Notify admin (find all admin users)
    final admins = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    for (final admin in admins.docs) {
      await _firestore
          .collection('users')
          .doc(admin.id)
          .collection('notifications')
          .add({
        'title': 'Reschedule Request Pending',
        'message':
            'A counsellor has requested to reschedule an appointment. Reason: $reason',
        'appointmentId': appointmentId,
        'type': 'reschedule_review',
        'read': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
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
      final isConfirmed = statusStr == AppointmentStatus.confirmed.name ||
          statusStr == AppointmentStatus.pending.name;
      final timeToStart = start - now;
      if (!reminderSent &&
          isConfirmed &&
          timeToStart > 0 &&
          timeToStart <= fiveMinMs &&
          studentId == userId) {
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
      'isReviewApproved': true,
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
            .where((a) =>
                a.studentRating != null ||
                (a.studentComment != null && a.studentComment!.isNotEmpty))
            .toList());
  }

  Future<void> approveReview(String appointmentId) {
    return _firestore.collection('appointments').doc(appointmentId).update({
      'isReviewApproved': true,
      'updatedAt': DateTime.now().millisecondsSinceEpoch
    });
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
  /// Submit a leave request (pending approval)
  Future<void> submitLeaveRequest({
    required String userId,
    required String counsellorName,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required String leaveType,
  }) async {
    await _firestore.collection('leave_requests').add({
      'userId': userId,
      'counsellorName': counsellorName,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'reason': reason,
      'leaveType': leaveType,
      'status': 'pending',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Notify all admins
    final admins = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    for (final admin in admins.docs) {
      await _firestore
          .collection('users')
          .doc(admin.id)
          .collection('notifications')
          .add({
        'title': 'New Leave Request',
        'message':
            '$counsellorName has requested leave from ${DateFormat('MMM d').format(startDate)} to ${DateFormat('MMM d').format(endDate)}',
        'type': 'leave_request',
        'read': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Get all pending leave requests
  Stream<List<Map<String, dynamic>>> pendingLeaveRequests() {
    return _firestore
        .collection('leave_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Process leave request (approve or decline)
  Future<void> processLeaveRequest(String requestId, bool approved) async {
    final requestDoc =
        await _firestore.collection('leave_requests').doc(requestId).get();
    if (!requestDoc.exists) return;

    final data = requestDoc.data()!;

    if (approved) {
      // Add to leaves collection if approved
      await _firestore.collection('leaves').add({
        'userId': data['userId'],
        'startDate': data['startDate'],
        'endDate': data['endDate'],
        'reason': data['reason'],
        'leaveType': data['leaveType'],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'approvedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // Update request status
    await requestDoc.reference.update({
      'status': approved ? 'approved' : 'declined',
      'processedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Add leave directly (for admins, bypasses approval)
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
        .orderBy('startDate')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> deleteLeave(String leaveId) {
    return _firestore.collection('leaves').doc(leaveId).delete();
  }

  /// Admin: Get all leaves across counsellors
  Stream<List<Map<String, dynamic>>> allLeaves() {
    return _firestore.collection('leaves').orderBy('startDate').snapshots().map(
        (snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
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

  Future<void> markNotificationRead(String userId, String notificationId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  /// Send a generic notification to a user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? appointmentId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'title': title,
      'message': message,
      'type': type,
      if (appointmentId != null) 'appointmentId': appointmentId,
      'read': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Send a mood tracking reminder if user hasn't logged mood in over 24 hours.
  /// Marks a flag to avoid duplicate reminders within the same day.
  Future<void> sendMoodTrackingReminderIfDue(String userId) async {
    try {
      final now = DateTime.now();
      final oneDayAgo = now.subtract(const Duration(days: 1));

      // Check if user has logged mood in the last 24 hours
      final recentMoodSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('moods')
          .where('timestamp', isGreaterThan: oneDayAgo.millisecondsSinceEpoch)
          .limit(1)
          .get();

      // If they have recent mood entries, don't send reminder
      if (recentMoodSnap.docs.isNotEmpty) {
        return;
      }

      // Check if we've already sent a reminder today
      final todayStart =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final existingReminderSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'mood_tracking_reminder')
          .where('createdAt', isGreaterThan: todayStart)
          .limit(1)
          .get();

      // If we've already sent a reminder today, don't send another
      if (existingReminderSnap.docs.isNotEmpty) {
        return;
      }

      // Array of caring messages
      final messages = [
        'Oh dear, let us know how you feel today 💙',
        'How\'s your day going? We\'d love to hear from you 🌟',
        'We didn\'t hear from you today. Are you okay, dear? 💭',
        'Hey there! How are you feeling today? 😊',
        'It\'s been a while. Share your feelings with us 💚',
        'Take a moment to check in with yourself today 🌸',
      ];

      // Pick a random message
      final randomMessage =
          messages[DateTime.now().millisecond % messages.length];

      // Send the notification
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Mood Check-in',
        'message': randomMessage,
        'type': 'mood_tracking_reminder',
        'read': false,
        'createdAt': now.millisecondsSinceEpoch,
      });
    } catch (e) {
      // Non-blocking: silently fail if reminder can't be sent
      print('Error sending mood tracking reminder: $e');
    }
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

    // Check counsellor active status
    final counsellorDoc =
        await _firestore.collection('users').doc(counsellorId).get();
    final counsellorData = counsellorDoc.data() ?? {};
    final counsellorActive = counsellorData['isActive'] as bool? ?? true;
    if (!counsellorActive) {
      conflicts.add('Counsellor account is inactive.');
    }

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
      final statusStr = data['status'] as String?;
      // Only consider confirmed and pending appointments as conflicts
      if (statusStr == 'cancelled') {
        return false;
      }
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
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) {
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

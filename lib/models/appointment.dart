enum AppointmentStatus { pending, confirmed, completed, cancelled }
enum SessionType { online, faceToFace }

class Appointment {
  Appointment({
    required this.id,
    required this.studentId,
    required this.counsellorId,
    required this.start,
    required this.end,
    required this.status,
    this.notes,
    this.topic,
    this.sentiment,
    this.riskLevel,
    this.isDuplicate = false,
    this.studentRating,
    this.studentComment,
    this.counsellorNotes,
    this.followUpPlan,
    this.createdAt,
    this.updatedAt,
    this.sessionType,
    this.initialProblem,
    this.meetLink,
  });

  final String id;
  final String studentId;
  final String counsellorId;
  final DateTime start;
  final DateTime end;
  final AppointmentStatus status;
  final String? notes;
  final String? topic;
  final String? sentiment;
  final String? riskLevel;
  final bool isDuplicate;
  final int? studentRating;
  final String? studentComment;
  final String? counsellorNotes;
  final String? followUpPlan;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SessionType? sessionType;
  final String? initialProblem;
  final String? meetLink;

  factory Appointment.fromJson(Map<String, dynamic> json, String id) {
    return Appointment(
      id: id,
      studentId: json['studentId'] as String,
      counsellorId: json['counsellorId'] as String,
      start: DateTime.fromMillisecondsSinceEpoch(
        (json['start'] as num?)?.toInt() ?? 0,
      ),
      end: DateTime.fromMillisecondsSinceEpoch(
        (json['end'] as num?)?.toInt() ?? 0,
      ),
      status: _statusFromString(json['status'] as String?),
      notes: json['notes'] as String?,
      topic: json['topic'] as String?,
      sentiment: json['sentiment'] as String?,
      riskLevel: json['riskLevel'] as String?,
      isDuplicate: json['isDuplicate'] as bool? ?? false,
      studentRating: (json['studentRating'] as num?)?.toInt(),
      studentComment: json['studentComment'] as String?,
      counsellorNotes: json['counsellorNotes'] as String?,
      followUpPlan: json['followUpPlan'] as String?,
      createdAt: _tsToDate(json['createdAt']),
      updatedAt: _tsToDate(json['updatedAt']),
      sessionType: _sessionTypeFromString(json['sessionType'] as String?),
      initialProblem: json['initialProblem'] as String?,
      meetLink: json['meetLink'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'counsellorId': counsellorId,
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
      'status': status.name,
      'notes': notes,
      'topic': topic,
      if (sentiment != null) 'sentiment': sentiment,
      if (riskLevel != null) 'riskLevel': riskLevel,
      'isDuplicate': isDuplicate,
      if (studentRating != null) 'studentRating': studentRating,
      if (studentComment != null) 'studentComment': studentComment,
      if (counsellorNotes != null) 'counsellorNotes': counsellorNotes,
      if (followUpPlan != null) 'followUpPlan': followUpPlan,
      'createdAt': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      if (sessionType != null) 'sessionType': sessionType!.name,
      if (initialProblem != null) 'initialProblem': initialProblem,
      if (meetLink != null) 'meetLink': meetLink,
    };
  }

  static DateTime? _tsToDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }

  static AppointmentStatus _statusFromString(String? value) {
    switch (value) {
      case 'confirmed':
        return AppointmentStatus.confirmed;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'pending':
      default:
        return AppointmentStatus.pending;
    }
  }

  static SessionType? _sessionTypeFromString(String? value) {
    switch (value) {
      case 'online':
        return SessionType.online;
      case 'faceToFace':
        return SessionType.faceToFace;
      default:
        return null;
    }
  }
}

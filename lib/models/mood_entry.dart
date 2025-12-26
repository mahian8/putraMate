class MoodEntry {
  MoodEntry({
    required this.id,
    required this.userId,
    required this.moodScore,
    required this.note,
    required this.timestamp,
    this.sentiment,
    this.riskLevel,
    this.flaggedForCounsellor = false,
  });

  final String id;
  final String userId;
  final int moodScore; // 1-10
  final String note;
  final DateTime timestamp;
  final String? sentiment;
  final String? riskLevel;
  final bool flaggedForCounsellor;

  factory MoodEntry.fromJson(Map<String, dynamic> json, String id) {
    return MoodEntry(
      id: id,
      userId: json['userId'] as String,
      moodScore: (json['moodScore'] as num?)?.toInt() ?? 5,
      note: json['note'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] as num?)?.toInt() ?? 0,
      ),
      sentiment: json['sentiment'] as String?,
      riskLevel: json['riskLevel'] as String?,
      flaggedForCounsellor: json['flaggedForCounsellor'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'moodScore': moodScore,
      'note': note,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'sentiment': sentiment,
      'riskLevel': riskLevel,
      'flaggedForCounsellor': flaggedForCounsellor,
    };
  }
}

class JournalEntry {
  JournalEntry({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.moodScore,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String content;
  final int moodScore; // 1-10 scale
  final DateTime createdAt;

  factory JournalEntry.fromJson(Map<String, dynamic> json, String id) {
    return JournalEntry(
      id: id,
      userId: json['userId'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      moodScore: (json['moodScore'] as num?)?.toInt() ?? 5,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'moodScore': moodScore,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}

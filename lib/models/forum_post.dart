class ForumPost {
  ForumPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.content,
    required this.createdAt,
    this.tags = const [],
    this.likes = const [],
    this.commentCount = 0,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String title;
  final String content;
  final DateTime createdAt;
  final List<String> tags;
  final List<String> likes; // List of user IDs who liked
  final int commentCount;

  factory ForumPost.fromJson(Map<String, dynamic> json, String id) {
    return ForumPost(
      id: id,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String? ?? 'Anon',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      likes: (json['likes'] as List<dynamic>?)?.cast<String>() ?? const [],
      commentCount: (json['commentCount'] as int?) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'title': title,
      'content': content,
      'tags': tags,
      'likes': likes,
      'commentCount': commentCount,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}

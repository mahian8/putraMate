class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.isBot = false,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool isBot;

  factory ChatMessage.fromJson(Map<String, dynamic> json, String id) {
    return ChatMessage(
      id: id,
      senderId: json['senderId'] as String,
      text: json['text'] as String? ?? '',
      sentAt: DateTime.fromMillisecondsSinceEpoch(
        (json['sentAt'] as num?)?.toInt() ?? 0,
      ),
      isBot: json['isBot'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'text': text,
      'sentAt': sentAt.millisecondsSinceEpoch,
      'isBot': isBot,
    };
  }
}

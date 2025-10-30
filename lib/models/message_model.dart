class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String type; // 'text' or 'image' (or 'file')
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String,
      type: map['type'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
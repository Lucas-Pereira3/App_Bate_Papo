class Conversation {
  final String id;
  final String? name;
  final bool isGroup;
  final DateTime createdAt;

  Conversation({
    required this.id,
    this.name,
    this.isGroup = false,
    required this.createdAt,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      name: map['name'] as String?,
      isGroup: map['is_group'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
enum ChatRole { user, aether, system }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.imageUrl,
    this.imageBase64,
    this.isStreaming = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final ChatRole role;
  final String text;
  final String? imageUrl;
  final String? imageBase64;
  final bool isStreaming;
  final DateTime createdAt;

  bool get hasImage =>
      (imageUrl != null && imageUrl!.isNotEmpty) ||
      (imageBase64 != null && imageBase64!.isNotEmpty);

  ChatMessage copyWith({
    String? text,
    String? imageUrl,
    String? imageBase64,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBase64: imageBase64 ?? this.imageBase64,
      isStreaming: isStreaming ?? this.isStreaming,
      createdAt: createdAt,
    );
  }
}

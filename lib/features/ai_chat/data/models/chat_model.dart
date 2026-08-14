import '../../domain/entities/chat_entity.dart';

class ChatMessageModel {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
        id: json['id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  ChatMessageEntity toEntity() => ChatMessageEntity(
        id: id,
        role: role == 'user' ? MessageRole.user : MessageRole.assistant,
        content: content,
        createdAt: createdAt,
      );
}

class ChatResponseModel {
  final String conversationId;
  final ChatMessageModel message;

  const ChatResponseModel({required this.conversationId, required this.message});

  factory ChatResponseModel.fromJson(Map<String, dynamic> json) => ChatResponseModel(
        conversationId: json['conversationId'] as String,
        message: ChatMessageModel.fromJson(json['message'] as Map<String, dynamic>),
      );
}

class ChatConversationModel {
  final String id;
  final String? title;
  final DateTime updatedAt;
  final List<ChatMessageModel> messages;

  const ChatConversationModel({
    required this.id,
    this.title,
    required this.updatedAt,
    this.messages = const [],
  });

  factory ChatConversationModel.fromJson(Map<String, dynamic> json) => ChatConversationModel(
        id: json['id'] as String,
        title: json['title'] as String?,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        messages: (json['messages'] as List?)
                ?.map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  ChatConversationEntity toEntity() => ChatConversationEntity(
        id: id,
        title: title,
        updatedAt: updatedAt,
        lastMessagePreview: messages.isNotEmpty ? messages.last.content : null,
      );
}

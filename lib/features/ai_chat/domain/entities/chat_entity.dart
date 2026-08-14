import 'package:equatable/equatable.dart';

enum MessageRole { user, assistant }

class ChatMessageEntity extends Equatable {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final bool isPending;
  final bool isError;

  const ChatMessageEntity({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isPending = false,
    this.isError = false,
  });

  ChatMessageEntity copyWith({String? content, bool? isPending, bool? isError}) {
    return ChatMessageEntity(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      isPending: isPending ?? this.isPending,
      isError: isError ?? this.isError,
    );
  }

  @override
  List<Object?> get props => [id, role, content, createdAt, isPending, isError];
}

class ChatConversationEntity extends Equatable {
  final String id;
  final String? title;
  final DateTime updatedAt;
  final String? lastMessagePreview;

  const ChatConversationEntity({
    required this.id,
    this.title,
    required this.updatedAt,
    this.lastMessagePreview,
  });

  @override
  List<Object?> get props => [id, title, updatedAt, lastMessagePreview];
}

/// Suggested opening prompts shown on a fresh conversation
abstract final class SuggestedPrompts {
  static const all = [
    'How am I doing financially this month?',
    'Which budget category am I overspending in?',
    'How can I reach my savings goals faster?',
    'What subscriptions should I consider cancelling?',
  ];
}

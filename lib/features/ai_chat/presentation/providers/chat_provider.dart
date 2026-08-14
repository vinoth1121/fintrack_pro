import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/chat_entity.dart';
import '../../data/repositories/chat_repository.dart';
import '../../../../core/errors/failures.dart';

const _uuid = Uuid();

// ─── Chat State ──────────────────────────────────────────────────────────────

class ChatState extends Equatable {
  final List<ChatMessageEntity> messages;
  final bool isSending;
  final String? conversationId;
  final Failure? failure;

  const ChatState({
    this.messages = const [],
    this.isSending = false,
    this.conversationId,
    this.failure,
  });

  bool get isEmpty => messages.isEmpty;

  ChatState copyWith({
    List<ChatMessageEntity>? messages,
    bool? isSending,
    String? conversationId,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      conversationId: conversationId ?? this.conversationId,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [messages, isSending, conversationId, failure];
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;

  ChatNotifier(this._repository) : super(const ChatState());

  Future<void> loadConversation(String conversationId) async {
    final result = await _repository.getConversation(conversationId);
    result.fold(
      (failure) => state = state.copyWith(failure: failure),
      (model) => state = state.copyWith(
        conversationId: model.id,
        messages: model.messages.map((m) => m.toEntity()).toList(),
      ),
    );
  }

  void startNewConversation() {
    state = const ChatState();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || state.isSending) return;

    final userMessage = ChatMessageEntity(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: content.trim(),
      createdAt: DateTime.now(),
    );

    // Placeholder assistant message shows a typing indicator while we wait
    final pendingId = _uuid.v4();
    final pendingMessage = ChatMessageEntity(
      id: pendingId,
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      isPending: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, pendingMessage],
      isSending: true,
      clearFailure: true,
    );

    final result = await _repository.sendMessage(
      conversationId: state.conversationId,
      message: content.trim(),
      history: state.messages
          .where((m) => !m.isPending && !m.isError)
          .map((m) => {
                'role': m.role == MessageRole.user ? 'user' : 'assistant',
                'content': m.content,
              },)
          .toList(),
    );

    result.fold(
      (failure) {
        // Replace the pending bubble with an inline error state rather than
        // a generic snackbar — the user needs to see exactly which message failed.
        final updated = state.messages.map((m) {
          if (m.id != pendingId) return m;
          return m.copyWith(
            content: failure.message,
            isPending: false,
            isError: true,
          );
        }).toList();
        state = state.copyWith(messages: updated, isSending: false, failure: failure);
      },
      (response) {
        final updated = state.messages.map((m) {
          if (m.id != pendingId) return m;
          return ChatMessageEntity(
            id: response.message.id,
            role: MessageRole.assistant,
            content: response.message.content,
            createdAt: response.message.createdAt,
          );
        }).toList();
        state = state.copyWith(
          messages: updated,
          isSending: false,
          conversationId: response.conversationId,
        );
      },
    );
  }

  Future<void> retryLastMessage() async {
    if (state.messages.length < 2) return;
    final lastUserMessage = state.messages.reversed.firstWhere(
      (m) => m.role == MessageRole.user,
      orElse: () => state.messages.last,
    );
    // Drop the failed assistant bubble before retrying
    final withoutFailed = state.messages.where((m) => !m.isError).toList();
    state = state.copyWith(messages: withoutFailed);
    await sendMessage(lastUserMessage.content);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(chatRepositoryProvider));
});

// ─── Conversation History List ────────────────────────────────────────────────

enum ConversationListStatus { initial, loading, loaded, error }

class ConversationListState extends Equatable {
  final ConversationListStatus status;
  final List<ChatConversationEntity> conversations;
  final Failure? failure;

  const ConversationListState({
    this.status = ConversationListStatus.initial,
    this.conversations = const [],
    this.failure,
  });

  ConversationListState copyWith({
    ConversationListStatus? status,
    List<ChatConversationEntity>? conversations,
    Failure? failure,
  }) {
    return ConversationListState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, conversations, failure];
}

class ConversationListNotifier extends StateNotifier<ConversationListState> {
  final ChatRepository _repository;

  ConversationListNotifier(this._repository) : super(const ConversationListState());

  Future<void> load() async {
    state = state.copyWith(status: ConversationListStatus.loading);
    final result = await _repository.getConversations();

    result.fold(
      (failure) => state = state.copyWith(status: ConversationListStatus.error, failure: failure),
      (models) => state = state.copyWith(
        status: ConversationListStatus.loaded,
        conversations: models.map((m) => m.toEntity()).toList(),
      ),
    );
  }
}

final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, ConversationListState>((ref) {
  return ConversationListNotifier(ref.watch(chatRepositoryProvider));
});

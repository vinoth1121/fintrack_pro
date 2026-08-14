import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/chat_entity.dart';
import '../providers/chat_provider.dart';
import '../../../../shared/widgets/shell/main_shell.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppDurations.normal,
          curve: AppCurves.decelerate,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    _inputFocusNode.unfocus();
    _scrollToBottom();
    await ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    ref.listen(chatProvider, (previous, next) {
      if (next.messages.length != previous?.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => ShellScaffoldData.of(context)?.openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('AI Assistant', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'New conversation',
              onPressed: () => ref.read(chatProvider.notifier).startNewConversation(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.isEmpty
                ? _EmptyState(onPromptTap: _send)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.sm),
                    itemCount: state.messages.length,
                    itemBuilder: (context, i) {
                      final message = state.messages[i];
                      return _MessageBubble(
                        message: message,
                        onRetry: message.isError ? () => ref.read(chatProvider.notifier).retryLastMessage() : null,
                      );
                    },
                  ),
          ),
          _ChatInputBar(
            controller: _inputController,
            focusNode: _inputFocusNode,
            isSending: state.isSending,
            onSend: () => _send(),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State with Suggested Prompts ──────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onPromptTap;
  const _EmptyState({required this.onPromptTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Your Financial Assistant',
              style: AppTypography.titleLarge.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ask about your spending, budgets, or savings goals — I have context on your real financial data.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            ...SuggestedPrompts.all.map((prompt) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PromptChip(text: prompt, onTap: () => onPromptTap(prompt)),
            ),),
          ],
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _PromptChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkCard,
      borderRadius: BorderRadius.circular(AppRadius.base),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.base),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.base), border: Border.all(color: AppColors.darkBorder, width: 0.5)),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text, style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary))),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessageEntity message;
  final VoidCallback? onRetry;

  const _MessageBubble({required this.message, this.onRetry});

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!_isUser) _AvatarIcon(isError: message.isError),
          if (!_isUser) const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _isUser
                        ? AppColors.primary
                        : message.isError
                            ? AppColors.errorContainer
                            : AppColors.darkCard,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppRadius.base),
                      topRight: const Radius.circular(AppRadius.base),
                      bottomLeft: Radius.circular(_isUser ? AppRadius.base : AppRadius.xs),
                      bottomRight: Radius.circular(_isUser ? AppRadius.xs : AppRadius.base),
                    ),
                    border: _isUser ? null : Border.all(color: AppColors.darkBorder, width: 0.5),
                  ),
                  child: message.isPending
                      ? const _TypingIndicator()
                      : Text(
                          message.content,
                          style: AppTypography.bodyMedium.copyWith(
                            color: _isUser ? Colors.white : AppColors.darkTextPrimary,
                            height: 1.5,
                          ),
                        ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  GestureDetector(
                    onTap: onRetry,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded, size: 12, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text('Retry', style: AppTypography.labelSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
                if (!message.isPending) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat.jm().format(message.createdAt),
                    style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarIcon extends StatelessWidget {
  final bool isError;
  const _AvatarIcon({required this.isError});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        gradient: isError ? null : AppColors.primaryGradient,
        color: isError ? AppColors.error : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(
        isError ? Icons.error_outline_rounded : Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 14,
      ),
    );
  }
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final delay = i * 0.2;
              final t = (_controller.value - delay) % 1.0;
              final opacity = t < 0.5 ? (0.3 + t) : (1.3 - t);
              return Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: AppColors.darkTextTertiary.withValues(alpha: opacity.clamp(0.3, 1.0)),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          border: Border(top: BorderSide(color: AppColors.darkDivider, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: AppColors.darkBorder, width: 0.5),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Ask about your finances...',
                    hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextTertiary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: InkWell(
                onTap: isSending ? null : onSend,
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: Container(
                  width: 44, height: 44,
                  alignment: Alignment.center,
                  child: isSending
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

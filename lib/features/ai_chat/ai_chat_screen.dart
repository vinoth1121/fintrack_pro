import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/ai_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';

/// AI Chat screen — faithful port of the web `AiChatView`.
/// Header + messages list + input bar; markdown assistant replies.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});
  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _loading = false;

  static const _suggestions = <_Suggestion>[
    _Suggestion(
        icon: Icons.trending_up, text: 'Analyze my spending this month', color: AppColors.iris,),
    _Suggestion(
        icon: Icons.savings_outlined,
        text: 'How can I improve my savings rate?',
        color: AppColors.success,),
    _Suggestion(
        icon: Icons.warning_amber_rounded,
        text: 'Which budget am I closest to exceeding?',
        color: AppColors.warning,),
    _Suggestion(
        icon: Icons.flag_outlined,
        text: "Forecast when I'll hit my savings goals",
        color: AppColors.cyan,),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  String _buildContext() {
    final state = ref.read(fintrackProvider);
    final d = ref.read(derivedProvider);
    final cur = state.profile.baseCurrency;
    final topCats = d.categoryBreakdown.take(5).map((c) {
      final amt = formatMoney(c.amount, cur);
      return '  • ${c.name}: $amt (${c.pct}%)';
    }).join('\n');
    final budgets = d.budgetUsage.map((b) {
      final spent = formatMoney(b.spent, cur);
      final limit = formatMoney(b.limit, cur);
      return '  • ${b.categoryName}: spent $spent / $limit (${b.pct}%${b.over ? ", OVER" : ""})';
    }).join('\n');
    final goalLines = state.goals.map((g) {
      final saved = formatMoney(g.saved, cur);
      final target = formatMoney(g.target, cur);
      final pct = g.target > 0 ? ((g.saved / g.target) * 100).round() : 0;
      return '  • ${g.name}: $saved / $target ($pct%)';
    }).join('\n');
    var subTotal = 0.0;
    for (final s in state.subscriptions.where((s) => s.active)) {
      if (s.cycle == 'monthly') {
        subTotal += s.amount;
      } else if (s.cycle == 'yearly') {
        subTotal += s.amount / 12;
      } else {
        subTotal += s.amount * 4.33;
      }
    }
    final trend = d.trend.map((t) {
      final inc = formatMoney(t.income, cur, compact: true);
      final exp = formatMoney(t.expense, cur, compact: true);
      return '${t.month}: in $inc/out $exp';
    }).join(', ');

    return [
      'Currency: $cur (${state.profile.name})',
      'This month: income ${formatMoney(d.monthIncome, cur)}, expenses ${formatMoney(d.monthExpenses, cur)}, savings rate ${(d.savingsRate * 100).round()}%.',
      'Net worth (account balances): ${formatMoney(d.netBalance, cur)}.',
      'Expense vs last month: ${d.expenseDelta >= 0 ? "+" : ""}${d.expenseDelta.round()}%.',
      'Top spending categories this month:',
      topCats.isEmpty ? '  • (none)' : topCats,
      'Budgets:',
      budgets.isEmpty ? '  • (none)' : budgets,
      'Savings goals:',
      goalLines.isEmpty ? '  • (none)' : goalLines,
      'Active subscriptions monthly cost: ${formatMoney(subTotal, cur)} (${state.subscriptions.where((s) => s.active).length} active).',
      '6-month trend: $trend',
    ].join('\n');
  }

  Future<void> _send(String text) async {
    final t = ref.read(tProvider);
    final content = text.trim();
    if (content.isEmpty || _loading) return;
    final state = ref.read(fintrackProvider);
    final history = [...state.chat, ChatMessage(
      id: uid('msg'),
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    ),];
    ref.read(fintrackProvider.notifier).addChatMessage(history.last);
    _input.clear();
    setState(() => _loading = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    String reply;
    try {
      reply = await AiRepository.chat(history: history, context: _buildContext());
    } catch (_) {
      reply = "I couldn't reach the AI service. Please check your connection and try again.";
      if (mounted) showAppToast(context, t.messages.aiRequestFailed, kind: ToastKind.error);
    }
    if (!mounted) return;
    ref.read(fintrackProvider.notifier).addChatMessage(ChatMessage(
      id: uid('msg'),
      role: 'assistant',
      content: reply,
      createdAt: DateTime.now(),
    ),);
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _clearChat() {
    final t = ref.read(tProvider);
    ref.read(fintrackProvider.notifier).clearChat();
    showAppToast(context, t.aiChat.clearConversation, kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final chat = ref.watch(fintrackProvider.select((s) => s.chat));
    // Auto-scroll when messages change.
    ref.listen(fintrackProvider.select((s) => s.chat), (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(t, chat.isNotEmpty),
          const SizedBox(height: 16),
          Expanded(child: _buildBody(t, chat)),
          const SizedBox(height: 12),
          _buildInput(t),
        ],
      ),
    );
  }

  Widget _buildHeader(AppT t, bool hasChat) {
    return GlassCard(
      strong: true,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: AppColors.brandGradient,
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientPill(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.auto_awesome, size: 12, color: AppColors.iris),
                  const SizedBox(width: 6),
                  Text(t.aiChat.aiFinancialCoach),
                ],),),
                const SizedBox(height: 6),
                Text(t.aiChat.groundedInData,
                    style: AppTypography.body(context, size: 12)
                        .copyWith(color: context.lumina.mutedForeground),),
              ],
            ),
          ),
          if (hasChat)
            GhostButton(
              icon: const Icon(Icons.delete_outline, size: 14),
              onPressed: _clearChat,
              child: Text(t.aiChat.clear),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(AppT t, List<ChatMessage> chat) {
    if (chat.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AppColors.brandGradient,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 400.ms),
              Text(t.aiChat.askLumina, style: AppTypography.display(context, size: 20)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  t.aiChat.canAnalyze,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(context, size: 12)
                      .copyWith(color: context.lumina.mutedForeground),
                ),
              ),
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: LayoutBuilder(builder: (context, c) {
                  final twoCol = c.maxWidth >= 560;
                  final cardWidth = twoCol ? (c.maxWidth - 8) / 2 : c.maxWidth;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < _suggestions.length; i++)
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: cardWidth),
                          child: _SuggestionCard(
                            suggestion: _suggestions[i],
                            onTap: () => _send(_suggestions[i].text),
                          )
                              .animate()
                              .fadeIn(delay: (100 + i * 80).ms, duration: 400.ms)
                              .slideY(
                                  begin: 0.1,
                                  end: 0,
                                  duration: 400.ms,
                                  delay: (100 + i * 80).ms,),
                        ),
                    ],
                  );
                },),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(right: 4),
      itemCount: chat.length + (_loading ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == chat.length) {
          return _TypingIndicator()
              .animate()
              .fadeIn(duration: 200.ms);
        }
        final m = chat[i];
        return _ChatBubble(
          role: m.role,
          content: m.content,
          index: i,
        ).animate().fadeIn(delay: (i * 20).clamp(0, 200).ms, duration: 300.ms).slideY(
              begin: 0.05,
              end: 0,
              duration: 300.ms,
              delay: (i * 20).clamp(0, 200).ms,
            );
      },
    );
  }

  Widget _buildInput(AppT t) {
    final l = context.lumina;
    return GlassCard(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              maxLines: 4,
              minLines: 1,
              style: AppTypography.body(context, size: 13),
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: t.aiChat.askAboutFinances,
                hintStyle: AppTypography.body(context, size: 13)
                    .copyWith(color: l.mutedForeground),
              ),
              onSubmitted: (v) => _send(v),
            ),
          ),
          const SizedBox(width: 8),
          GradientButton(
            icon: const Icon(Icons.send, size: 14),
            onPressed: _loading ? null : () => _send(_input.text),
            child: Text(t.aiChat.send),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Sub-widgets
// =============================================================

class _Suggestion {
  final IconData icon;
  final String text;
  final Color color;
  const _Suggestion({required this.icon, required this.text, required this.color});
}

class _SuggestionCard extends StatelessWidget {
  final _Suggestion suggestion;
  final VoidCallback onTap;
  const _SuggestionCard({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: l.surface3.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: l.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: suggestion.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(suggestion.icon, size: 18, color: suggestion.color),
              ),
              Expanded(
                child: Text(
                  suggestion.text,
                  style: AppTypography.body(context, size: 13, weight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String role;
  final String content;
  final int index;
  const _ChatBubble({required this.role, required this.content, required this.index});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final isUser = role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _avatar(context, isUser),
          if (!isUser) const SizedBox(width: 10),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.iris.withValues(alpha: 0.10)
                    : l.surface3.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: l.border, width: 1),
              ),
              child: isUser
                  ? Text(content, style: AppTypography.body(context, size: 13))
                  : _MarkdownView(content: content),
            ),
          ),
          if (isUser) const SizedBox(width: 10),
          if (isUser) _avatar(context, isUser),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, bool isUser) {
    final l = context.lumina;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isUser ? l.surface3 : null,
        gradient: isUser ? null : AppColors.brandGradient,
      ),
      child: Icon(
        isUser ? Icons.person : Icons.auto_awesome,
        color: isUser ? l.foreground : Colors.white,
        size: 16,
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: AppColors.brandGradient,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (d) {
                return Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(color: AppColors.iris, shape: BoxShape.circle),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .fade(
                      begin: 0.3,
                      end: 1,
                      duration: 900.ms,
                      delay: (d * 150).ms,
                    )
                    .moveY(
                      begin: 0,
                      end: -3,
                      duration: 900.ms,
                      delay: (d * 150).ms,
                    );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Minimal Markdown renderer — bold + bullets + paragraphs
// =============================================================

class _MarkdownView extends StatelessWidget {
  final String content;
  const _MarkdownView({required this.content});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final lines = content.split('\n');
    final blocks = <Widget>[];
    final bullets = <Widget>[];

    void flushBullets() {
      if (bullets.isEmpty) return;
      blocks.add(Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.of(bullets),
        ),
      ),);
      bullets.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushBullets();
        continue;
      }
      final isBullet = trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          trimmed.startsWith('• ');
      if (isBullet) {
        bullets.add(Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 8),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(color: AppColors.iris, shape: BoxShape.circle),
                ),
              ),
              Expanded(child: _RichSegments(text: trimmed.substring(2))),
            ],
          ),
        ),);
      } else {
        flushBullets();
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: _RichSegments(text: trimmed),
        ),);
      }
    }
    flushBullets();

    return DefaultTextStyle.merge(
      style: AppTypography.body(context, size: 13).copyWith(color: l.foreground),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks,
      ),
    );
  }
}

class _RichSegments extends StatelessWidget {
  final String text;
  const _RichSegments({required this.text});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    var lastEnd = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(color: AppColors.iris, fontWeight: FontWeight.w600),
      ),);
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: text));
    return RichText(
      text: TextSpan(
        style: AppTypography.body(context, size: 13).copyWith(color: l.foreground),
        children: spans,
      ),
    );
  }
}

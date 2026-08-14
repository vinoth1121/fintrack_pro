import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_tokens.dart';
import '../providers/voice_input_provider.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/voice_expense_parser.dart';
import '../screens/receipt_scanner_screen.dart' show ScannedExpenseDraft;
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class VoiceExpenseScreen extends ConsumerWidget {
  const VoiceExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceInputProvider);

    ref.listen(voiceInputProvider, (previous, next) {
      if (next.status == VoiceInputStatus.error && next.errorMessage != null) {
        AppSnackbar.error(context, next.errorMessage!);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Voice Expense',
          style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: switch (state.status) {
        VoiceInputStatus.success => _ReviewView(parsed: state.parsed!, transcript: state.transcript),
        VoiceInputStatus.listening ||
        VoiceInputStatus.requestingPermission ||
        VoiceInputStatus.processing =>
          _ListeningView(state: state),
        _ => const _StartView(),
      },
    );
  }
}

// ─── Start View (idle / error / not-available) ───────────────────────────────

class _StartView extends ConsumerWidget {
  const _StartView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Log an Expense by Voice',
              style: AppTypography.titleLarge.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Try saying something like:\n"Spent twenty dollars at Target for groceries"',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            AppPrimaryButton(
              label: 'Start Speaking',
              leadingIcon: Icons.mic_rounded,
              onTap: () => ref.read(voiceInputProvider.notifier).startListening(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Listening / Processing View ─────────────────────────────────────────────

class _ListeningView extends ConsumerStatefulWidget {
  final VoiceInputState state;
  const _ListeningView({required this.state});

  @override
  ConsumerState<_ListeningView> createState() => _ListeningViewState();
}

class _ListeningViewState extends ConsumerState<_ListeningView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.state.status == VoiceInputStatus.listening;
    final isProcessing = widget.state.status == VoiceInputStatus.processing;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = isListening ? 1.0 + (_pulseController.value * 0.15) : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: isListening ? AppColors.error.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: isListening ? AppColors.error : AppColors.primary, width: 2),
                ),
                child: isProcessing
                    ? const Center(
                        child: SizedBox(
                          width: 32, height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                        ),
                      )
                    : Icon(Icons.mic_rounded, color: isListening ? AppColors.error : AppColors.primary, size: 40),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              isProcessing ? 'Understanding...' : isListening ? 'Listening...' : 'Getting ready...',
              style: AppTypography.titleSmall.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.base),
            if (widget.state.transcript.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.base),
                decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(AppRadius.base)),
                child: Text(
                  '"${widget.state.transcript}"',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            if (isListening) ...[
              const SizedBox(height: AppSpacing.xxxl),
              Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => ref.read(voiceInputProvider.notifier).stopListening(),
                  child: Text('Done Speaking', style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Review View (editable pre-fill, never auto-submitted) ──────────────────

class _ReviewView extends ConsumerStatefulWidget {
  final ParsedVoiceExpense parsed;
  final String transcript;

  const _ReviewView({required this.parsed, required this.transcript});

  @override
  ConsumerState<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends ConsumerState<_ReviewView> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.parsed.merchant ?? '');
    _amountController = TextEditingController(
      text: widget.parsed.amount != null ? widget.parsed.amount!.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  CategoryEntity? get _matchedCategory {
    final hint = widget.parsed.categoryHint;
    if (hint == null) return null;
    try {
      return DefaultCategories.expense.firstWhere((c) => c.id == hint);
    } catch (_) {
      return null;
    }
  }

  void _confirmAndContinue() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      AppSnackbar.warning(context, 'Please check the amount before continuing.');
      return;
    }

    // Same handoff pattern as Receipt Scanner — reuses AddExpenseScreen's
    // existing validation, category selection, and submission logic rather
    // than duplicating it.
    context.pushReplacement(
      '/expenses/add',
      extra: ScannedExpenseDraft(
        title: _titleController.text.trim().isEmpty ? 'Voice Expense' : _titleController.text.trim(),
        amount: amount,
        date: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = _matchedCategory;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(AppRadius.base)),
            child: Row(
              children: [
                const Icon(Icons.record_voice_over_rounded, size: 16, color: AppColors.darkTextTertiary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '"${widget.transcript}"',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    'Please review before saving',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('What was it for?', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _titleController,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.darkCard,
              hintText: 'e.g. Starbucks',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text('Amount', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.darkCard,
              prefixText: '\$ ',
              hintText: '0.00',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide.none),
            ),
          ),
          if (category != null) ...[
            const SizedBox(height: AppSpacing.base),
            Text('Detected category', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            Builder(builder: (context) {
              final categoryColor = Color(int.parse(category.color.replaceFirst('#', '0xFF')));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: categoryColor),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      category.name,
                      style: AppTypography.labelMedium.copyWith(color: categoryColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'You can change this on the next screen',
                style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxxl),
          AppPrimaryButton(label: 'Continue to Expense', onTap: _confirmAndContinue),
          const SizedBox(height: AppSpacing.sm),
          Consumer(
            builder: (context, ref, _) => AppOutlinedButton(
              label: 'Try Again',
              leadingIcon: Icons.refresh_rounded,
              onTap: () => ref.read(voiceInputProvider.notifier).reset(),
            ),
          ),
        ],
      ),
    );
  }
}

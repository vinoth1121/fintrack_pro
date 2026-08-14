import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_tokens.dart';
import '../providers/receipt_scan_provider.dart';
import '../../domain/receipt_parser.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class ReceiptScannerScreen extends ConsumerWidget {
  const ReceiptScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiptScanProvider);

    ref.listen(receiptScanProvider, (previous, next) {
      if (next.status == ScanStatus.error && next.errorMessage != null) {
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
          'Scan Receipt',
          style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: switch (state.status) {
        ScanStatus.idle || ScanStatus.capturing => _CaptureOptions(isLoading: state.status == ScanStatus.capturing),
        ScanStatus.processing => const _ProcessingView(),
        ScanStatus.success => _ReviewView(
            imagePath: state.imagePath!,
            parsed: state.parsedReceipt!,
          ),
        ScanStatus.error => const _CaptureOptions(isLoading: false),
      },
    );
  }
}

// ─── Capture Options (initial state) ────────────────────────────────────────

class _CaptureOptions extends ConsumerWidget {
  final bool isLoading;
  const _CaptureOptions({required this.isLoading});

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
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Scan a Receipt',
              style: AppTypography.titleLarge.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'We\'ll automatically extract the merchant, amount, and date. Everything is processed on your device — nothing is uploaded.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            AppPrimaryButton(
              label: 'Take Photo',
              leadingIcon: Icons.camera_alt_rounded,
              isLoading: isLoading,
              onTap: () => ref.read(receiptScanProvider.notifier).captureFromCamera(),
            ),
            const SizedBox(height: AppSpacing.md),
            AppOutlinedButton(
              label: 'Choose from Gallery',
              leadingIcon: Icons.photo_library_outlined,
              isLoading: isLoading,
              onTap: () => ref.read(receiptScanProvider.notifier).pickFromGallery(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Processing State ────────────────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  const _ProcessingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Reading your receipt...',
            style: AppTypography.titleSmall.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This only takes a moment',
            style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary),
          ),
        ],
      ),
    );
  }
}

// ─── Review View (editable pre-fill, never auto-submitted) ──────────────────

class _ReviewView extends ConsumerStatefulWidget {
  final String imagePath;
  final ParsedReceipt parsed;

  const _ReviewView({required this.imagePath, required this.parsed});

  @override
  ConsumerState<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends ConsumerState<_ReviewView> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.parsed.merchantName ?? '');
    _amountController = TextEditingController(
      text: widget.parsed.totalAmount != null ? widget.parsed.totalAmount!.toStringAsFixed(2) : '',
    );
    _selectedDate = widget.parsed.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndContinue() async {
    final amount = double.tryParse(_amountController.text);
    if (_titleController.text.trim().isEmpty || amount == null || amount <= 0) {
      AppSnackbar.warning(context, 'Please check the merchant name and amount before continuing.');
      return;
    }

    // Hands off to the existing Add Expense screen with the scanned values
    // pre-filled via route `extra` — the scanner's job is to pre-fill data,
    // not to duplicate validation/category/submission logic that already
    // exists and is already tested in AddExpenseScreen.
    if (!mounted) return;
    context.pushReplacement(
      '/expenses/add',
      extra: ScannedExpenseDraft(
        title: _titleController.text.trim(),
        amount: amount,
        date: _selectedDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confidenceColor = widget.parsed.confidence >= 0.66
        ? AppColors.success
        : widget.parsed.confidence >= 0.33
            ? AppColors.warning
            : AppColors.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.base),
            child: Image.file(
              File(widget.imagePath),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: confidenceColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: confidenceColor.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: confidenceColor),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    'Please review before saving — always double-check scanned details',
                    style: AppTypography.labelSmall.copyWith(color: confidenceColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Merchant', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _titleController,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.darkCard,
              hintText: 'Enter merchant name',
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
          const SizedBox(height: AppSpacing.base),
          Text('Date', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.input),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.darkTextSecondary),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          AppPrimaryButton(label: 'Continue to Expense', onTap: _confirmAndContinue),
          const SizedBox(height: AppSpacing.sm),
          Consumer(
            builder: (context, ref, _) => AppOutlinedButton(
              label: 'Scan Again',
              leadingIcon: Icons.refresh_rounded,
              onTap: () => ref.read(receiptScanProvider.notifier).reset(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carries scanner-extracted values to the Add Expense screen via router
/// `extra`, so AddExpenseScreen can pre-fill its text controllers on init
/// without the scanner needing to know about that screen's internal state.
class ScannedExpenseDraft {
  final String title;
  final double amount;
  final DateTime date;

  const ScannedExpenseDraft({
    required this.title,
    required this.amount,
    required this.date,
  });
}

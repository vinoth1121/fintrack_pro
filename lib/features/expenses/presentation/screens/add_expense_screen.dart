import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/expense_entity.dart';
import '../providers/expense_provider.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import 'receipt_scanner_screen.dart' show ScannedExpenseDraft;

class AddExpenseScreen extends ConsumerStatefulWidget {
  final ScannedExpenseDraft? initialDraft;

  const AddExpenseScreen({super.key, this.initialDraft});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  static const _paymentMethods = ['Cash', 'Credit Card', 'Debit Card', 'Bank Transfer', 'Apple Pay'];

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    if (draft != null) {
      _titleController.text = draft.title;
      _amountController.text = draft.amount.toStringAsFixed(2);
      // Defer to after the first frame so the provider is fully initialized
      // before we push a date into it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(addExpenseProvider.notifier).selectDate(draft.date);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(addExpenseProvider.notifier);
    final formState = ref.read(addExpenseProvider);

    if (formState.selectedCategory == null) {
      AppSnackbar.warning(context, 'Please select a category.');
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await notifier.submit(
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      AppSnackbar.success(context, 'Expense added successfully.');
      context.pop();
    } else {
      final failure = ref.read(addExpenseProvider).failure;
      if (failure != null) AppSnackbar.error(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(addExpenseProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add Expense',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.base, AppSpacing.xl, AppSpacing.xxxl,
          ),
          children: [
            // ── Amount Input (large, centered) ──────────────────────────────
            Center(
              child: Column(
                children: [
                  Text(
                    'Amount',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  IntrinsicWidth(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: AppTypography.amountHero.copyWith(
                        color: AppColors.expense,
                        fontSize: 48,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        prefixText: '\$',
                        hintText: '0.00',
                        prefixStyle: TextStyle(
                          fontSize: 32,
                          color: AppColors.darkTextTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final amount = double.tryParse(v);
                        if (amount == null || amount <= 0) return 'Invalid amount';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Title ────────────────────────────────────────────────────────
            AppTextField(
              controller: _titleController,
              label: 'What was it for?',
              hint: 'e.g. Grocery shopping',
              prefixIcon: Icons.edit_outlined,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Title is required';
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Category Grid ────────────────────────────────────────────────
            Text(
              'Category',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.darkTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.85,
              children: DefaultCategories.expense.map((cat) {
                final isSelected = formState.selectedCategory?.id == cat.id;
                final color = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
                return GestureDetector(
                  onTap: () => ref.read(addExpenseProvider.notifier).selectCategory(cat),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: AppDurations.fast,
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.2) : AppColors.darkCard,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: isSelected ? color : AppColors.darkBorder,
                            width: isSelected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Icon(_iconFor(cat.icon), color: isSelected ? color : AppColors.darkTextTertiary, size: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cat.name.split(' ').first,
                        style: AppTypography.labelSmall.copyWith(
                          color: isSelected ? color : AppColors.darkTextTertiary,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Date Picker ──────────────────────────────────────────────────
            _SelectorTile(
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              value: DateFormat('MMM d, yyyy').format(formState.selectedDate),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: formState.selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  ref.read(addExpenseProvider.notifier).selectDate(picked);
                }
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Payment Method ───────────────────────────────────────────────
            _SelectorTile(
              icon: Icons.credit_card_rounded,
              label: 'Payment Method',
              value: formState.selectedPaymentMethod ?? 'Select method',
              onTap: () => _showPaymentMethodSheet(context),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Recurring Toggle ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(AppRadius.base),
                border: Border.all(color: AppColors.darkBorder, width: 0.5),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Recurring Expense',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary),
                ),
                subtitle: Text(
                  'Repeats automatically each period',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary),
                ),
                value: formState.isRecurring,
                onChanged: (_) => ref.read(addExpenseProvider.notifier).toggleRecurring(),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Notes ────────────────────────────────────────────────────────
            AppTextField(
              controller: _notesController,
              label: 'Notes (optional)',
              hint: 'Add any additional details...',
              prefixIcon: Icons.notes_rounded,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // ── Submit ───────────────────────────────────────────────────────
            AppPrimaryButton(
              label: 'Save Expense',
              leadingIcon: Icons.check_rounded,
              isLoading: formState.isLoading,
              color: AppColors.expense,
              onTap: _onSubmit,
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _paymentMethods.map((method) {
            return ListTile(
              title: Text(method, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary)),
              onTap: () {
                ref.read(addExpenseProvider.notifier).selectPaymentMethod(method);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _iconFor(String icon) {
    return switch (icon) {
      'restaurant' => Icons.restaurant_rounded,
      'car' => Icons.directions_car_rounded,
      'bag' => Icons.shopping_bag_rounded,
      'movie' => Icons.movie_rounded,
      'flash' => Icons.flash_on_rounded,
      'health' => Icons.favorite_rounded,
      'book' => Icons.menu_book_rounded,
      'home' => Icons.home_rounded,
      'flight' => Icons.flight_rounded,
      _ => Icons.category_rounded,
    };
  }
}

// ─── Selector Tile (Date / Payment Method) ────────────────────────────────────

class _SelectorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SelectorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkCard,
      borderRadius: BorderRadius.circular(AppRadius.base),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.base),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.base),
            border: Border.all(color: AppColors.darkBorder, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.darkTextSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary)),
                    Text(value, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.darkTextTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

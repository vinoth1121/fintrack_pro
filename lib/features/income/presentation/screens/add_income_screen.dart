import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../providers/income_provider.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class AddIncomeScreen extends ConsumerStatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  ConsumerState<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends ConsumerState<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _sourceController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _sourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(addIncomeProvider.notifier);
    final formState = ref.read(addIncomeProvider);

    if (formState.selectedCategory == null) {
      AppSnackbar.warning(context, 'Please select a category.');
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await notifier.submit(
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      source: _sourceController.text.trim().isEmpty ? null : _sourceController.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      AppSnackbar.success(context, 'Income added successfully.');
      context.pop();
    } else {
      final failure = ref.read(addIncomeProvider).failure;
      if (failure != null) AppSnackbar.error(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(addIncomeProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add Income',
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
                        color: AppColors.income,
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
              hint: 'e.g. Monthly salary',
              prefixIcon: Icons.edit_outlined,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Title is required';
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.base),

            // ── Source ───────────────────────────────────────────────────────
            AppTextField(
              controller: _sourceController,
              label: 'Source (optional)',
              hint: 'e.g. Acme Corp, Client name',
              prefixIcon: Icons.business_outlined,
              textCapitalization: TextCapitalization.words,
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
              children: DefaultCategories.income.map((cat) {
                final isSelected = formState.selectedCategory?.id == cat.id;
                final color = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
                return GestureDetector(
                  onTap: () => ref.read(addIncomeProvider.notifier).selectCategory(cat),
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
                        child: Icon(
                          _iconFor(cat.icon),
                          color: isSelected ? color : AppColors.darkTextTertiary,
                          size: 22,
                        ),
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
                  ref.read(addIncomeProvider.notifier).selectDate(picked);
                }
              },
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
                  'Recurring Income',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary),
                ),
                subtitle: Text(
                  'Repeats automatically each period',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary),
                ),
                value: formState.isRecurring,
                activeThumbColor: AppColors.income,
                onChanged: (_) => ref.read(addIncomeProvider.notifier).toggleRecurring(),
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
              label: 'Save Income',
              leadingIcon: Icons.check_rounded,
              isLoading: formState.isLoading,
              color: AppColors.income,
              onTap: _onSubmit,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String icon) {
    return switch (icon) {
      'work' => Icons.work_rounded,
      'code' => Icons.code_rounded,
      'trending_up' => Icons.trending_up_rounded,
      'gift' => Icons.card_giftcard_rounded,
      'business' => Icons.business_center_rounded,
      _ => Icons.attach_money_rounded,
    };
  }
}

// ─── Selector Tile ────────────────────────────────────────────────────────────

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

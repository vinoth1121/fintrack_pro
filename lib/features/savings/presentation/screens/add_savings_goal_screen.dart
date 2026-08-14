import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/savings_goal_entity.dart';
import '../providers/savings_provider.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class AddSavingsGoalScreen extends ConsumerStatefulWidget {
  const AddSavingsGoalScreen({super.key});

  @override
  ConsumerState<AddSavingsGoalScreen> createState() => _AddSavingsGoalScreenState();
}

class _AddSavingsGoalScreenState extends ConsumerState<AddSavingsGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final success = await ref.read(addGoalProvider.notifier).submit(
      name: _nameController.text.trim(),
      targetAmount: double.parse(_amountController.text),
    );

    if (!mounted) return;
    if (success) {
      AppSnackbar.success(context, 'Savings goal created!');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(addGoalProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => context.pop()),
        title: Text('New Savings Goal', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.base, AppSpacing.xl, AppSpacing.xxxl),
          children: [
            // ── Template Grid ────────────────────────────────────────────────
            Text('Choose a template', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.85,
              children: GoalTemplates.all.map((template) {
                final isSelected = formState.selectedTemplate?.name == template.name;
                final color = Color(int.parse(template.color.replaceFirst('#', '0xFF')));
                return GestureDetector(
                  onTap: () {
                    ref.read(addGoalProvider.notifier).selectTemplate(template);
                    if (_nameController.text.isEmpty || _nameController.text == formState.selectedTemplate?.name) {
                      _nameController.text = template.name == 'Custom Goal' ? '' : template.name;
                    }
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: AppDurations.fast,
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.2) : AppColors.darkCard,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: isSelected ? color : AppColors.darkBorder, width: isSelected ? 1.5 : 0.5),
                        ),
                        child: Icon(_iconFor(template.icon), color: isSelected ? color : AppColors.darkTextTertiary, size: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.name.split(' ').first,
                        style: AppTypography.labelSmall.copyWith(color: isSelected ? color : AppColors.darkTextTertiary, fontSize: 9),
                        maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.xl),

            AppTextField(
              controller: _nameController,
              label: 'Goal Name',
              hint: 'e.g. Emergency Fund',
              prefixIcon: Icons.flag_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),

            const SizedBox(height: AppSpacing.base),

            AppAmountField(controller: _amountController),

            const SizedBox(height: AppSpacing.base),

            // ── Deadline ─────────────────────────────────────────────────────
            Material(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(AppRadius.base),
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 90)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) ref.read(addGoalProvider.notifier).selectDeadline(picked);
                },
                borderRadius: BorderRadius.circular(AppRadius.base),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.base), border: Border.all(color: AppColors.darkBorder, width: 0.5)),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 20, color: AppColors.darkTextSecondary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target Date (optional)', style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary)),
                            Text(
                              formState.deadline != null ? DateFormat('MMM d, yyyy').format(formState.deadline!) : 'No deadline',
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      if (formState.deadline != null)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.darkTextTertiary),
                          onPressed: () => ref.read(addGoalProvider.notifier).selectDeadline(null),
                        )
                      else
                        const Icon(Icons.chevron_right_rounded, color: AppColors.darkTextTertiary),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            AppPrimaryButton(
              label: 'Create Goal',
              leadingIcon: Icons.check_rounded,
              isLoading: formState.isLoading,
              color: AppColors.savings,
              onTap: _onSubmit,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String icon) {
    return switch (icon) {
      'shield' => Icons.shield_rounded,
      'flight' => Icons.flight_rounded,
      'car' => Icons.directions_car_rounded,
      'home' => Icons.home_rounded,
      'favorite' => Icons.favorite_rounded,
      'book' => Icons.menu_book_rounded,
      'devices' => Icons.devices_rounded,
      _ => Icons.flag_rounded,
    };
  }
}

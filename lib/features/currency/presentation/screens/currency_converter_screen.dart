import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/currency_entity.dart';
import '../providers/currency_provider.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import '../../../../shared/widgets/states/app_states.dart';

class CurrencyConverterScreen extends ConsumerStatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  ConsumerState<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends ConsumerState<CurrencyConverterScreen> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '100');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(currencyConverterProvider);

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
        title: Text('Currency Converter', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(currencyConverterProvider.notifier).load(),
          ),
        ],
      ),
      body: state.status == RatesStatus.loading && state.rates == null
          ? const AppLoadingState(message: 'Fetching live exchange rates...')
          : state.status == RatesStatus.error && state.rates == null
              ? AppErrorState(
                  message: state.failure?.message,
                  onRetry: () => ref.read(currencyConverterProvider.notifier).load(),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  children: [
                    // ── From Currency Card ────────────────────────────────────
                    _CurrencyCard(
                      label: 'Amount',
                      currencyCode: state.fromCurrency,
                      controller: _amountController,
                      onChanged: (v) => ref.read(currencyConverterProvider.notifier).setAmount(double.tryParse(v) ?? 0),
                      onCurrencyTap: () => _showCurrencyPicker(context, isFrom: true),
                      editable: true,
                    ),

                    // ── Swap Button ────────────────────────────────────────────
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () => ref.read(currencyConverterProvider.notifier).swapCurrencies(),
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 44, height: 44,
                              alignment: Alignment.center,
                              child: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── To Currency Card ───────────────────────────────────────
                    _CurrencyCard(
                      label: 'Converted',
                      currencyCode: state.toCurrency,
                      displayValue: state.convertedAmount,
                      onCurrencyTap: () => _showCurrencyPicker(context, isFrom: false),
                      editable: false,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Rate Info ──────────────────────────────────────────────
                    if (state.exchangeRate != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.base),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(AppRadius.base),
                          border: Border.all(color: AppColors.darkBorder, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.trending_flat_rounded, size: 18, color: AppColors.darkTextTertiary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                '1 ${state.fromCurrency} = ${state.exchangeRate!.toStringAsFixed(4)} ${state.toCurrency}',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary),
                              ),
                            ),
                            if (state.rates != null)
                              Text(
                                state.rates!.isStale ? 'Cached' : 'Live',
                                style: AppTypography.labelSmall.copyWith(
                                  color: state.rates!.isStale ? AppColors.warning : AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Quick Amount Chips ────────────────────────────────────
                    Text('Quick Amount', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [10, 50, 100, 500, 1000].map((amount) {
                        return GestureDetector(
                          onTap: () {
                            _amountController.text = amount.toString();
                            ref.read(currencyConverterProvider.notifier).setAmount(amount.toDouble());
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.darkCardElevated,
                              borderRadius: BorderRadius.circular(AppRadius.full),
                              border: Border.all(color: AppColors.darkBorder, width: 0.5),
                            ),
                            child: Text(amount.toString(), style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextSecondary)),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Popular Currencies Grid ────────────────────────────────
                    Text('Popular Currencies', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.sm),
                    if (state.rates != null)
                      ...CommonCurrencies.all.where((c) => c.code != state.fromCurrency).take(6).map((currency) {
                        final rate = state.rates!.convert(state.fromCurrency, currency.code, 1);
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.darkCard,
                            borderRadius: BorderRadius.circular(AppRadius.base),
                            border: Border.all(color: AppColors.darkBorder, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Text(currency.flag, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(currency.code, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
                                    Text(currency.name, style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
                                  ],
                                ),
                              ),
                              Text(
                                rate != null ? rate.toStringAsFixed(4) : '—',
                                style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
    );
  }

  void _showCurrencyPicker(BuildContext context, {required bool isFrom}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet))),
      builder: (context) => _CurrencyPickerSheet(
        onSelect: (code) {
          if (isFrom) {
            ref.read(currencyConverterProvider.notifier).setFromCurrency(code);
          } else {
            ref.read(currencyConverterProvider.notifier).setToCurrency(code);
          }
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ─── Currency Card ─────────────────────────────────────────────────────────────

class _CurrencyCard extends StatelessWidget {
  final String label;
  final String currencyCode;
  final TextEditingController? controller;
  final double? displayValue;
  final ValueChanged<String>? onChanged;
  final VoidCallback onCurrencyTap;
  final bool editable;

  const _CurrencyCard({
    required this.label,
    required this.currencyCode,
    this.controller,
    this.displayValue,
    this.onChanged,
    required this.onCurrencyTap,
    required this.editable,
  });

  @override
  Widget build(BuildContext context) {
    final currency = CommonCurrencies.byCode(currencyCode);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextTertiary)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: editable
                    ? TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: onChanged,
                        style: AppTypography.amountHero.copyWith(color: AppColors.darkTextPrimary, fontSize: 36),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          displayValue != null ? NumberFormat('#,##0.00').format(displayValue) : '—',
                          style: AppTypography.amountHero.copyWith(color: AppColors.primary, fontSize: 36),
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Material(
                color: AppColors.darkCardElevated,
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: InkWell(
                  onTap: onCurrencyTap,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(currency.flag, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: AppSpacing.xs),
                        Text(currency.code, style: AppTypography.labelLarge.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 2),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.darkTextTertiary, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Currency Picker Sheet ──────────────────────────────────────────────────────

class _CurrencyPickerSheet extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _CurrencyPickerSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Currency', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.base),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: CommonCurrencies.all.length,
                itemBuilder: (context, i) {
                  final currency = CommonCurrencies.all[i];
                  return ListTile(
                    leading: Text(currency.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(currency.code, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(currency.name, style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
                    onTap: () => onSelect(currency.code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

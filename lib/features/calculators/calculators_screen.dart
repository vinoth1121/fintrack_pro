import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/fintrack_provider.dart';
import 'basic_calculator_engine.dart';

/// Calculator Hub — Basic / EMI / GST / Savings Goal / Split Bill.
/// Written from scratch: every tab here is a fresh, self-contained
/// implementation with no dependency on any prior calculator code.
class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key});

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen> {
  int _tab = 0;

  static const _tabs = [
    ('Basic', Icons.calculate_outlined),
    ('EMI', Icons.account_balance_outlined),
    ('GST', Icons.receipt_long_outlined),
    ('Savings', Icons.savings_outlined),
    ('Split Bill', Icons.groups_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            scrollDirection: Axis.horizontal,
            itemCount: _tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final selected = _tab == i;
              final (label, icon) = _tabs[i];
              return _TabChip(
                label: label,
                icon: icon,
                selected: selected,
                onTap: () => setState(() => _tab = i),
              );
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            sizing: StackFit.expand,
            children: const [
              _BasicCalculatorTab(),
              _EmiCalculatorTab(),
              _GstCalculatorTab(),
              _SavingsCalculatorTab(),
              _SplitBillCalculatorTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : l.surface2.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(22),
          border: selected ? null : Border.all(color: l.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : l.mutedForeground),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.label(context, size: 13).copyWith(
                color: selected ? Colors.white : l.foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// BASIC CALCULATOR
// ─────────────────────────────────────────────────────────────────────────

class _BasicCalculatorTab extends StatefulWidget {
  const _BasicCalculatorTab();

  @override
  State<_BasicCalculatorTab> createState() => _BasicCalculatorTabState();
}

class _BasicCalculatorTabState extends State<_BasicCalculatorTab> {
  final _engine = BasicCalculatorEngine();
  String? _flashError;

  void _press(VoidCallback action) {
    HapticFeedback.selectionClick();
    setState(() {
      _flashError = null;
      action();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          // Display
          Expanded(
            flex: 3,
            child: GlassCard(
              strong: true,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 22,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _engine.expressionPreview,
                        style: AppTypography.body(context, size: 15).copyWith(color: l.mutedForeground),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _engine.display,
                      style: AppTypography.display(context, size: 52, weight: FontWeight.w600),
                    ),
                  ),
                  if (_flashError != null) ...[
                    const SizedBox(height: 6),
                    Text(_flashError!, style: AppTypography.body(context, size: 12).copyWith(color: AppColors.error)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Button grid
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _row([
                  _btn('AC', onTap: () => _press(_engine.clearAll), kind: _KeyKind.util),
                  _btn('⌫', onTap: () => _press(_engine.backspace), kind: _KeyKind.util),
                  _btn('%', onTap: () => _press(_engine.inputPercent), kind: _KeyKind.util),
                  _btn('÷', onTap: () => _press(() => _engine.inputOperator('÷')), kind: _KeyKind.op),
                ]),
                _row([
                  _btn('7', onTap: () => _press(() => _engine.inputDigit('7'))),
                  _btn('8', onTap: () => _press(() => _engine.inputDigit('8'))),
                  _btn('9', onTap: () => _press(() => _engine.inputDigit('9'))),
                  _btn('×', onTap: () => _press(() => _engine.inputOperator('×')), kind: _KeyKind.op),
                ]),
                _row([
                  _btn('4', onTap: () => _press(() => _engine.inputDigit('4'))),
                  _btn('5', onTap: () => _press(() => _engine.inputDigit('5'))),
                  _btn('6', onTap: () => _press(() => _engine.inputDigit('6'))),
                  _btn('−', onTap: () => _press(() => _engine.inputOperator('−')), kind: _KeyKind.op),
                ]),
                _row([
                  _btn('1', onTap: () => _press(() => _engine.inputDigit('1'))),
                  _btn('2', onTap: () => _press(() => _engine.inputDigit('2'))),
                  _btn('3', onTap: () => _press(() => _engine.inputDigit('3'))),
                  _btn('+', onTap: () => _press(() => _engine.inputOperator('+')), kind: _KeyKind.op),
                ]),
                _row([
                  _btn('±', onTap: () => _press(_engine.toggleSign)),
                  _btn('0', onTap: () => _press(() => _engine.inputDigit('0'))),
                  _btn('.', onTap: () => _press(_engine.inputDecimal)),
                  _btn('=', onTap: () => _press(() { _flashError = _engine.equals(); }), kind: _KeyKind.equals),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(List<Widget> children) => Expanded(
    child: Row(children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.all(5), child: c))).toList()),
  );

  Widget _btn(String label, {required VoidCallback onTap, _KeyKind kind = _KeyKind.digit}) {
    return _CalcKey(label: label, onTap: onTap, kind: kind);
  }
}

enum _KeyKind { digit, op, util, equals }

class _CalcKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final _KeyKind kind;
  const _CalcKey({required this.label, required this.onTap, required this.kind});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    Color bg;
    Color fg;
    Gradient? gradient;
    switch (kind) {
      case _KeyKind.digit:
        bg = l.surface2.withValues(alpha: 0.7);
        fg = l.foreground;
        gradient = null;
      case _KeyKind.util:
        bg = l.surface3.withValues(alpha: 0.85);
        fg = AppColors.iris;
        gradient = null;
      case _KeyKind.op:
        bg = AppColors.iris.withValues(alpha: 0.16);
        fg = AppColors.iris;
        gradient = null;
      case _KeyKind.equals:
        bg = Colors.transparent;
        fg = Colors.white;
        gradient = AppColors.brandGradient;
    }
    return Material(
      color: gradient == null ? bg : null,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Center(
            child: Text(label, style: AppTypography.heading(context, size: 22).copyWith(color: fg)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared numeric input field for the financial calculators
// ─────────────────────────────────────────────────────────────────────────

class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? suffix;
  final ValueChanged<String>? onChanged;
  const _NumField({required this.label, required this.controller, this.suffix, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  const _ResultRow({required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground)),
          Text(
            value,
            style: emphasize
                ? AppTypography.heading(context, size: 20).copyWith(color: AppColors.iris)
                : AppTypography.heading(context, size: 15),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// EMI CALCULATOR
// ─────────────────────────────────────────────────────────────────────────

class _EmiCalculatorTab extends ConsumerStatefulWidget {
  const _EmiCalculatorTab();
  @override
  ConsumerState<_EmiCalculatorTab> createState() => _EmiCalculatorTabState();
}

class _EmiCalculatorTabState extends ConsumerState<_EmiCalculatorTab> {
  final _principal = TextEditingController(text: '500000');
  final _rate = TextEditingController(text: '10.5');
  final _tenure = TextEditingController(text: '36');

  @override
  void dispose() {
    _principal.dispose();
    _rate.dispose();
    _tenure.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(fintrackProvider.select((s) => s.profile.baseCurrency));
    final p = double.tryParse(_principal.text) ?? 0;
    final annualRate = double.tryParse(_rate.text) ?? 0;
    final months = int.tryParse(_tenure.text) ?? 0;

    double emi = 0, totalPayment = 0, totalInterest = 0;
    if (p > 0 && months > 0) {
      if (annualRate <= 0) {
        emi = p / months;
      } else {
        final r = annualRate / 12 / 100;
        final factor = _pow(1 + r, months);
        emi = p * r * factor / (factor - 1);
      }
      totalPayment = emi * months;
      totalInterest = totalPayment - p;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Loan EMI Calculator', subtitle: 'Estimate your monthly instalment'),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NumField(label: 'Loan amount', controller: _principal, suffix: currency, onChanged: (_) => setState(() {})),
                const SizedBox(height: 12),
                _NumField(label: 'Interest rate (annual)', controller: _rate, suffix: '%', onChanged: (_) => setState(() {})),
                const SizedBox(height: 12),
                _NumField(label: 'Tenure', controller: _tenure, suffix: 'months', onChanged: (_) => setState(() {})),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            strong: true,
            child: Column(
              children: [
                _ResultRow(label: 'Monthly EMI', value: formatMoney(emi, currency), emphasize: true),
                const Divider(height: 20),
                _ResultRow(label: 'Total interest', value: formatMoney(totalInterest, currency)),
                _ResultRow(label: 'Total payment', value: formatMoney(totalPayment, currency)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _pow(double base, int exp) {
    double result = 1;
    for (var i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// GST CALCULATOR
// ─────────────────────────────────────────────────────────────────────────

class _GstCalculatorTab extends ConsumerStatefulWidget {
  const _GstCalculatorTab();
  @override
  ConsumerState<_GstCalculatorTab> createState() => _GstCalculatorTabState();
}

class _GstCalculatorTabState extends ConsumerState<_GstCalculatorTab> {
  final _amount = TextEditingController(text: '1000');
  final _rate = TextEditingController(text: '18');
  bool _inclusive = false; // false = add GST on top, true = extract GST from an inclusive amount

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(fintrackProvider.select((s) => s.profile.baseCurrency));
    final amount = double.tryParse(_amount.text) ?? 0;
    final rate = double.tryParse(_rate.text) ?? 0;

    double net, gst, total;
    if (_inclusive) {
      net = amount / (1 + rate / 100);
      gst = amount - net;
      total = amount;
    } else {
      net = amount;
      gst = amount * rate / 100;
      total = amount + gst;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'GST Calculator', subtitle: 'Add GST, or extract it from an inclusive price'),
          const SizedBox(height: 14),
          GlassCard(
            child: Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: 'Add GST',
                    selected: !_inclusive,
                    onTap: () => setState(() => _inclusive = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    label: 'Remove GST',
                    selected: _inclusive,
                    onTap: () => setState(() => _inclusive = true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NumField(
                  label: _inclusive ? 'Amount (GST inclusive)' : 'Amount (before GST)',
                  controller: _amount,
                  suffix: currency,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _NumField(label: 'GST rate', controller: _rate, suffix: '%', onChanged: (_) => setState(() {})),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            strong: true,
            child: Column(
              children: [
                _ResultRow(label: 'GST amount', value: formatMoney(gst, currency), emphasize: true),
                const Divider(height: 20),
                _ResultRow(label: 'Net amount', value: formatMoney(net, currency)),
                _ResultRow(label: 'Total amount', value: formatMoney(total, currency)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : l.surface2,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.label(context, size: 13).copyWith(
            color: selected ? Colors.white : l.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SAVINGS GOAL CALCULATOR
// ─────────────────────────────────────────────────────────────────────────

class _SavingsCalculatorTab extends ConsumerStatefulWidget {
  const _SavingsCalculatorTab();
  @override
  ConsumerState<_SavingsCalculatorTab> createState() => _SavingsCalculatorTabState();
}

class _SavingsCalculatorTabState extends ConsumerState<_SavingsCalculatorTab> {
  final _target = TextEditingController(text: '100000');
  final _current = TextEditingController(text: '10000');
  final _monthly = TextEditingController(text: '5000');

  @override
  void dispose() {
    _target.dispose();
    _current.dispose();
    _monthly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(fintrackProvider.select((s) => s.profile.baseCurrency));
    final target = double.tryParse(_target.text) ?? 0;
    final current = double.tryParse(_current.text) ?? 0;
    final monthly = double.tryParse(_monthly.text) ?? 0;

    final remaining = (target - current).clamp(0, double.infinity);
    int? monthsNeeded;
    if (monthly > 0 && remaining > 0) {
      monthsNeeded = (remaining / monthly).ceil();
    } else if (remaining <= 0) {
      monthsNeeded = 0;
    }

    final years = monthsNeeded == null ? null : monthsNeeded ~/ 12;
    final leftoverMonths = monthsNeeded == null ? null : monthsNeeded % 12;
    final targetDate = monthsNeeded == null
        ? null
        : DateTime.now().add(Duration(days: (monthsNeeded * 30.44).round()));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Savings Goal Calculator', subtitle: 'How long until you hit your target?'),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NumField(label: 'Target amount', controller: _target, suffix: currency, onChanged: (_) => setState(() {})),
                const SizedBox(height: 12),
                _NumField(label: 'Current savings', controller: _current, suffix: currency, onChanged: (_) => setState(() {})),
                const SizedBox(height: 12),
                _NumField(label: 'Monthly contribution', controller: _monthly, suffix: currency, onChanged: (_) => setState(() {})),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            strong: true,
            child: Column(
              children: [
                _ResultRow(
                  label: 'Time to reach goal',
                  value: monthsNeeded == null
                      ? '—'
                      : monthsNeeded == 0
                          ? 'Goal already reached'
                          : '${years! > 0 ? '${years}y ' : ''}${leftoverMonths}mo',
                  emphasize: true,
                ),
                const Divider(height: 20),
                _ResultRow(label: 'Remaining amount', value: formatMoney(remaining.toDouble(), currency)),
                if (targetDate != null && monthsNeeded! > 0)
                  _ResultRow(label: 'Estimated date', value: formatDate(targetDate, style: 'long')),
              ],
            ),
          ),
          if (monthly <= 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Enter a monthly contribution greater than zero to estimate a timeline.',
                style: AppTypography.body(context, size: 12).copyWith(color: context.lumina.mutedForeground),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SPLIT BILL CALCULATOR
// ─────────────────────────────────────────────────────────────────────────

class _SplitBillCalculatorTab extends ConsumerStatefulWidget {
  const _SplitBillCalculatorTab();
  @override
  ConsumerState<_SplitBillCalculatorTab> createState() => _SplitBillCalculatorTabState();
}

class _SplitBillCalculatorTabState extends ConsumerState<_SplitBillCalculatorTab> {
  final _total = TextEditingController(text: '2400');
  final _tip = TextEditingController(text: '10');
  int _people = 4;

  @override
  void dispose() {
    _total.dispose();
    _tip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(fintrackProvider.select((s) => s.profile.baseCurrency));
    final total = double.tryParse(_total.text) ?? 0;
    final tipPct = double.tryParse(_tip.text) ?? 0;
    final tipAmount = total * tipPct / 100;
    final grandTotal = total + tipAmount;
    final perPerson = _people > 0 ? grandTotal / _people : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Split Bill Calculator', subtitle: 'Split a bill with tip, evenly'),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NumField(label: 'Bill total', controller: _total, suffix: currency, onChanged: (_) => setState(() {})),
                const SizedBox(height: 12),
                _NumField(label: 'Tip', controller: _tip, suffix: '%', onChanged: (_) => setState(() {})),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Split between', style: AppTypography.body(context, size: 13).copyWith(color: context.lumina.mutedForeground)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _people > 1 ? () => setState(() => _people--) : null,
                        ),
                        SizedBox(
                          width: 32,
                          child: Text('$_people', textAlign: TextAlign.center, style: AppTypography.heading(context, size: 16)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => _people++),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            strong: true,
            child: Column(
              children: [
                _ResultRow(label: 'Each person pays', value: formatMoney(perPerson, currency), emphasize: true),
                const Divider(height: 20),
                _ResultRow(label: 'Tip amount', value: formatMoney(tipAmount, currency)),
                _ResultRow(label: 'Grand total', value: formatMoney(grandTotal, currency)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

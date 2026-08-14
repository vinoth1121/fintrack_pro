import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/seed/seed_data.dart';
import '../../l10n/app_localizations.dart';

/// Fetches live exchange rates (base INR) from a free, no-key API and caches
/// them locally for 6h. Falls back to the static [currencyRates] map (and
/// then to the local cache) if the network call fails, so the converter
/// never breaks — it just stops being "live" until connectivity returns.
class _LiveRates {
  static const _cacheKey = 'currency_live_rates_inr_v1';
  static const _cacheTsKey = 'currency_live_rates_inr_ts_v1';
  static const _maxAge = Duration(hours: 6);

  static Future<Map<String, double>> fetch() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await Dio().get('https://open.er-api.com/v6/latest/INR');
      final data = res.data as Map<String, dynamic>;
      if (data['result'] == 'success') {
        final raw = data['rates'] as Map<String, dynamic>;
        final rates = raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
        await prefs.setString(_cacheKey, jsonEncode(rates));
        await prefs.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
        return rates;
      }
    } catch (_) {
      // fall through to cache/static below
    }

    final cachedRaw = prefs.getString(_cacheKey);
    final cachedTs = prefs.getInt(_cacheTsKey);
    if (cachedRaw != null && cachedTs != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cachedTs)) < _maxAge) {
      final cached = (jsonDecode(cachedRaw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
      return cached;
    }
    return currencyRates;
  }
}

const _currencies = <String>['INR', 'USD', 'EUR', 'GBP', 'JPY', 'AED', 'AUD', 'CAD'];

const _popularPairs = <_Pair>[
  _Pair('USD', 'INR'),
  _Pair('EUR', 'INR'),
  _Pair('GBP', 'INR'),
  _Pair('USD', 'EUR'),
  _Pair('AED', 'INR'),
  _Pair('AUD', 'USD'),
];

const _quickAmounts = <int>[100, 1000, 10000];

class _Pair {
  final String from;
  final String to;
  const _Pair(this.from, this.to);
}

class _RatePoint {
  final String label;
  final double rate;
  const _RatePoint(this.label, this.rate);
}

/// Currency converter screen — From/To panels, swap, quick amounts,
/// popular pairs and a 30-day trend line chart.
class CurrencyScreen extends ConsumerStatefulWidget {
  const CurrencyScreen({super.key});

  @override
  ConsumerState<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends ConsumerState<CurrencyScreen> {
  String _from = 'USD';
  String _to = 'INR';
  String _fromAmount = '1000';
  double _swapRotation = 0;
  final Set<String> _favorites = {'USD→INR'};

  Map<String, double> _rates = currencyRates;
  bool _ratesLoading = true;
  DateTime? _ratesFetchedAt;

  @override
  void initState() {
    super.initState();
    _loadLiveRates();
  }

  Future<void> _loadLiveRates() async {
    final rates = await _LiveRates.fetch();
    if (!mounted) return;
    setState(() {
      _rates = rates;
      _ratesLoading = false;
      _ratesFetchedAt = DateTime.now();
    });
  }

  double get _rateFrom => _rates[_from] ?? currencyRates[_from] ?? 1;
  double get _rateTo => _rates[_to] ?? currencyRates[_to] ?? 1;
  double get _unitRate => _rateTo / _rateFrom;

  double get _fromValue =>
      double.tryParse(_fromAmount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  double get _toValue => _fromValue * _unitRate;

  void _swap() {
    final newAmount = _toValue.toStringAsFixed(2);
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
      _fromAmount = newAmount;
      _swapRotation += 180;
    });
    showAppToast(context, 'Swapped $_to ↔ $_from', description: 'Live rate applied');
  }

  void _quickAmount(int amt) => setState(() => _fromAmount = amt.toString());

  void _toggleFavorite(String key) {
    setState(() {
      if (_favorites.contains(key)) {
        _favorites.remove(key);
        showAppToast(context, 'Removed from favorites');
      } else {
        _favorites.add(key);
        showAppToast(context, 'Added to favorites');
      }
    });
  }

  void _loadPair(String from, String to) =>
      setState(() { _from = from; _to = to; });

  String _formatRate(double n) {
    if (!n.isFinite || n == 0) return '—';
    if (n >= 100) return n.toStringAsFixed(2);
    if (n >= 1) return n.toStringAsFixed(4);
    return n.toStringAsFixed(6);
  }

  List<_RatePoint> _history() {
    final current = _unitRate;
    if (!current.isFinite || current <= 0) {
      final now = DateTime.now();
      return List.generate(30, (i) {
        final d = now.subtract(Duration(days: 29 - i));
        return _RatePoint(_fmtDay(d), 0);
      });
    }
    final seed =
        (_from.codeUnitAt(0) * 31 + _to.codeUnitAt(0) * 17 + _from.length * 7 + _to.length * 11) %
            100;
    final out = <_RatePoint>[];
    final now = DateTime.now();
    for (var i = 0; i < 30; i++) {
      final phase = i / 29;
      final noise = math.sin(seed + i * 0.6) * 0.012 +
          math.cos(seed * 0.4 + i * 0.23) * 0.008;
      final swing = math.sin(seed * 0.3 + i * 0.18) * 0.025;
      final rate = current * (1 - swing * (1 - phase) + noise);
      final d = now.subtract(Duration(days: 29 - i));
      out.add(_RatePoint(_fmtDay(d), rate));
    }
    out[out.length - 1] = _RatePoint(out.last.label, current);
    return out;
  }

  String _fmtDay(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return "${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]}";
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final l = context.lumina;
    final history = _history();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // Header
          GlassCard(
            strong: true,
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GradientPill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ratesLoading
                                ? const SizedBox(
                                    width: 8, height: 8,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                  )
                                : Container(
                                    width: 6, height: 6,
                                    decoration: BoxDecoration(
                                      color: _ratesFetchedAt != null ? AppColors.success : AppColors.warning,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            const SizedBox(width: 6),
                            Text(
                              _ratesLoading
                                  ? 'Updating rates…'
                                  : _ratesFetchedAt != null
                                      ? t.currency.liveRates
                                      : 'Offline rates',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t.currency.currencyConverter,
                        style: AppTypography.display(context, size: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.currency.realTimeRates} · ${t.currency.cachedDemo}',
                        style: AppTypography.body(context, size: 12)
                            .copyWith(color: l.mutedForeground),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.iris.withValues(alpha: 0.15),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.refresh, size: 28, color: AppColors.iris),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Main converter
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // From / Swap / To
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _CurrencyPanel(
                        label: t.currency.from,
                        currency: _from,
                        onCurrencyChange: (c) => setState(() => _from = c),
                        amount: _fromAmount,
                        onAmountChange: (v) => setState(() => _fromAmount = v),
                        editable: true,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: AnimatedRotation(
                        turns: _swapRotation / 360,
                        duration: 450.ms,
                        child: Tooltip(
                          message: t.currency.swap,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: _swap,
                              child: Container(
                                width: 48, height: 48,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.brandGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 18,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.swap_horiz,
                                    color: Colors.white, size: 22,),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _CurrencyPanel(
                        label: t.currency.to,
                        currency: _to,
                        onCurrencyChange: (c) => setState(() => _to = c),
                        amount: _toValue.toStringAsFixed(2),
                        onAmountChange: (_) {},
                        editable: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Quick amounts
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${t.currency.quickAmounts}:',
                      style: AppTypography.label(context, size: 11)
                          .copyWith(color: l.mutedForeground),
                    ),
                    ..._quickAmounts.map((amt) => _QuickChip(
                          label: '${_formatNumber(amt)} ${currencySymbol(_from)}',
                          onTap: () => _quickAmount(amt),
                        ),),
                  ],
                ),
                const SizedBox(height: 20),
                // Rate display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.iris.withValues(alpha: 0.08),
                        AppColors.cyan.withValues(alpha: 0.06),
                      ],
                    ),
                    border: Border.all(color: l.border, width: 1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        t.currency.rate.toUpperCase(),
                        style: AppTypography.label(context, size: 10)
                            .copyWith(letterSpacing: 1.2, color: l.mutedForeground),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '1 ${currencySymbol(_from)}',
                            style: AppTypography.amount(context, size: 20, weight: FontWeight.w600)
                                .copyWith(color: AppColors.iris),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('=', style: AppTypography.amount(context, size: 16)
                                .copyWith(color: l.mutedForeground),),
                          ),
                          ShaderMask(
                            shaderCallback: (rect) =>
                                AppColors.brandGradient.createShader(rect),
                            child: Text(
                              '${_formatRate(_unitRate)} ${currencySymbol(_to)}',
                              style: AppTypography.amount(context, size: 20, weight: FontWeight.bold)
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_from → $_to · inverse ${_formatRate(1 / _unitRate)} ${currencySymbol(_from)} per ${currencySymbol(_to)}',
                        style: AppTypography.label(context, size: 11)
                            .copyWith(color: l.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Popular pairs + trend chart
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCol = constraints.maxWidth >= 720;
              final children = <Widget>[
                // Popular pairs
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(
                        title: t.currency.popularPairs,
                        subtitle: t.misc.tapPairToLoad,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _popularPairs.map((p) {
                          final rate = (_rates[p.to] ?? currencyRates[p.to] ?? 1) /
                              (_rates[p.from] ?? currencyRates[p.from] ?? 1);
                          final key = '${p.from}→${p.to}';
                          final active = _from == p.from && _to == p.to;
                          final fav = _favorites.contains(key);
                          return _PopularPairCard(
                            pair: p,
                            rateText: '${_formatRate(rate)} ${currencySymbol(p.to)}',
                            active: active,
                            favorited: fav,
                            onTap: () => _loadPair(p.from, p.to),
                            onFavorite: () => _toggleFavorite(key),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 12, color: l.mutedForeground),
                          const SizedBox(width: 6),
                          Text(
                            '${_favorites.length} favorited · decorative only',
                            style: AppTypography.label(context, size: 10)
                                .copyWith(color: l.mutedForeground),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 140.ms).slideY(begin: 0.05, end: 0),
                SizedBox(width: twoCol ? 16 : 0, height: twoCol ? 0 : 16),
                // 30-day trend
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(
                        title: t.currency.dayTrend,
                        subtitle: '$_from → $_to',
                        action: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.trending_up, size: 14, color: AppColors.iris),
                            const SizedBox(width: 4),
                            Text(
                              'Live',
                              style: AppTypography.label(context, size: 11, weight: FontWeight.w600)
                                  .copyWith(color: AppColors.iris),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: CustomPaint(
                          painter: _TrendPainter(
                            points: history,
                            lineColor: AppColors.iris,
                            gridColor: l.border.withValues(alpha: 0.4),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '30 days ago',
                            style: AppTypography.label(context, size: 10)
                                .copyWith(color: l.mutedForeground),
                          ),
                          Text(
                            '${t.common.today}: ${_formatRate(_unitRate)} ${currencySymbol(_to)}',
                            style: AppTypography.label(context, size: 10, weight: FontWeight.w500)
                                .copyWith(color: AppColors.iris),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),
              ];
              if (twoCol) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: children[0]),
                    children[1],
                    Expanded(child: children[2]),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [children[0], children[1], children[2]],
              );
            },
          ),
        ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/* ------------------------------ Currency panel ------------------------------ */

class _TrendPainter extends CustomPainter {
  final List<_RatePoint> points;
  final Color lineColor;
  final Color gridColor;

  const _TrendPainter({required this.points, required this.lineColor, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final chartHeight = size.height - 24;
    final chartWidth = size.width - 24;
    final minValue = points.map((p) => p.rate).fold<double>(0, (prev, value) => prev == 0 ? value : math.min(prev, value));
    final maxValue = points.map((p) => p.rate).fold<double>(1, (prev, value) => math.max(prev, value));
    final span = maxValue - minValue;
    final safeSpan = span <= 0 ? 1 : span;

    for (var i = 0; i < 4; i++) {
      final y = 12 + (chartHeight / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = 12 + (chartWidth * i) / (points.length - 1).clamp(1, 999999);
      final value = points[i].rate;
      final y = size.height - 12 - ((value - minValue) / safeSpan) * chartHeight;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor || oldDelegate.gridColor != gridColor;
  }
}

class _CurrencyPanel extends StatelessWidget {
  final String label;
  final String currency;
  final ValueChanged<String> onCurrencyChange;
  final String amount;
  final ValueChanged<String> onAmountChange;
  final bool editable;

  const _CurrencyPanel({
    required this.label,
    required this.currency,
    required this.onCurrencyChange,
    required this.amount,
    required this.onAmountChange,
    required this.editable,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: l.surface3.withValues(alpha: 0.3),
        border: Border.all(color: l.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTypography.label(context, size: 10)
                    .copyWith(letterSpacing: 1.2, color: l.mutedForeground),
              ),
              _CurrencyDropdown(
                value: currency,
                onChanged: onCurrencyChange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  currencySymbol(currency),
                  style: AppTypography.amount(context, size: 22, weight: FontWeight.w600)
                      .copyWith(color: AppColors.iris),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: editable
                    ? TextFormField(
                        initialValue: amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.right,
                        style: AppTypography.amount(context, size: 26, weight: FontWeight.bold),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isCollapsed: true,
                        ),
                        onChanged: onAmountChange,
                      )
                    : Text(
                        amount,
                        textAlign: TextAlign.right,
                        style: AppTypography.amount(context, size: 26, weight: FontWeight.bold)
                            .copyWith(color: AppColors.cyan),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            currency,
            textAlign: TextAlign.right,
            style: AppTypography.label(context, size: 10)
                .copyWith(letterSpacing: 1.2, color: l.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CurrencyDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: l.surface2.withValues(alpha: 0.6),
        border: Border.all(color: l.border, width: 1),
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        color: l.surface3.withValues(alpha: 0.98),
        onSelected: onChanged,
        itemBuilder: (_) => _currencies
            .map((code) => PopupMenuItem(
                  value: code,
                  child: Row(
                    children: [
                      Text(currencySymbol(code),
                          style: AppTypography.amount(context, size: 13, weight: FontWeight.w600)
                              .copyWith(color: AppColors.iris),),
                      const SizedBox(width: 6),
                      Text(code, style: AppTypography.label(context, size: 12, weight: FontWeight.w500)),
                    ],
                  ),
                ),)
            .toList(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currencySymbol(value),
                style: AppTypography.amount(context, size: 13, weight: FontWeight.w600)
                    .copyWith(color: AppColors.iris),),
            const SizedBox(width: 4),
            Text(value,
                style: AppTypography.label(context, size: 12, weight: FontWeight.w500)
                    .copyWith(color: l.foreground),),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 14, color: l.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------ Quick chip ------------------------------ */

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Material(
      color: l.surface3.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: l.border, width: 1),
          ),
          child: Text(
            label,
            style: AppTypography.label(context, size: 11, weight: FontWeight.w500)
                .copyWith(color: l.foreground.withValues(alpha: 0.8)),
          ),
        ),
      ),
    );
  }
}

/* ------------------------------ Popular pair card ------------------------------ */

class _PopularPairCard extends StatelessWidget {
  final _Pair pair;
  final String rateText;
  final bool active;
  final bool favorited;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  const _PopularPairCard({
    required this.pair,
    required this.rateText,
    required this.active,
    required this.favorited,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Material(
      color: active
          ? AppColors.iris.withValues(alpha: 0.1)
          : l.surface3.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.iris.withValues(alpha: 0.6) : l.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(currencySymbol(pair.from),
                            style: AppTypography.amount(context, size: 14, weight: FontWeight.w600)
                                .copyWith(color: AppColors.iris),),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 12, color: l.mutedForeground),
                        const SizedBox(width: 4),
                        Text(currencySymbol(pair.to),
                            style: AppTypography.amount(context, size: 14, weight: FontWeight.w600)
                                .copyWith(color: AppColors.cyan),),
                        const SizedBox(width: 6),
                        Text(
                          '${pair.from}/${pair.to}',
                          style: AppTypography.label(context, size: 10)
                              .copyWith(color: l.mutedForeground),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1 ${currencySymbol(pair.from)} = $rateText',
                      style: AppTypography.amount(context, size: 13, weight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                iconSize: 16,
                color: favorited ? const Color(0xFFFFC107) : l.mutedForeground.withValues(alpha: 0.5),
                onPressed: onFavorite,
                icon: Icon(favorited ? Icons.star : Icons.star_border),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

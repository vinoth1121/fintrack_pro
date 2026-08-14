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

/// AI Insights — mirrors the web app's `views/insights.tsx`.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  InsightsPayload? _data;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Defer to after first build so ref is available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final s = ref.read(fintrackProvider);
    final currency = s.profile.baseCurrency;
    final nameMap = <String, String>{for (final c in s.categories) c.id: c.name};
    try {
      final payload = await AiRepository.insights(
        transactions: s.transactions,
        budgets: s.budgets,
        goals: s.goals,
        currency: currency,
        categoryNameMap: nameMap,
      );
      if (payload == null) {
        setState(() {
          _error = ref.read(tProvider).messages.aiRequestFailed;
          _loading = false;
        });
        return;
      }
      setState(() {
        _data = payload;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = ref.read(tProvider).messages.networkError;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final state = ref.watch(fintrackProvider);
    final d = ref.watch(derivedProvider);
    final currency = state.profile.baseCurrency;

    final health = financialHealthScore(
      income: d.monthIncome,
      expenses: d.monthExpenses,
      budgetsOver: d.budgetsOver,
      budgetsTotal: d.budgetUsage.length,
      goalsOnTrack: d.goalsOnTrack,
      goalsTotal: d.goalsTotal,
    );
    final healthColor = health.score >= 70
        ? AppColors.success
        : health.score >= 50
            ? AppColors.warning
            : AppColors.error;
    final gradeLabel = _gradeLabel(health.label, t);
    final gradeTitle = '${t.analytics.grade} ${health.grade} · $gradeLabel';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _HealthHero(
                    score: health.score,
                    gradeTitle: gradeTitle,
                    healthColor: healthColor,
                    pill: t.insights.aiFinancialInsights,
                    description:
                        'Your financial health blends savings rate, budget adherence, and goal progress. Lumina analyzes your patterns and surfaces personalized actions.',
                    savingsRate: d.savingsRate,
                    budgetsOnTrack: d.budgetUsage.length - d.budgetsOver,
                    budgetsTotal: d.budgetUsage.length,
                    goalsOnTrack: d.goalsOnTrack,
                    goalsTotal: d.goalsTotal,
                    onRefresh: _load,
                    loading: _loading,
                    refreshLabel: t.insights.refresh,
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                ),
              ),
              if (_data != null) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _PanelsRow(
                      t: t,
                      currency: currency,
                      data: _data!,
                    ).animate().fadeIn(delay: 80.ms, duration: 400.ms).slideY(begin: 0.05),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _InsightCardsSection(
                    t: t,
                    currency: currency,
                    data: _data,
                    loading: _loading,
                    error: _error,
                    onRetry: _load,
                    onSaveAsNotification: () {
                      ref.read(fintrackProvider.notifier).pushNotification(
                            AppNotification(
                              id: uid('nt_'),
                              title: 'AI Insights refreshed',
                              body:
                                  'Lumina generated a fresh batch of personalized financial insights.',
                              kind: NotificationKind.ai,
                              read: false,
                              createdAt: DateTime.now(),
                              action: const NotificationAction(
                                  label: 'View', view: 'insights',),
                            ),
                          );
                      showAppToast(context, 'Insights refreshed',
                          kind: ToastKind.success,);
                    },
                  ).animate().fadeIn(delay: 160.ms, duration: 400.ms).slideY(begin: 0.05),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  String _gradeLabel(String label, AppT t) {
    switch (label) {
      case 'Excellent':
        return t.analytics.excellent;
      case 'Great':
        return t.analytics.great;
      case 'Good':
        return t.analytics.good;
      case 'Fair':
        return t.analytics.fair;
      default:
        return t.analytics.needsWork;
    }
  }
}

class _HealthHero extends StatelessWidget {
  final int score;
  final String gradeTitle;
  final Color healthColor;
  final String pill, description;
  final double savingsRate;
  final int budgetsOnTrack, budgetsTotal, goalsOnTrack, goalsTotal;
  final VoidCallback onRefresh;
  final bool loading;
  final String refreshLabel;

  const _HealthHero({
    required this.score,
    required this.gradeTitle,
    required this.healthColor,
    required this.pill,
    required this.description,
    required this.savingsRate,
    required this.budgetsOnTrack,
    required this.budgetsTotal,
    required this.goalsOnTrack,
    required this.goalsTotal,
    required this.onRefresh,
    required this.loading,
    required this.refreshLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return GlassCard(
      strong: true,
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.iris.withValues(alpha: 0.25),
                  Colors.transparent,
                ],),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProgressRing(
                value: score.toDouble(),
                size: 120,
                stroke: 11,
                color: healthColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score',
                        style: AppTypography.amount(context,
                                size: 26, weight: FontWeight.bold,)
                            .copyWith(height: 1.0),),
                    Text('/ 100',
                        style: AppTypography.label(context, size: 9)
                            .copyWith(
                                color: l.mutedForeground,
                                letterSpacing: 1.2,),),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientPill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.psychology, size: 12),
                          const SizedBox(width: 4),
                          Text(pill),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(gradeTitle,
                        style: AppTypography.display(context, size: 18),),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: AppTypography.body(context, size: 12)
                          .copyWith(color: l.mutedForeground),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _HealthChip(
                            label: 'Savings',
                            value: '${(savingsRate * 100).round()}%',
                            good: savingsRate >= 0.2,),
                        _HealthChip(
                            label: 'Budgets',
                            value: '$budgetsOnTrack/$budgetsTotal',
                            good: budgetsOver(budgetsOnTrack, budgetsTotal),),
                        _HealthChip(
                            label: 'Goals',
                            value: '$goalsOnTrack/$goalsTotal',
                            good: goalsOnTrack >= goalsTotal / 2,),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: GhostButton(
              icon: SizedBox(
                width: 14,
                height: 14,
                child: loading
                    ? const CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.iris,)
                    : const Icon(Icons.refresh, size: 14),
              ),
              onPressed: loading ? null : onRefresh,
              child: Text(refreshLabel,
                  style: AppTypography.body(context, size: 11, weight: FontWeight.w500)
                      .copyWith(color: l.mutedForeground),),
            ),
          ),
        ],
      ),
    );
  }

  bool budgetsOver(int onTrack, int total) => onTrack == total;
}

class _HealthChip extends StatelessWidget {
  final String label, value;
  final bool good;
  const _HealthChip(
      {required this.label, required this.value, required this.good,});

  @override
  Widget build(BuildContext context) {
    final color = good ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(good ? Icons.shield_outlined : Icons.warning_amber_rounded,
              size: 12, color: color,),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.body(context, size: 11)
                  .copyWith(color: color.withValues(alpha: 0.8)),),
          const SizedBox(width: 2),
          Text(value,
              style: AppTypography.body(context, size: 11, weight: FontWeight.w700)
                  .copyWith(color: color),),
        ],
      ),
    );
  }
}

class _PanelsRow extends StatelessWidget {
  final AppT t;
  final String currency;
  final InsightsPayload data;
  const _PanelsRow({required this.t, required this.currency, required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final card0 = _ForecastPanel(t: t, currency: currency, forecast: data.forecast);
        final card1 = _WeeklyPanel(t: t, currency: currency, summary: data.weeklySummary);
        final card2 = _AnomaliesPanel(t: t, currency: currency, anomalies: data.anomalies);
        if (wide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: card0),
                const SizedBox(width: 12),
                Expanded(child: card1),
                const SizedBox(width: 12),
                Expanded(child: card2),
              ],
            ),
          );
        }
        return Column(
          children: [
            card0,
            const SizedBox(height: 12),
            card1,
            const SizedBox(height: 12),
            card2,
          ],
        );
      },
    );
  }
}

class _ForecastPanel extends StatelessWidget {
  final AppT t;
  final String currency;
  final Forecast forecast;
  const _ForecastPanel({required this.t, required this.currency, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final trendIcon = forecast.trend == 'up'
        ? Icons.trending_up
        : forecast.trend == 'down'
            ? Icons.trending_down
            : Icons.remove;
    final trendColor = forecast.trend == 'up'
        ? AppColors.error
        : forecast.trend == 'down'
            ? AppColors.success
            : l.mutedForeground;
    final trendLabel = forecast.trend == 'up'
        ? t.insights.trendingUp
        : forecast.trend == 'down'
            ? t.insights.trendingDown
            : t.insights.steady;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.iris.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(trendIcon, color: AppColors.iris, size: 16),
              ),
              const SizedBox(width: 8),
              Text(t.insights.monthEndForecast,
                  style: AppTypography.heading(context, size: 13),),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatMoney(forecast.endOfMonthExpense, currency),
            style: AppTypography.amount(context, size: 26, weight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${t.insights.projectedTotalSpend} · ${forecast.daysProjected} ${t.insights.daysRemaining}',
            style: AppTypography.body(context, size: 11)
                .copyWith(color: l.mutedForeground),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, size: 12, color: trendColor),
                    const SizedBox(width: 4),
                    Text(trendLabel,
                        style: AppTypography.body(context, size: 11, weight: FontWeight.w600)
                            .copyWith(color: trendColor),),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: l.surface3,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${forecast.confidence} ${t.insights.confidence}',
                  style: AppTypography.body(context, size: 11)
                      .copyWith(color: l.mutedForeground),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyPanel extends StatelessWidget {
  final AppT t;
  final String currency;
  final WeeklySummaryData summary;
  const _WeeklyPanel({required this.t, required this.currency, required this.summary});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_today,
                    color: AppColors.cyan, size: 14,),
              ),
              const SizedBox(width: 8),
              Text(t.insights.weeklySummary,
                  style: AppTypography.heading(context, size: 13),),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.insights.spent.toUpperCase(),
                        style: AppTypography.label(context, size: 9)
                            .copyWith(color: l.mutedForeground, letterSpacing: 1),),
                    Text(
                      formatMoney(summary.weekSpent, currency, compact: true),
                      style: AppTypography.amount(context, size: 18, weight: FontWeight.bold)
                          .copyWith(color: AppColors.error),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.insights.earned.toUpperCase(),
                        style: AppTypography.label(context, size: 9)
                            .copyWith(color: l.mutedForeground, letterSpacing: 1),),
                    Text(
                      formatMoney(summary.weekIncome, currency, compact: true),
                      style: AppTypography.amount(context, size: 18, weight: FontWeight.bold)
                          .copyWith(color: AppColors.success),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: l.surface3.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.insights.topCategory,
                    style: AppTypography.body(context, size: 11)
                        .copyWith(color: l.mutedForeground),),
                const SizedBox(height: 2),
                Text(summary.topCategory,
                    style: AppTypography.body(context, size: 13, weight: FontWeight.w500),),
                Text(formatMoney(summary.topCategoryAmount, currency),
                    style: AppTypography.amount(context, size: 13, weight: FontWeight.w600)
                        .copyWith(color: AppColors.iris),),
              ],
            ),
          ),
          if (summary.vsLastWeekPct != 0) ...[
            const SizedBox(height: 6),
            Text(
              '${summary.vsLastWeekPct > 0 ? '▲' : '▼'} ${summary.vsLastWeekPct.abs()}% ${t.insights.vsLastWeek}',
              style: AppTypography.body(context, size: 11, weight: FontWeight.w600)
                  .copyWith(
                      color: summary.vsLastWeekPct > 0
                          ? AppColors.error
                          : AppColors.success,),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnomaliesPanel extends StatelessWidget {
  final AppT t;
  final String currency;
  final List<Anomaly> anomalies;
  const _AnomaliesPanel(
      {required this.t, required this.currency, required this.anomalies,});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 16,),
              ),
              const SizedBox(width: 8),
              Text(t.insights.anomalies,
                  style: AppTypography.heading(context, size: 13),),
            ],
          ),
          const SizedBox(height: 12),
          if (anomalies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.verified_user,
                        color: AppColors.success, size: 32,),
                    const SizedBox(height: 6),
                    Text(t.insights.allClear,
                        style: AppTypography.body(context, size: 13, weight: FontWeight.w600)
                            .copyWith(color: AppColors.success),),
                    const SizedBox(height: 2),
                    Text(t.insights.noUnusual,
                        textAlign: TextAlign.center,
                        style: AppTypography.body(context, size: 11)
                            .copyWith(color: l.mutedForeground),),
                  ],
                ),
              ),
            )
          else
            Column(
              children: anomalies
                  .take(3)
                  .map((a) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3),
                              width: 1,),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(a.merchant,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.body(context,
                                              size: 12, weight: FontWeight.w600,)
                                          .copyWith(height: 1.1),),
                                ),
                                Text(
                                  formatMoney(a.amount, currency, compact: true),
                                  style: AppTypography.amount(context,
                                          size: 12, weight: FontWeight.bold,)
                                      .copyWith(color: AppColors.warning),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_relDate(a.date)} · ${a.reason}',
                              style: AppTypography.body(context, size: 10)
                                  .copyWith(color: l.mutedForeground),
                            ),
                          ],
                        ),
                      ),)
                  .toList(),
            ),
        ],
      ),
    );
  }

  String _relDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return formatDate(d, style: 'rel');
    } catch (_) {
      return iso;
    }
  }
}

class _InsightCardsSection extends StatelessWidget {
  final AppT t;
  final String currency;
  final InsightsPayload? data;
  final bool loading;
  final String? error;
  final VoidCallback onRetry, onSaveAsNotification;

  const _InsightCardsSection({
    required this.t,
    required this.currency,
    required this.data,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onSaveAsNotification,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: t.insights.personalizedInsights,
            subtitle: t.insights.generatedBy,
            action: GradientButton(
              icon: const Icon(Icons.auto_awesome, size: 14),
              onPressed: onSaveAsNotification,
              child: Text(t.insights.saveAsNotification),
            ),
          ),
          const SizedBox(height: 14),
          if (loading && data == null)
            LayoutBuilder(
              builder: (context, c) {
                final count = c.maxWidth >= 540 ? 4 : 2;
                final perRow = c.maxWidth >= 540 ? 2 : 1;
                return Column(
                  children: List.generate(
                    (count / perRow).ceil(),
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: List.generate(
                          perRow,
                          (_) => const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: ShimmerBox(height: 110),
                            ),
                          ),
                        ).toList(),
                      ),
                    ),
                  ),
                );
              },
            )
          else if (error != null && data == null)
            EmptyState(
              icon: const Icon(Icons.warning_amber_rounded),
              title: "Couldn't load insights",
              description: error!,
              action: GhostButton(
                icon: const Icon(Icons.refresh, size: 14),
                onPressed: onRetry,
                child: Text(t.common.retry),
              ),
            )
          else if (data != null && data!.cards.isNotEmpty)
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 540;
                final perRow = wide ? 2 : 1;
                final rows = <Widget>[];
                for (var i = 0; i < data!.cards.length; i += perRow) {
                  final row = <Widget>[];
                  for (var j = 0; j < perRow && i + j < data!.cards.length; j++) {
                    row.add(Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _InsightCardItem(
                          card: data!.cards[i + j],
                          index: i + j,
                        ),
                      ),
                    ),);
                  }
                  if (row.length < perRow) {
                    row.add(const Expanded(child: SizedBox()));
                  }
                  rows.add(Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: row,
                    ),
                  ),);
                }
                return Column(children: rows);
              },
            )
          else
            EmptyState(
              icon: const Icon(Icons.lightbulb_outline),
              title: t.insights.noUnusual,
              description: t.insights.generatedBy,
            ),
        ],
      ),
    );
  }
}

class _InsightCardItem extends StatelessWidget {
  final InsightCard card;
  final int index;
  const _InsightCardItem({required this.card, required this.index});

  @override
  Widget build(BuildContext context) {
    final accent = _accentOf(card.accent);
    return GlassCard(
      hover: true,
      padding: const EdgeInsets.all(14),
      border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconFor(card.icon), color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(card.title,
                          style: AppTypography.heading(context, size: 13)
                              .copyWith(height: 1.2),),
                    ),
                    if (card.metric != null) ...[
                      const SizedBox(width: 6),
                      Text(card.metric!,
                          style: AppTypography.amount(context,
                                  size: 13, weight: FontWeight.bold,)
                              .copyWith(color: accent),),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(card.body,
                    style: AppTypography.body(context, size: 11)
                        .copyWith(color: context.lumina.mutedForeground, height: 1.4),),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(card.kind.toUpperCase(),
                      style: AppTypography.label(context, size: 9)
                          .copyWith(color: accent, letterSpacing: 1),),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (200 + index * 60).ms)
        .slideY(begin: 0.05, delay: (200 + index * 60).ms);
  }
}

// ---- helpers ---------------------------------------------------------------

Color _accentOf(String accent) {
  switch (accent) {
    case 'iris':
      return AppColors.iris;
    case 'cyan':
      return AppColors.cyan;
    case 'green':
      return AppColors.success;
    case 'amber':
      return AppColors.warning;
    case 'red':
      return AppColors.error;
    default:
      return AppColors.iris;
  }
}

IconData _iconFor(String name) {
  const m = <String, IconData>{
    'lightbulb': Icons.lightbulb_outline,
    'trending_up': Icons.trending_up,
    'trending_down': Icons.trending_down,
    'target': Icons.gps_fixed,
    'trophy': Icons.emoji_events,
    'wallet': Icons.account_balance_wallet,
    'brain': Icons.psychology,
    'sparkles': Icons.auto_awesome,
    'shield': Icons.shield,
    'alert': Icons.warning_amber_rounded,
    'calendar': Icons.calendar_today,
    'minus': Icons.remove,
  };
  return m[name] ?? Icons.lightbulb_outline;
}

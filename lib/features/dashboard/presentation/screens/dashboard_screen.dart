import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/router/app_router.dart';
import '../providers/dashboard_provider.dart';
import '../../domain/entities/dashboard_entities.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/notifications/presentation/providers/notification_provider.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import '../../../../shared/widgets/states/app_states.dart';
import '../widgets/balance_hero_card.dart';
import '../widgets/quick_stats_row.dart';
import '../widgets/spending_chart_card.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/top_categories_card.dart';
import '../widgets/financial_health_card.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/ai_insight_banner.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final scrolled = _scrollController.offset > 10;
      if (scrolled != _isScrolled) setState(() => _isScrolled = scrolled);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _DashboardAppBar(
            userName: user?.fullName.split(' ').first ?? 'there',
            isScrolled: _isScrolled || innerBoxIsScrolled,
            onMenuTap: () => ShellScaffoldData.of(context)?.openDrawer(),
            onNotificationTap: () => context.push(AppRoutes.notifications),
          ),
        ],
        body: dashState.isLoading
            ? const _DashboardSkeleton()
            : dashState.hasData
                ? _DashboardContent(
                    summary: dashState.summary!,
                    period: dashState.selectedPeriod,
                    onPeriodChanged: (p) =>
                        ref.read(dashboardProvider.notifier).setPeriod(p),
                    onRefresh: () =>
                        ref.read(dashboardProvider.notifier).refresh(),
                  )
                : AppErrorState(
                    message: dashState.failure?.message,
                    onRetry: () => ref.read(dashboardProvider.notifier).load(),
                  ),
      ),
    );
  }
}

// ─── App Bar ─────────────────────────────────────────────────────────────────

class _DashboardAppBar extends ConsumerWidget {
  final String userName;
  final bool isScrolled;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;

  const _DashboardAppBar({
    required this.userName,
    required this.isScrolled,
    required this.onMenuTap,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationListProvider).unreadCount;

    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: isScrolled
          ? AppColors.darkSurface.withValues(alpha: 0.95)
          : Colors.transparent,
      elevation: 0,
      toolbarHeight: 64,
      leading: IconButton(
        icon: AnimatedContainer(
          duration: AppDurations.fast,
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.darkCardElevated,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.darkBorder, width: 0.5),
          ),
          child: const Icon(
            Icons.menu_rounded,
            color: AppColors.darkTextSecondary,
            size: 20,
          ),
        ),
        onPressed: onMenuTap,
      ),
      title: AnimatedOpacity(
        opacity: isScrolled ? 1.0 : 0.0,
        duration: AppDurations.fast,
        child: Text(
          'Dashboard',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      actions: [
        // Search
        IconButton(
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.darkCardElevated,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.darkBorder, width: 0.5),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: AppColors.darkTextSecondary,
              size: 20,
            ),
          ),
          onPressed: () {},
        ),
        // Notifications
        IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.darkCardElevated,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.darkBorder, width: 0.5),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.darkTextSecondary,
                  size: 20,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.darkBackground, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: onNotificationTap,
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}

// ─── Dashboard Content ────────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  final DashboardSummaryEntity summary;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final Future<void> Function() onRefresh;

  const _DashboardContent({
    required this.summary,
    required this.period,
    required this.onPeriodChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.darkCard,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          // ── Greeting ────────────────────────────────────────────────────
          const _GreetingHeader(),
          const SizedBox(height: AppSpacing.base),

          // ── Balance Hero ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: BalanceHeroCard(
              balance: summary.totalBalance,
              income: summary.totalIncome,
              expenses: summary.totalExpenses,
              period: period,
              onPeriodChanged: onPeriodChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // ── Quick Stats ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: QuickStatsRow(
              savingsRate: summary.savingsRate,
              budgetUsed: summary.budgetUsedPercent,
              subscriptions: summary.activeSubscriptions,
              subscriptionCost: summary.subscriptionsCost,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Quick Actions ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: QuickActionsRow(),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── AI Insight Banner ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: AiInsightBanner(insight: summary.financialHealth.insight),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Spending Chart ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: SpendingChartCard(weeklyData: summary.weeklySpending),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Financial Health ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: FinancialHealthCard(health: summary.financialHealth),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Top Categories ───────────────────────────────────────────────
          AppSectionHeader(
            title: 'Top Spending',
            actionLabel: 'See Analytics',
            onAction: () => GoRouter.of(context).push(AppRoutes.analytics),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: TopCategoriesCard(categories: summary.topCategories),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Recent Transactions ──────────────────────────────────────────
          AppSectionHeader(
            title: 'Recent Transactions',
            actionLabel: 'See All',
            onAction: () => GoRouter.of(context).push(AppRoutes.expenses),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          ),
          const SizedBox(height: AppSpacing.md),
          RecentTransactionsList(transactions: summary.recentTransactions),
        ],
      ),
    );
  }
}

// ─── Greeting ────────────────────────────────────────────────────────────────

class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader();

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final firstName = user?.fullName.split(' ').first ?? 'there';
    final now = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_greeting, $firstName 👋',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.darkTextPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            now,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.darkTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton Loading ────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: const [
        // Greeting skeleton
        AppShimmerCard(height: 48, borderRadius: AppRadius.sm),
        SizedBox(height: AppSpacing.base),
        // Balance card skeleton
        AppShimmerCard(height: 200),
        SizedBox(height: AppSpacing.base),
        // Stats row skeleton
        Row(
          children: [
            Expanded(child: AppShimmerCard(height: 80)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: AppShimmerCard(height: 80)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: AppShimmerCard(height: 80)),
          ],
        ),
        SizedBox(height: AppSpacing.xl),
        // Chart skeleton
        AppShimmerCard(height: 200),
        SizedBox(height: AppSpacing.xl),
        // Transactions skeleton
        AppShimmerList(itemCount: 4, itemHeight: 68),
      ],
    );
  }
}

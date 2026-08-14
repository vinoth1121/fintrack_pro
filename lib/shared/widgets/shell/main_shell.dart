import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/router/app_router.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Expose drawer opener to child screens via InheritedWidget
  void openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    return ShellScaffoldData(
      openDrawer: openDrawer,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.darkBackground,
        drawer: const AppNavigationDrawer(),
        body: widget.child,
      ),
    );
  }
}

// ─── Inherited Widget for Drawer Access ──────────────────────────────────────

class ShellScaffoldData extends InheritedWidget {
  final VoidCallback openDrawer;

  const ShellScaffoldData({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  static ShellScaffoldData? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScaffoldData>();

  @override
  bool updateShouldNotify(ShellScaffoldData oldWidget) => false;
}

// ─── Navigation Drawer ────────────────────────────────────────────────────────

class AppNavigationDrawer extends ConsumerWidget {
  const AppNavigationDrawer({super.key});

  static const List<_DrawerSection> _sections = [
    _DrawerSection(title: null, items: [
      _DrawerItem(
        route: AppRoutes.dashboard,
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
      ),
    ],),
    _DrawerSection(title: 'Finance', items: [
      _DrawerItem(
        route: AppRoutes.expenses,
        icon: Icons.trending_down_rounded,
        label: 'Expenses',
        accentColor: AppColors.expense,
      ),
      _DrawerItem(
        route: AppRoutes.income,
        icon: Icons.trending_up_rounded,
        label: 'Income',
        accentColor: AppColors.income,
      ),
      _DrawerItem(
        route: AppRoutes.budget,
        icon: Icons.account_balance_wallet_rounded,
        label: 'Budget',
        accentColor: AppColors.budget,
      ),
      _DrawerItem(
        route: AppRoutes.savings,
        icon: Icons.savings_rounded,
        label: 'Savings Goals',
        accentColor: AppColors.savings,
      ),
      _DrawerItem(
        route: AppRoutes.subscriptions,
        icon: Icons.repeat_rounded,
        label: 'Subscriptions',
        accentColor: Color(0xFFE040FB),
      ),
    ],),
    _DrawerSection(title: 'Insights', items: [
      _DrawerItem(
        route: AppRoutes.analytics,
        icon: Icons.bar_chart_rounded,
        label: 'Analytics',
      ),
      _DrawerItem(
        route: AppRoutes.reports,
        icon: Icons.description_rounded,
        label: 'Reports & Export',
      ),
      _DrawerItem(
        route: AppRoutes.aiChat,
        icon: Icons.auto_awesome_rounded,
        label: 'AI Assistant',
        badge: 'AI',
      ),
    ],),
    _DrawerSection(title: 'Tools', items: [
      _DrawerItem(
        route: AppRoutes.notes,
        icon: Icons.sticky_note_2_rounded,
        label: 'Notes',
      ),
      _DrawerItem(
        route: AppRoutes.calculatorHub,
        icon: Icons.calculate_rounded,
        label: 'Calculator Hub',
      ),
      _DrawerItem(
        route: AppRoutes.currencyConverter,
        icon: Icons.currency_exchange_rounded,
        label: 'Currency Converter',
      ),
    ],),
    _DrawerSection(title: 'Account', items: [
      _DrawerItem(
        route: AppRoutes.profile,
        icon: Icons.person_rounded,
        label: 'Profile',
      ),
      _DrawerItem(
        route: AppRoutes.notifications,
        icon: Icons.notifications_rounded,
        label: 'Notifications',
      ),
      _DrawerItem(
        route: AppRoutes.settings,
        icon: Icons.settings_rounded,
        label: 'Settings',
      ),
    ],),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final user = ref.watch(authProvider).user;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _DrawerHeader(user: user),

            // ── Navigation Items ─────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                children: _sections.map((section) {
                  return _DrawerSectionWidget(
                    section: section,
                    currentRoute: currentRoute,
                  );
                }).toList(),
              ),
            ),

            // ── Logout ───────────────────────────────────────────────────────
            const Divider(color: AppColors.darkDivider, thickness: 0.5, height: 1),
            _LogoutTile(
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go(AppRoutes.login);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

// ─── Drawer Header ────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  final dynamic user;
  const _DrawerHeader({this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      margin: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppColors.darkCardGradient,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                user?.fullName?.isNotEmpty == true
                    ? user!.fullName[0].toUpperCase()
                    : 'F',
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? 'User',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Premium badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              'PRO',
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Widget ──────────────────────────────────────────────────────────

class _DrawerSectionWidget extends StatelessWidget {
  final _DrawerSection section;
  final String currentRoute;

  const _DrawerSectionWidget({
    required this.section,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.base, AppSpacing.md, AppSpacing.xs,),
            child: Text(
              section.title!.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.darkTextTertiary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        ...section.items.map((item) => _DrawerItemTile(
          item: item,
          isActive: currentRoute == item.route ||
              (currentRoute.startsWith(item.route) && item.route != AppRoutes.dashboard),
        ),),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

// ─── Item Tile ───────────────────────────────────────────────────────────────

class _DrawerItemTile extends StatelessWidget {
  final _DrawerItem item;
  final bool isActive;

  const _DrawerItemTile({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final accentColor = item.accentColor ?? AppColors.primary;

    return AnimatedContainer(
      duration: AppDurations.fast,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? accentColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop(); // Close drawer
            context.go(item.route);
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppDurations.fast,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive
                        ? accentColor.withValues(alpha: 0.2)
                        : AppColors.darkCardElevated,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    item.icon,
                    size: AppIconSizes.md,
                    color: isActive ? accentColor : AppColors.darkTextTertiary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isActive
                          ? AppColors.darkTextPrimary
                          : AppColors.darkTextSecondary,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (item.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      item.badge!,
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                    ),
                  ),
                if (isActive)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(left: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Logout Tile ─────────────────────────────────────────────────────────────

class _LogoutTile extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: AppIconSizes.md,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Sign Out',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Data Models ─────────────────────────────────────────────────────────────

class _DrawerSection {
  final String? title;
  final List<_DrawerItem> items;
  const _DrawerSection({required this.title, required this.items});
}

class _DrawerItem {
  final String route;
  final IconData icon;
  final String label;
  final Color? accentColor;
  final String? badge;
  const _DrawerItem({
    required this.route,
    required this.icon,
    required this.label,
    this.accentColor,
    this.badge,
  });
}

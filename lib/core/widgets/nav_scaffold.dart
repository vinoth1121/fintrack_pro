import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';
import 'widgets.dart';

/// App shell — drawer + bottom navigation bar (always visible on mobile).
class NavScaffold extends ConsumerWidget {
  final String location;
  final Widget child;
  const NavScaffold({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final l = context.lumina;
    final unread = ref.watch(fintrackProvider.select((s) {
      final notifs = s.notifications;
      return notifs.where((n) => !n.read).length;
    }));

    final currentIndex = _navItems(t).indexWhere((n) => location.startsWith(n.path));

    return Scaffold(
      key: _scaffoldKey,
      body: child,
      drawer: _AppDrawer(location: location),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (i) => context.go(_navItems(t)[i].path),
        backgroundColor: l.surface.withValues(alpha: 0.95),
        indicatorColor: AppColors.iris.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(AppTypography.label(context, size: 11)),
        height: 65,
        destinations: _navItems(t).map((n) => NavigationDestination(
          icon: Icon(n.icon, size: 22),
          selectedIcon: Icon(n.icon, color: AppColors.iris, size: 22),
          label: n.label,
        ),).toList(),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(builder: (c) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(c).openDrawer(),
        ),),
        title: Text(_titleForLocation(location, t), style: AppTypography.heading(context, size: 18)),
        titleSpacing: 0,
        actions: [
          IconButton(
            icon: Stack(children: [
              const Icon(Icons.notifications_none),
              if (unread > 0)
                Positioned(right: 0, top: 0, child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),),
            ],),
            onPressed: () => context.go('/notifications'),
          ),
          IconButton(
            icon: Icon(context.lumina.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: ref.read(fintrackProvider.notifier).toggleTheme,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _titleForLocation(String loc, AppT t) {
    final map = {
      '/dashboard': t.nav.dashboard, '/expenses': t.nav.expenses, '/income': t.nav.income,
      '/budget': t.nav.budget, '/analytics': t.nav.analytics, '/insights': t.nav.insights,
      '/goals': t.nav.goals, '/subscriptions': t.nav.subscriptions, '/notes': t.nav.notes,
      '/calculators': t.nav.calculators, '/currency': t.nav.currency, '/receipts': t.nav.receipts,
      '/voice': t.nav.voice, '/ai-chat': t.nav.aiChat, '/reports': t.nav.reports,
      '/notifications': t.nav.notifications, '/family': t.nav.family,
      '/profile': t.nav.profile, '/settings': t.nav.settings,
    };
    return map[loc] ?? t.nav.dashboard;
  }
}

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

class _NavItem { final String path, label; final IconData icon; const _NavItem(this.path, this.label, this.icon); }

List<_NavItem> _navItems(AppT t) => [
  _NavItem('/dashboard', t.nav.dashboard, Icons.dashboard_outlined),
  _NavItem('/expenses', t.nav.expenses, Icons.arrow_downward_rounded),
  _NavItem('/analytics', t.nav.analytics, Icons.bar_chart_rounded),
  _NavItem('/ai-chat', t.nav.aiChat, Icons.auto_awesome),
  _NavItem('/settings', t.nav.settings, Icons.settings_outlined),
];

class _AppDrawer extends ConsumerWidget {
  final String location;
  const _AppDrawer({required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final l = context.lumina;
    final s = ref.watch(fintrackProvider);
    final notifs = s.notifications;
    final unread = notifs.where((n) => !n.read).length;
    final accts = s.accounts;
    final netBalance = accts.fold(0.0, (a, x) => a + x.balance);

    final allRoutes = <_DrawerGroup>[
      _DrawerGroup(t.nav.finance, [
        _DrawerItem('/dashboard', t.nav.dashboard, Icons.dashboard_outlined),
        _DrawerItem('/expenses', t.nav.expenses, Icons.arrow_downward_rounded),
        _DrawerItem('/income', t.nav.income, Icons.arrow_upward_rounded),
        _DrawerItem('/budget', t.nav.budget, Icons.savings_outlined),
        _DrawerItem('/analytics', t.nav.analytics, Icons.bar_chart_rounded),
        _DrawerItem('/insights', t.nav.insights, Icons.psychology),
        _DrawerItem('/goals', t.nav.goals, Icons.flag_outlined),
        _DrawerItem('/subscriptions', t.nav.subscriptions, Icons.repeat),
        _DrawerItem('/notes', t.nav.notes, Icons.sticky_note_2_outlined),
      ]),
      _DrawerGroup(t.nav.tools, [
        _DrawerItem('/ai-chat', t.nav.aiChat, Icons.auto_awesome),
        _DrawerItem('/receipts', t.nav.receipts, Icons.document_scanner_outlined),
        _DrawerItem('/voice', t.nav.voice, Icons.mic_none),
        _DrawerItem('/calculators', t.nav.calculators, Icons.calculate_outlined),
        _DrawerItem('/currency', t.nav.currency, Icons.currency_exchange),
        _DrawerItem('/reports', t.nav.reports, Icons.assessment_outlined),
      ]),
      _DrawerGroup(t.nav.account, [
        _DrawerItem('/notifications', t.nav.notifications, Icons.notifications_none, badge: unread),
        _DrawerItem('/family', t.nav.family, Icons.group_outlined),
        _DrawerItem('/profile', t.nav.profile, Icons.person_outline),
        _DrawerItem('/settings', t.nav.settings, Icons.settings_outlined),
      ]),
    ];

    return Drawer(
      backgroundColor: l.surface.withValues(alpha: 0.97),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: AppColors.brandGradient),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('FinTrack Pro', style: AppTypography.display(context, size: 15)),
                  Text(t.appTaglineFallback, style: AppTypography.label(context, size: 10).copyWith(color: l.mutedForeground)),
                ],),
              ],),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: l.surface3.withValues(alpha: 0.5)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.dashboard.totalNetWorth.toUpperCase(), style: AppTypography.label(context, size: 10).copyWith(letterSpacing: 1.2, color: l.mutedForeground)),
                  AmountText(value: netBalance, currency: s.profile.baseCurrency, size: 20, weight: FontWeight.bold, color: AppColors.iris),
                  Text('${s.profile.name} · ${s.profile.baseCurrency}', style: AppTypography.label(context, size: 10).copyWith(color: l.mutedForeground)),
                ],),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: allRoutes.length,
                itemBuilder: (c, gi) {
                  final g = allRoutes[gi];
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: Text(g.label.toUpperCase(), style: AppTypography.label(context, size: 10).copyWith(letterSpacing: 1.4, color: l.mutedForeground.withValues(alpha: 0.7)))),
                    ...g.items.map((item) {
                      final active = location.startsWith(item.path);
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: active ? AppColors.iris.withValues(alpha: 0.12) : null,
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(item.icon, size: 20, color: active ? AppColors.iris : l.mutedForeground),
                          title: Text(item.label, style: AppTypography.body(context, size: 13, weight: active ? FontWeight.w600 : FontWeight.w500).copyWith(color: active ? l.foreground : l.mutedForeground)),
                          trailing: item.badge != null && item.badge! > 0
                            ? Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle), child: Text('${item.badge}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))
                            : (active ? const Icon(Icons.circle, size: 6, color: AppColors.iris) : null),
                          onTap: () { context.go(item.path); Navigator.of(context).pop(); },
                        ),
                      );
                    }),
                  ],);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerGroup { final String label; final List<_DrawerItem> items; const _DrawerGroup(this.label, this.items); }
class _DrawerItem { final String path, label; final IconData icon; final int? badge; const _DrawerItem(this.path, this.label, this.icon, {this.badge}); }

// helper extension for tagline fallback
extension on AppT { String get appTaglineFallback => 'Lumina · AI Finance'; }
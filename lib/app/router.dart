import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/fintrack_provider.dart';
import '../providers/auth_provider.dart';
import '../data/models/models.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/auth/login/login_screen.dart';
import '../features/auth/register/register_screen.dart';
import '../features/auth/otp/otp_screen.dart';
import '../features/auth/forgot_password/forgot_password_screen.dart';
import '../features/auth/reset_password/reset_password_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/transactions/transactions_screen.dart';
import '../features/budget/budget_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/subscriptions/subscriptions_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/calculators/calculators_screen.dart';
import '../features/currency/currency_screen.dart';
import '../features/receipts/receipts_screen.dart';
import '../features/voice/voice_screen.dart';
import '../features/ai_chat/ai_chat_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/family/family_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../core/widgets/nav_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final booted = ref.watch(fintrackProvider.select((s) => s.booted));
  final onboardingDone = ref.watch(fintrackProvider.select((s) => s.onboardingDone));
  final authStatus = ref.watch(authStatusProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register' ||
          loc == '/otp' || loc == '/forgot-password' || loc == '/reset-password';

      // Splash phase
      if (!booted) return loc == '/splash' ? null : '/splash';

      // Auth gating
      if (authStatus == AuthStatus.authenticated) {
        // Onboarding check
        if (!onboardingDone && loc != '/onboarding' && loc != '/splash') return '/onboarding';
        // Authenticated user on auth routes → go to dashboard
        if (isAuthRoute && onboardingDone) return '/dashboard';
        if (isAuthRoute && !onboardingDone) return '/onboarding';
      } else if (authStatus == AuthStatus.unauthenticated) {
        // Unauthenticated user trying to access app routes → go to login
        if (!isAuthRoute && loc != '/splash' && loc != '/onboarding') return '/login';
      }
      // unknown status → stay (splash will resolve it)
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      // Auth routes
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(
        path: '/otp',
        builder: (c, s) => OtpScreen(
          email: s.uri.queryParameters['email'] ?? '',
          purpose: s.uri.queryParameters['purpose'] ?? 'register',
        ),
      ),
      GoRoute(path: '/forgot-password', builder: (c, s) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (c, s) => ResetPasswordScreen(
          email: s.uri.queryParameters['email'] ?? '',
        ),
      ),
      // App shell routes
      ShellRoute(
        builder: (context, state, child) => NavScaffold(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
          GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
          GoRoute(path: '/expenses', builder: (c, s) => const TransactionsScreen(type: TxType.expense)),
          GoRoute(path: '/income', builder: (c, s) => const TransactionsScreen(type: TxType.income)),
          GoRoute(path: '/budget', builder: (c, s) => const BudgetScreen()),
          GoRoute(path: '/analytics', builder: (c, s) => const AnalyticsScreen()),
          GoRoute(path: '/insights', builder: (c, s) => const InsightsScreen()),
          GoRoute(path: '/goals', builder: (c, s) => const GoalsScreen()),
          GoRoute(path: '/subscriptions', builder: (c, s) => const SubscriptionsScreen()),
          GoRoute(path: '/notes', builder: (c, s) => const NotesScreen()),
          GoRoute(path: '/calculators', builder: (c, s) => const CalculatorsScreen()),
          GoRoute(path: '/currency', builder: (c, s) => const CurrencyScreen()),
          GoRoute(path: '/receipts', builder: (c, s) => const ReceiptsScreen()),
          GoRoute(path: '/voice', builder: (c, s) => const VoiceScreen()),
          GoRoute(path: '/ai-chat', builder: (c, s) => const AiChatScreen()),
          GoRoute(path: '/reports', builder: (c, s) => const ReportsScreen()),
          GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
          GoRoute(path: '/family', builder: (c, s) => const FamilyScreen()),
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
          GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
        ],
      ),
    ],
    errorBuilder: (c, s) => Scaffold(body: Center(child: Text('Route not found: ${s.matchedLocation}'))),
  );
});

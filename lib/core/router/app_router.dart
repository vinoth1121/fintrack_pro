import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/expenses/presentation/screens/add_expense_screen.dart';
import '../../features/expenses/presentation/screens/receipt_scanner_screen.dart';
import '../../features/expenses/presentation/screens/voice_expense_screen.dart';
import '../../features/expenses/presentation/screens/expense_detail_screen.dart';
import '../../features/income/presentation/screens/income_screen.dart';
import '../../features/income/presentation/screens/add_income_screen.dart';
import '../../features/budget/presentation/screens/budget_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/savings/presentation/screens/savings_screen.dart';
import '../../features/savings/presentation/screens/add_savings_goal_screen.dart';
import '../../features/subscriptions/presentation/screens/subscriptions_screen.dart';
import '../../features/notes/presentation/screens/notes_screen.dart';
import '../../features/calculator/presentation/screens/calculator_hub_screen.dart';
import '../../features/currency/presentation/screens/currency_converter_screen.dart';
import '../../features/ai_chat/presentation/screens/ai_chat_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../shared/widgets/shell/main_shell.dart';

// Route names — use these constants everywhere, never raw strings
abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const otpVerification = '/otp-verification';

  // Main shell
  static const dashboard = '/dashboard';
  static const expenses = '/expenses';
  static const addExpense = '/expenses/add';
  static const scanReceipt = '/expenses/scan';
  static const voiceExpense = '/expenses/voice';
  static const expenseDetail = '/expenses/:id';
  static const income = '/income';
  static const addIncome = '/income/add';
  static const budget = '/budget';
  static const analytics = '/analytics';
  static const savings = '/savings';
  static const addSavingsGoal = '/savings/add';
  static const subscriptions = '/subscriptions';
  static const notes = '/notes';
  static const calculatorHub = '/calculators';
  static const currencyConverter = '/currency';
  static const aiChat = '/ai-chat';
  static const reports = '/reports';
  static const settings = '/settings';
  static const profile = '/profile';
  static const notifications = '/notifications';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      // TODO: Add auth guard logic once AuthProvider is implemented
      // final isAuthenticated = ref.read(authProvider).isAuthenticated;
      // final isOnboarded = ref.read(onboardingProvider).isCompleted;
      return null;
    },
    routes: [
      // ── Standalone screens (no shell) ──────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.otpVerification,
        pageBuilder: (context, state) {
          final email = state.extra as String? ?? '';
          return _buildPage(
            state: state,
            child: OtpVerificationScreen(email: email),
          );
        },
      ),

      // ── Main app shell (with Drawer navigation) ────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.expenses,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const ExpensesScreen(),
            ),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (context, state) => _buildPage(
                  state: state,
                  child: AddExpenseScreen(
                    initialDraft: state.extra as ScannedExpenseDraft?,
                  ),
                ),
              ),
              GoRoute(
                path: 'scan',
                pageBuilder: (context, state) => _buildPage(
                  state: state,
                  child: const ReceiptScannerScreen(),
                ),
              ),
              GoRoute(
                path: 'voice',
                pageBuilder: (context, state) => _buildPage(
                  state: state,
                  child: const VoiceExpenseScreen(),
                ),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _buildPage(
                    state: state,
                    child: ExpenseDetailScreen(expenseId: id),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.income,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const IncomeScreen(),
            ),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (context, state) => _buildPage(
                  state: state,
                  child: const AddIncomeScreen(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.budget,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const BudgetScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const AnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.savings,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const SavingsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (context, state) => _buildPage(
                  state: state,
                  child: const AddSavingsGoalScreen(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.subscriptions,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const SubscriptionsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.notes,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const NotesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.calculatorHub,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const CalculatorHubScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.currencyConverter,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const CurrencyConverterScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.aiChat,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const AiChatScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.reports,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const ReportsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const ProfileScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            pageBuilder: (context, state) => _buildNoTransitionPage(
              state: state,
              child: const NotificationsScreen(),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _RouterErrorScreen(error: state.error),
  );
});

/// Slide-up transition — used for child routes (add/detail screens)
CustomTransitionPage<void> _buildPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curve),
        child: FadeTransition(opacity: curve, child: child),
      );
    },
  );
}

/// No-transition page — used for shell routes (no animation between drawer items)
NoTransitionPage<void> _buildNoTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

class _RouterErrorScreen extends StatelessWidget {
  final Exception? error;
  const _RouterErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Navigation error: $error'),
      ),
    );
  }
}

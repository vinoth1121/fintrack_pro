import 'package:flutter/material.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import 'basic_calculator_view.dart';
import 'emi_calculator_view.dart';
import 'gst_calculator_view.dart';
import 'savings_calculator_view.dart';

class CalculatorHubScreen extends StatefulWidget {
  const CalculatorHubScreen({super.key});

  @override
  State<CalculatorHubScreen> createState() => _CalculatorHubScreenState();
}

class _CalculatorHubScreenState extends State<CalculatorHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    (label: 'Basic', icon: Icons.calculate_outlined),
    (label: 'EMI', icon: Icons.account_balance_outlined),
    (label: 'GST', icon: Icons.receipt_long_outlined),
    (label: 'Savings', icon: Icons.savings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          'Calculator Hub',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.darkBorder, width: 0.5),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.darkTextTertiary,
                labelStyle: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                unselectedLabelStyle: AppTypography.labelSmall.copyWith(fontSize: 11),
                tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BasicCalculatorView(),
          EmiCalculatorView(),
          GstCalculatorView(),
          SavingsCalculatorView(),
        ],
      ),
    );
  }
}

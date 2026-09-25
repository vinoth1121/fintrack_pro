// Reproduction test: Reports & Export screen must render without throwing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fintrack_pro/app/theme/app_theme.dart';
import 'package:fintrack_pro/features/reports/reports_screen.dart';

void main() {
  testWidgets('ReportsScreen renders without build exception', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ReportsScreen(),
        ),
      ),
    );
    await tester.pump();
    // Drain flutter_animate delay timers (one-shot fade/slide animations).
    await tester.pump(const Duration(seconds: 2));

    final exception = tester.takeException();
    expect(exception, isNull, reason: exception?.toString());
    expect(find.text('Reports & Export'), findsWidgets);
  });
}

// Onboarding flow regression test.
//
// Bugs under test (user-reported):
//  1. Continue jumps straight to Login instead of stepping through slides.
//  2. "Get started" is unresponsive on the final slide.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fintrack_pro/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
  });

  Future<void> pumpUntilOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FinTrackApp()));
    await tester.pump();
    // Splash animations (~1.9s) + navigation delay (600ms) + onboarding entry.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('Continue steps through slides; Get started reaches login',
      (tester) async {
    await pumpUntilOnboarding(tester);
    expect(tester.takeException(), isNull);

    // Slide 1
    expect(find.text('Welcome to FinTrack Pro'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Continue → (expect slide 2). Use several small pumps so the page
    // animation actually advances frame-by-frame in the test clock.
    await tester.tap(find.text('Continue'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('See your money clearly'), findsOneWidget,
        reason: 'Continue should advance to slide 2, not exit onboarding');

    // Continue → slide 3
    await tester.tap(find.text('Continue'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('Your personal AI coach'), findsOneWidget);

    // Continue → slide 4, label switches to "Get started"
    await tester.tap(find.text('Continue'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('Bank-grade security'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    // Get started → Login screen
    await tester.tap(find.text('Get started'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Get started'), findsNothing,
        reason: 'Get started must leave the onboarding screen');
    expect(find.text('Welcome to FinTrack Pro'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

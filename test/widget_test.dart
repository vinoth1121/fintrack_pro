// Smoke test: the app boots to the splash screen without throwing.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fintrack_pro/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    // flutter_secure_storage has no plugin in tests — answer instead of throwing.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
  });

  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FinTrackApp()));
    await tester.pump();

    // Splash brand mark is visible (wordmark is split across two Text widgets).
    expect(find.textContaining('FinTrack'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Drain splash animation + navigation timers so nothing dangles.
    await tester.pump(const Duration(seconds: 5));
    // Drain timers started by the screen we navigated to (onboarding/login).
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../providers/fintrack_provider.dart';
import 'theme/app_theme.dart';
import 'router.dart';

class FinTrackApp extends ConsumerWidget {
  const FinTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(fintrackProvider.select((s) => s.theme));
    final goRouter = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'FinTrack Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme == 'dark' ? ThemeMode.dark : ThemeMode.light,
      routerConfig: goRouter,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), Locale('es'), Locale('fr'), Locale('de'),
        Locale('hi'), Locale('ta'), Locale('ja'),
      ],
    );
  }
}

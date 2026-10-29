import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_state.dart';
import 'core/logging/app_log.dart';
import 'core/perf/perf_metrics.dart';
import 'core/storage/settings_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_providers.dart';
import 'core/theme/tokens.dart';
import 'features/apps/ui/app_drawer_screen.dart';
import 'features/dashboard/ui/dashboard_screen.dart';
import 'features/diagnostics/ui/diagnostics_screen.dart';
import 'features/launcher/state/launcher_providers.dart';
import 'features/onboarding/ui/onboarding_screen.dart';
import 'features/settings/ui/dock_editor_screen.dart';
import 'features/settings/ui/settings_screen.dart';

class SwiftDriveApp extends ConsumerStatefulWidget {
  const SwiftDriveApp({super.key, this.startupWatch});

  final Stopwatch? startupWatch;

  @override
  ConsumerState<SwiftDriveApp> createState() => _SwiftDriveAppState();
}

class _SwiftDriveAppState extends ConsumerState<SwiftDriveApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<void>? _homeSub;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(foregroundProvider.notifier).set(true);
        ref.read(resumeTickProvider.notifier).bump();
      },
      onHide: () => ref.read(foregroundProvider.notifier).set(false),
    );
    // HOME pressed while SwiftDrive is on top: go back to the dashboard.
    _homeSub = ref.read(launcherRepositoryProvider).homePressed.listen((_) {
      _navigatorKey.currentState?.popUntil((r) => r.isFirst);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerfMetrics.firstFrameTime = widget.startupWatch?.elapsed;
      AppLog.i(
        'startup',
        'first frame after ${widget.startupWatch?.elapsedMilliseconds} ms',
      );
      ref.read(startupStageProvider.notifier).begin();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _homeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentIndex = ref.watch(
      settingsProvider.select((s) => s.accentIndex),
    );
    final reduceMotion = ref.watch(
      settingsProvider.select((s) => s.performanceMode),
    );
    final onboarded = ref.watch(
      settingsProvider.select((s) => s.onboardingDone),
    );
    final accent =
        SdColors.accents[accentIndex.clamp(0, SdColors.accents.length - 1)];

    return MaterialApp(
      title: 'SwiftDrive',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: buildTheme(Brightness.light, accent, reduceMotion: reduceMotion),
      darkTheme: buildTheme(
        Brightness.dark,
        accent,
        reduceMotion: reduceMotion,
      ),
      themeMode: ref.watch(themeModeProvider),
      // A cross-fade between themes would briefly show mixed colours; switch instantly instead.
      themeAnimationDuration: Duration.zero,
      home: onboarded ? const DashboardScreen() : const OnboardingScreen(),
      routes: {
        AppDrawerScreen.route: (_) => const AppDrawerScreen(),
        SettingsScreen.route: (_) => const SettingsScreen(),
        DockEditorScreen.route: (_) => const DockEditorScreen(),
        DiagnosticsScreen.route: (_) => const DiagnosticsScreen(),
      },
    );
  }
}

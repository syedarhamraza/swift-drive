import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the launcher is in the foreground. Native streams (location, media, Bluetooth) subscribe only
/// while this is true, so nothing polls or tracks in the background.
final foregroundProvider = NotifierProvider<_BoolController, bool>(
  () => _BoolController(true),
);

/// Increments on every resume so permission/role/access checks re-run after the user visits Settings.
final resumeTickProvider = NotifierProvider<ResumeTick, int>(ResumeTick.new);

class _BoolController extends Notifier<bool> {
  _BoolController(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;

  void set(bool value) => state = value;
}

class ResumeTick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Staged startup (spec §22):
/// 1 shell visible, 2 apps/shortcuts, 3 media/location, 4 map/network, 5 weather/diagnostics.
final startupStageProvider = NotifierProvider<StartupStage, int>(
  StartupStage.new,
);

class StartupStage extends Notifier<int> {
  final _timers = <Timer>[];

  @override
  int build() {
    ref.onDispose(() {
      for (final t in _timers) {
        t.cancel();
      }
    });
    return 1;
  }

  /// Called after the first frame is rendered.
  void begin() {
    if (state > 1) return;
    state = 2;
    for (final (stage, ms) in const [(3, 250), (4, 700), (5, 2500)]) {
      _timers.add(
        Timer(
          Duration(milliseconds: ms),
          () => state = state < stage ? stage : state,
        ),
      );
    }
  }

  /// Tests jump straight to the final stage.
  void completeAll() => state = 5;
}

extension StageRef on Ref {
  bool stageReached(int stage) =>
      watch(startupStageProvider.select((s) => s >= stage));
}

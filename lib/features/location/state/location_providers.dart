import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_state.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/platform/platform_failure.dart';
import '../data/location_repository.dart';
import '../domain/speed.dart';

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => ChannelLocationRepository(),
);

class LocationState {
  const LocationState({
    this.status,
    this.fix,
    this.speed = const SpeedState(SpeedStatus.acquiring),
  });

  final LocationStatus? status;

  /// Latest fix from any provider (GPS or network). Used for the map and weather, never for speed.
  final LocationFix? fix;
  final SpeedState speed;

  LocationState copyWith({
    LocationStatus? status,
    LocationFix? fix,
    SpeedState? speed,
  }) => LocationState(
    status: status ?? this.status,
    fix: fix ?? this.fix,
    speed: speed ?? this.speed,
  );
}

final locationProvider = NotifierProvider<LocationController, LocationState>(
  LocationController.new,
);

class LocationController extends Notifier<LocationState> {
  final _speed = SpeedEstimator();

  @override
  LocationState build() {
    final previous = stateOrNull ?? const LocationState();
    final active = ref.watch(foregroundProvider) && ref.stageReached(3);
    if (!active) return previous;

    final repo = ref.watch(locationRepositoryProvider);
    final sub = repo.events().listen(
      (event) {
        switch (event) {
          case LocationStatus s:
            AppLog.i(
              'location',
              'status: perm=${s.permission} gps=${s.gpsAvailable}/${s.gpsEnabled}',
            );
            state = state.copyWith(
              status: s,
              speed: _speed.evaluate(s, monotonicNow()),
            );
          case LocationFix f:
            _speed.addFix(f);
            state = state.copyWith(
              fix: f,
              speed: _speed.evaluate(state.status, monotonicNow()),
            );
        }
      },
      onError: (Object e) {
        AppLog.e('location', 'location stream failed: $e');
        state = state.copyWith(
          speed: const SpeedState(SpeedStatus.unavailable),
        );
      },
    );
    // Re-evaluate freshness once per second so stale speed is withdrawn even if fixes stop arriving.
    final ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _speed.evaluate(state.status, monotonicNow());
      if (next != state.speed) state = state.copyWith(speed: next);
    });
    ref.onDispose(() {
      sub.cancel();
      ticker.cancel();
    });
    return previous;
  }

  /// After the user grants permission, restart native updates so fixes start flowing.
  Future<void> restart() async {
    try {
      await ref.read(locationRepositoryProvider).restart();
    } on PlatformFailure catch (f) {
      AppLog.w('location', 'restart failed: ${f.kind.name}');
    }
  }
}

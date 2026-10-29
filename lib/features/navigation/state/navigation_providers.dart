import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/storage/settings_providers.dart';
import '../../location/state/location_providers.dart';
import '../data/navigation_models.dart';
import '../data/osm_providers.dart';
import '../domain/route_geometry.dart';
import 'voice_guidance.dart';

final routingProviderProvider = Provider<RoutingProvider>(
  (ref) => OsrmRoutingProvider(
    ref.watch(settingsProvider.select((s) => s.routingUrl)),
  ),
);

final geocodingProviderProvider = Provider<GeocodingProvider>(
  (ref) => NominatimGeocodingProvider(
    ref.watch(settingsProvider.select((s) => s.geocodingUrl)),
  ),
);

enum NavPhase {
  idle,
  searching,
  calculating,
  routeReady,
  navigating,
  rerouting,
  arrived,
  unavailable,
  error,
}

class NavState {
  const NavState({
    this.phase = NavPhase.idle,
    this.results = const [],
    this.destination,
    this.route,
    this.progress,
    this.message,
  });

  final NavPhase phase;
  final List<Place> results;
  final Place? destination;
  final RouteResult? route;
  final RouteProgress? progress;
  final String? message;

  bool get isGuiding =>
      phase == NavPhase.navigating || phase == NavPhase.rerouting;

  NavState copyWith({
    NavPhase? phase,
    List<Place>? results,
    RouteResult? route,
    RouteProgress? progress,
    String? message,
  }) => NavState(
    phase: phase ?? this.phase,
    results: results ?? this.results,
    destination: destination,
    route: route ?? this.route,
    progress: progress ?? this.progress,
    message: message,
  );
}

final navigationProvider = NotifierProvider<NavigationController, NavState>(
  NavigationController.new,
);

/// Navigation state machine. Map rendering only observes this state; route calculation lives here.
class NavigationController extends Notifier<NavState> {
  static const offRouteMeters = 50.0;
  static const offRouteFixes = 3;
  static const rerouteInterval = Duration(seconds: 30);
  static const arrivalMeters = 30.0;

  RouteTracker? _tracker;
  int _offCount = 0;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  NavState build() {
    ref.listen(locationProvider.select((s) => s.fix), (_, fix) {
      if (fix != null && state.isGuiding) {
        onPosition(GeoPoint(fix.lat, fix.lon));
      }
    });
    return const NavState();
  }

  GeoPoint? _here() {
    final fix = ref.read(locationProvider).fix;
    return fix == null ? null : GeoPoint(fix.lat, fix.lon);
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    state = NavState(phase: NavPhase.searching, destination: null);
    try {
      final results = await ref
          .read(geocodingProviderProvider)
          .search(query, near: _here());
      if (!ref.mounted) return;
      state = NavState(
        results: results,
        message: results.isEmpty ? 'No places found' : null,
      );
    } catch (e) {
      AppLog.w('navigation', 'search failed: ${e.runtimeType}');
      if (ref.mounted) {
        state = const NavState(
          phase: NavPhase.error,
          message: 'Search failed. Check the internet connection.',
        );
      }
    }
  }

  Future<void> choose(Place place) async {
    final origin = _here();
    if (origin == null) {
      state = NavState(
        phase: NavPhase.unavailable,
        destination: place,
        message: 'Waiting for a location fix',
      );
      return;
    }
    state = NavState(phase: NavPhase.calculating, destination: place);
    try {
      final route = await ref
          .read(routingProviderProvider)
          .route(origin, place.point);
      if (!ref.mounted) return;
      _tracker = RouteTracker(route);
      state = NavState(
        phase: NavPhase.routeReady,
        destination: place,
        route: route,
        progress: _tracker!.progress(origin),
      );
    } catch (e) {
      AppLog.w('navigation', 'route failed: ${e.runtimeType}');
      if (ref.mounted) {
        state = NavState(
          phase: NavPhase.error,
          destination: place,
          message: 'Route unavailable. Check the internet connection.',
        );
      }
    }
  }

  void start() {
    if (state.phase != NavPhase.routeReady || state.route == null) return;
    _offCount = 0;
    state = state.copyWith(phase: NavPhase.navigating);
    final first = state.progress?.nextStep;
    ref
        .read(voiceGuidanceProvider)
        .say(
          first == null
              ? 'Starting route'
              : 'Starting route. ${first.instruction}',
        );
  }

  void cancel() {
    _tracker = null;
    ref.read(voiceGuidanceProvider).reset();
    state = const NavState();
  }

  @visibleForTesting
  void onPosition(GeoPoint p) {
    final tracker = _tracker;
    final dest = state.destination;
    if (tracker == null || dest == null || state.phase != NavPhase.navigating) {
      return;
    }
    final progress = tracker.progress(p);
    if (haversine(p, dest.point) < arrivalMeters ||
        progress.remainingMeters < arrivalMeters) {
      state = state.copyWith(phase: NavPhase.arrived, progress: progress);
      ref.read(voiceGuidanceProvider).say('You have arrived');
      return;
    }
    _offCount = progress.offRouteMeters > offRouteMeters ? _offCount + 1 : 0;
    state = state.copyWith(progress: progress);
    if (_offCount >= offRouteFixes &&
        DateTime.now().difference(_lastReroute) > rerouteInterval) {
      _reroute(p, dest);
    } else {
      ref.read(voiceGuidanceProvider).onProgress(progress);
    }
  }

  Future<void> _reroute(GeoPoint from, Place dest) async {
    _lastReroute = DateTime.now();
    _offCount = 0;
    state = state.copyWith(phase: NavPhase.rerouting);
    ref.read(voiceGuidanceProvider).say('Rerouting');
    try {
      final route = await ref
          .read(routingProviderProvider)
          .route(from, dest.point);
      if (!ref.mounted || state.phase != NavPhase.rerouting) return;
      _tracker = RouteTracker(route);
      ref.read(voiceGuidanceProvider).reset();
      state = state.copyWith(
        phase: NavPhase.navigating,
        route: route,
        progress: _tracker!.progress(from),
      );
    } catch (e) {
      AppLog.w('navigation', 'reroute failed: ${e.runtimeType}');
      // Keep guiding on the old route; the next deviation check will try again after the interval.
      if (ref.mounted && state.phase == NavPhase.rerouting) {
        state = state.copyWith(
          phase: NavPhase.navigating,
          message: 'Could not reroute (offline?)',
        );
      }
    }
  }
}

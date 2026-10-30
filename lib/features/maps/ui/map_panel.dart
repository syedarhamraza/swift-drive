import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/app_state.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/perf/perf_metrics.dart';
import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../apps/ui/app_picker.dart';
import '../../location/data/location_repository.dart';
import '../../location/state/location_providers.dart';
import '../../navigation/data/navigation_models.dart';
import '../../navigation/state/navigation_providers.dart';
import '../../navigation/ui/destination_sheet.dart';
import '../../navigation/ui/nav_banner.dart';

const _routeSource = 'sd-route';
const _styleTimeout = Duration(seconds: 20);

/// Embedded map. Created once and kept alive under pushed routes. The vehicle puck and follow-camera
/// are driven by our own LocationManager fixes through MapLibre's manual location source, so neither
/// location permission inside the plugin nor Google Play Services is involved.
class MapPanel extends ConsumerStatefulWidget {
  const MapPanel({super.key});

  @override
  ConsumerState<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends ConsumerState<MapPanel> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  bool _follow = true;
  bool _failed = false;
  bool _zoomedToFirstFix = false;
  int _generation = 0;
  Timer? _timeout;
  final _initWatch = Stopwatch();

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController c) {
    _controller = c;
    _initWatch
      ..reset()
      ..start();
    _timeout?.cancel();
    _timeout = Timer(_styleTimeout, () {
      if (!mounted || _styleLoaded) return;
      AppLog.e(
        'map',
        'style did not load within ${_styleTimeout.inSeconds}s (offline or blocked tile server?)',
      );
      setState(() => _failed = true);
    });
  }

  Future<void> _onStyleLoaded() async {
    _timeout?.cancel();
    PerfMetrics.mapInitTime ??= _initWatch.elapsed;
    AppLog.i('map', 'style loaded in ${_initWatch.elapsedMilliseconds} ms');
    final c = _controller;
    if (c == null) return;
    final accent = Theme.of(context).colorScheme.primary;
    try {
      await c.addGeoJsonSource(_routeSource, _routeGeoJson());
      await c.addLineLayer(
        _routeSource,
        'sd-route-line',
        LineLayerProperties(
          lineColor: _hex(accent),
          lineWidth: 7,
          lineCap: 'round',
          lineJoin: 'round',
          lineOpacity: 0.9,
        ),
        filter: [
          '==',
          ['geometry-type'],
          'LineString',
        ],
      );
      await c.addCircleLayer(
        _routeSource,
        'sd-destination',
        CircleLayerProperties(
          circleRadius: 9,
          circleColor: _hex(SdColors.warning),
          circleStrokeWidth: 3,
          circleStrokeColor: '#101114',
        ),
        filter: [
          '==',
          ['geometry-type'],
          'Point',
        ],
      );
    } catch (e) {
      AppLog.w('map', 'route layers failed: $e');
    }
    if (mounted) setState(() => _styleLoaded = true);
    final fix = ref.read(locationProvider).fix;
    if (fix != null) _pushFix(fix);
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  Map<String, Object> _routeGeoJson() {
    final nav = ref.read(navigationProvider);
    final features = <Map<String, Object>>[];
    final route = nav.route;
    if (route != null && route.geometry.length > 1) {
      features.add({
        'type': 'Feature',
        'properties': <String, Object>{},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in route.geometry) [p.lon, p.lat],
          ],
        },
      });
    }
    final dest = nav.destination;
    if (dest != null && route != null) {
      features.add({
        'type': 'Feature',
        'properties': <String, Object>{},
        'geometry': {
          'type': 'Point',
          'coordinates': [dest.point.lon, dest.point.lat],
        },
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  Future<void> _drawRoute(NavState nav) async {
    final c = _controller;
    if (c == null || !_styleLoaded) return;
    try {
      await c.setGeoJsonSource(_routeSource, _routeGeoJson());
      final route = nav.route;
      if (nav.phase == NavPhase.routeReady &&
          route != null &&
          route.geometry.length > 1) {
        // Route preview: show the whole route. Following resumes when guidance starts.
        setState(() => _follow = false);
        await c.animateCamera(
          CameraUpdate.newLatLngBounds(
            _bounds(route.geometry),
            left: 60,
            top: 140,
            right: 60,
            bottom: 60,
          ),
        );
      } else if (nav.phase == NavPhase.navigating) {
        _setFollow(true);
      }
    } catch (e) {
      AppLog.w('map', 'route draw failed: $e');
    }
  }

  LatLngBounds _bounds(List<GeoPoint> pts) {
    var minLat = pts.first.lat,
        maxLat = minLat,
        minLon = pts.first.lon,
        maxLon = minLon;
    for (final p in pts) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lon < minLon) minLon = p.lon;
      if (p.lon > maxLon) maxLon = p.lon;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }

  void _pushFix(LocationFix fix) {
    final c = _controller;
    if (c == null || !_styleLoaded) return;
    c
        .updateManualLocation(
          ManualLocationUpdate(
            target: LatLng(fix.lat, fix.lon),
            horizontalAccuracy: fix.accuracy,
            bearing: fix.bearing,
            speed: fix.speed,
            timestamp: DateTime.now(),
          ),
        )
        .catchError(
          (Object e) => AppLog.w('map', 'location update failed: $e'),
        );
    if (!_zoomedToFirstFix && _follow) {
      _zoomedToFirstFix = true;
      // Zoom only: moving the target would dismiss the native follow mode.
      c.animateCamera(CameraUpdate.zoomTo(15));
    }
  }

  MyLocationTrackingMode _trackingMode() {
    if (!_follow) return MyLocationTrackingMode.none;
    return ref.read(settingsProvider).headingUp
        ? MyLocationTrackingMode.trackingGps
        : MyLocationTrackingMode.tracking;
  }

  void _setFollow(bool follow) {
    if (_follow == follow) return;
    setState(() => _follow = follow);
    _controller?.updateMyLocationTrackingMode(_trackingMode());
  }

  void _retry() => setState(() {
    _failed = false;
    _styleLoaded = false;
    _controller = null;
    _generation++;
  });

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(settingsProvider.select((s) => s.mapEnabled));
    final ready = ref.watch(startupStageProvider.select((s) => s >= 4));
    final perf = ref.watch(settingsProvider.select((s) => s.performanceMode));
    final styles = ref.watch(
      settingsProvider.select((s) => (s.mapStyleLight, s.mapStyleDark)),
    );
    ref.watch(
      settingsProvider.select((s) => s.headingUp),
    ); // Rebuild to apply the tracking mode.
    final dark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(locationProvider.select((s) => s.fix), (_, fix) {
      if (fix != null) _pushFix(fix);
    });
    ref.listen(navigationProvider, (prev, nav) {
      if (prev?.route != nav.route || prev?.phase != nav.phase) _drawRoute(nav);
    });

    final overlay = _Overlay(
      follow: _follow,
      mapReady: enabled && !_failed && _styleLoaded,
      onRecenter: () => _setFollow(true),
      onZoomIn: () => _controller?.animateCamera(CameraUpdate.zoomIn()),
      onZoomOut: () => _controller?.animateCamera(CameraUpdate.zoomOut()),
    );

    if (!enabled || _failed) {
      return Stack(
        children: [
          Positioned.fill(
            child: _MapFallback(failed: _failed, onRetry: _retry),
          ),
          overlay,
        ],
      );
    }
    final lastFix = ref.read(locationProvider).fix;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: !ready
                ? const SizedBox.shrink()
                : RepaintBoundary(
                    child: MapLibreMap(
                      key: ValueKey(_generation),
                      styleString: dark ? styles.$2 : styles.$1,
                      initialCameraPosition: lastFix == null
                          ? const CameraPosition(target: LatLng(0, 0), zoom: 1)
                          : CameraPosition(
                              target: LatLng(lastFix.lat, lastFix.lon),
                              zoom: 15,
                            ),
                      onMapCreated: _onMapCreated,
                      onStyleLoadedCallback: _onStyleLoaded,
                      // Route and puck use our own layers. Plugin annotation managers would add 4 unused layers
                      // and race style reloads (STYLE_NOT_READY on theme switch).
                      annotationOrder: const [],
                      myLocationEnabled: true,
                      locationSource: const ManualLocationSource(),
                      myLocationTrackingMode: _trackingMode(),
                      myLocationRenderMode: MyLocationRenderMode.gps,
                      onCameraTrackingDismissed: () =>
                          setState(() => _follow = false),
                      compassEnabled: !perf,
                      tiltGesturesEnabled: false,
                      attributionButtonPosition:
                          AttributionButtonPosition.bottomLeft,
                    ),
                  ),
          ),
        ),
        if (ready && !_styleLoaded)
          const Center(child: CircularProgressIndicator()),
        overlay,
      ],
    );
  }
}

class _Overlay extends ConsumerWidget {
  const _Overlay({
    required this.follow,
    required this.mapReady,
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final bool follow;
  final bool mapReady;
  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasRoute = ref.watch(
      navigationProvider.select(
        (n) => n.destination != null && n.phase != NavPhase.idle,
      ),
    );
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(SdSpace.md),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: hasRoute
                  ? NavBanner(mapAvailable: mapReady)
                  : FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, SdSize.driveTarget),
                      ),
                      onPressed: () =>
                          showDestinationSheet(context, mapAvailable: mapReady),
                      icon: const Icon(Icons.search),
                      label: const Text('Where to?'),
                    ),
            ),
            if (mapReady)
              Align(
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Zoom in',
                      onPressed: onZoomIn,
                      icon: const Icon(Icons.add),
                    ),
                    const SizedBox(height: SdSpace.sm),
                    IconButton.filledTonal(
                      tooltip: 'Zoom out',
                      onPressed: onZoomOut,
                      icon: const Icon(Icons.remove),
                    ),
                    if (!follow) ...[
                      const SizedBox(height: SdSpace.sm),
                      IconButton.filled(
                        tooltip: 'Recenter',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(
                            SdSize.driveTarget,
                            SdSize.driveTarget,
                          ),
                        ),
                        onPressed: onRecenter,
                        icon: const Icon(Icons.my_location),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapFallback extends ConsumerWidget {
  const _MapFallback({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(SdSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusMessage(
              icon: Icons.map_outlined,
              title: failed ? 'Map could not load' : 'Embedded map is off',
              body: failed
                  ? 'Check the internet connection or the map style URL in Settings.'
                  : 'Enable it in Settings › Navigation.',
              actionLabel: failed ? 'Retry' : null,
              onAction: failed ? onRetry : null,
            ),
            const SizedBox(height: SdSpace.md),
            OutlinedButton.icon(
              onPressed: () => launchRole(context, ref, FactoryRole.navigation),
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Open navigation app'),
            ),
          ],
        ),
      ),
    ),
  );
}

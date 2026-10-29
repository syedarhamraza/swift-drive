import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftdrive/features/location/data/location_repository.dart';
import 'package:swiftdrive/features/location/state/location_providers.dart';
import 'package:swiftdrive/features/navigation/data/navigation_models.dart';
import 'package:swiftdrive/features/navigation/data/osm_providers.dart';
import 'package:swiftdrive/features/navigation/domain/route_geometry.dart';
import 'package:swiftdrive/features/navigation/state/navigation_providers.dart';

import '../fakes/fakes.dart';

// A straight 1.1 km route due north with a right turn halfway.
const start = GeoPoint(33.600, 73.0);
const mid = GeoPoint(33.605, 73.0);
const end = GeoPoint(33.610, 73.0);
const route = RouteResult(
  geometry: [start, mid, end],
  distanceMeters: 1112,
  durationSeconds: 120,
  steps: [
    RouteStep(instruction: 'Head out', location: start, type: 'depart'),
    RouteStep(
      instruction: 'Turn right',
      location: mid,
      type: 'turn',
      modifier: 'right',
    ),
    RouteStep(
      instruction: 'Arrive at destination',
      location: end,
      type: 'arrive',
    ),
  ],
);

void main() {
  group('geometry', () {
    test('haversine of 0.01° latitude is about 1.11 km', () {
      expect(haversine(start, end), closeTo(1112, 2));
    });

    test('progress finds remaining distance, ETA and next maneuver', () {
      final p = RouteTracker(route).progress(start);
      expect(p.offRouteMeters, lessThan(1));
      expect(p.remainingMeters, closeTo(1112, 2));
      expect(p.remainingSeconds, closeTo(120, 0.5));
      expect(p.nextStep!.instruction, 'Turn right');
      expect(p.metersToNextStep, closeTo(556, 2));
    });

    test('after passing the turn the next maneuver is arrival', () {
      final p = RouteTracker(route).progress(const GeoPoint(33.607, 73.0));
      expect(p.nextStep!.type, 'arrive');
      expect(p.remainingSeconds, closeTo(120 * p.remainingMeters / 1112, 1));
    });

    test('off-route distance is perpendicular to the polyline', () {
      final p = RouteTracker(route).progress(const GeoPoint(33.605, 73.001));
      expect(p.offRouteMeters, closeTo(92.7, 1));
    });
  });

  group('OSRM', () {
    test('parses geometry, totals and steps', () {
      final r = parseOsrmRoute({
        'code': 'Ok',
        'routes': [
          {
            'distance': 1000.5,
            'duration': 90,
            'geometry': {
              'coordinates': [
                [73.0, 33.6],
                [73.0, 33.61],
              ],
            },
            'legs': [
              {
                'steps': [
                  {
                    'name': 'Jinnah Avenue',
                    'maneuver': {
                      'type': 'depart',
                      'location': [73.0, 33.6],
                    },
                  },
                  {
                    'name': '',
                    'maneuver': {
                      'type': 'turn',
                      'modifier': 'left',
                      'location': [73.0, 33.61],
                    },
                  },
                ],
              },
            ],
          },
        ],
      });
      expect(r.geometry.first, start);
      expect(r.distanceMeters, 1000.5);
      expect(r.steps.map((s) => s.instruction), [
        'Head along Jinnah Avenue',
        'Turn left',
      ]);
    });

    test('non-Ok response throws', () {
      expect(() => parseOsrmRoute({'code': 'NoRoute'}), throwsFormatException);
    });

    test('maneuverText', () {
      expect(
        maneuverText('turn', 'sharp right', 'Main St'),
        'Turn sharp right onto Main St',
      );
      expect(maneuverText('roundabout', null, null), 'Enter the roundabout');
      expect(maneuverText('turn', 'uturn', null), 'Make a U-turn');
      expect(maneuverText('new name', 'straight', 'X'), 'Continue onto X');
      expect(maneuverText('fork', 'left', null), 'Keep left at the fork');
    });
  });

  group('state machine', () {
    late Fakes fakes;
    late ProviderContainer c;

    Future<void> fixAt(GeoPoint p) async {
      fakes.location.events$.add(
        LocationFix(
          provider: 'gps',
          lat: p.lat,
          lon: p.lon,
          fixTime: monotonicNow(),
          accuracy: 5,
          speed: 10,
        ),
      );
      await pumpEventQueue();
    }

    setUp(() async {
      fakes = Fakes();
      c = await makeContainer(fakes);
      c.listen(locationProvider, (_, _) {});
      c.listen(navigationProvider, (_, _) {});
    });
    tearDown(() => c.dispose());

    NavState nav() => c.read(navigationProvider);
    const place = Place('Destination', end);

    test('choosing without a fix is unavailable, not an error', () async {
      await c.read(navigationProvider.notifier).choose(place);
      expect(nav().phase, NavPhase.unavailable);
      expect(fakes.routing.calls, 0);
    });

    test('search with no results returns to idle with a message', () async {
      await c.read(navigationProvider.notifier).search('nowhere');
      expect(nav().phase, NavPhase.idle);
      expect(nav().message, 'No places found');
    });

    test('offline routing becomes an error state', () async {
      await fixAt(start);
      await c.read(navigationProvider.notifier).choose(place);
      expect(nav().phase, NavPhase.error);
    });

    test(
      'route → navigate → reroute after 3 off-route fixes → arrive',
      () async {
        fakes.routing.result = route;
        await fixAt(start);
        final ctl = c.read(navigationProvider.notifier);
        await ctl.choose(place);
        expect(nav().phase, NavPhase.routeReady);

        ctl.start();
        expect(nav().phase, NavPhase.navigating);
        expect(fakes.voice.spoken.last, 'Starting route. Turn right');

        const off = GeoPoint(33.602, 73.002);
        await fixAt(off);
        await fixAt(off);
        expect(fakes.routing.calls, 1);
        await fixAt(off);
        await pumpEventQueue();
        expect(fakes.routing.calls, 2);
        expect(fakes.voice.spoken, contains('Rerouting'));
        expect(nav().phase, NavPhase.navigating);

        await fixAt(end);
        expect(nav().phase, NavPhase.arrived);
        expect(fakes.voice.spoken.last, 'You have arrived');

        ctl.cancel();
        expect(nav().phase, NavPhase.idle);
      },
    );
  });

  group('voice thresholds', () {
    RouteProgress at(double d, [int idx = 1]) => RouteProgress(
      offRouteMeters: 0,
      remainingMeters: 1000,
      remainingSeconds: 60,
      nextStep: route.steps[idx],
      nextStepIndex: idx,
      metersToNextStep: d,
    );

    test('announces at 500 m and 100 m once each', () async {
      final v = FakeVoice();
      for (final d in [700.0, 480.0, 450.0, 90.0, 40.0]) {
        v.onProgress(at(d));
      }
      expect(v.spoken, ['In 500 metres, Turn right', 'Turn right']);
    });

    test('a late start inside 100 m says only the turn', () {
      final v = FakeVoice()..onProgress(at(60));
      v.onProgress(at(30));
      expect(v.spoken, ['Turn right']);
    });
  });
}

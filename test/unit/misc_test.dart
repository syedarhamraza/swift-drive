import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftdrive/core/format.dart';
import 'package:swiftdrive/core/platform/platform_failure.dart';
import 'package:swiftdrive/core/storage/settings.dart';
import 'package:swiftdrive/core/theme/theme_providers.dart';
import 'package:swiftdrive/features/dashboard/domain/dashboard_layout.dart';
import 'package:swiftdrive/features/diagnostics/data/device_repository.dart';
import 'package:swiftdrive/features/notifications/data/notifications_repository.dart';
import 'package:swiftdrive/features/weather/data/weather_repository.dart';

void main() {
  group('capabilities and failures', () {
    test(
      'parseCapabilityStatus maps native strings; unknown stays unknown',
      () {
        expect(parseCapabilityStatus('AVAILABLE'), CapabilityStatus.available);
        expect(
          parseCapabilityStatus('PERMISSION_REQUIRED'),
          CapabilityStatus.permissionRequired,
        );
        expect(
          parseCapabilityStatus('UNSUPPORTED'),
          CapabilityStatus.unsupported,
        );
        expect(parseCapabilityStatus('garbage'), CapabilityStatus.unknown);
        expect(parseCapabilityStatus(null), CapabilityStatus.unknown);
      },
    );

    test('native error codes map to typed failures', () {
      expect(
        PlatformFailure.kindForCode('PERMISSION_DENIED'),
        FailureKind.permissionDenied,
      );
      expect(
        PlatformFailure.kindForCode('ACTIVITY_NOT_FOUND'),
        FailureKind.activityMissing,
      );
      expect(PlatformFailure.kindForCode('TIMEOUT'), FailureKind.timeout);
      expect(PlatformFailure.kindForCode('???'), FailureKind.unexpected);
    });

    test('DeviceReport.fromMap tolerates missing fields', () {
      final r = DeviceReport.fromMap({
        'capabilities': [
          {'id': 'gps', 'label': 'GPS', 'status': 'AVAILABLE'},
        ],
      });
      expect(r.adapterName, 'Unknown');
      expect(r.statusOf('gps'), CapabilityStatus.available);
      expect(r.statusOf('radio'), CapabilityStatus.unknown);
    });
  });

  group('sunPhase', () {
    final rise = DateTime(2026, 1, 1, 6, 30);
    final set = DateTime(2026, 1, 1, 18);
    test('before sunrise is night until sunrise', () {
      expect(sunPhase(DateTime(2026, 3, 5, 5), rise, set), (
        false,
        DateTime(2026, 3, 5, 6, 30),
      ));
    });
    test('daytime until sunset', () {
      expect(sunPhase(DateTime(2026, 3, 5, 12), rise, set), (
        true,
        DateTime(2026, 3, 5, 18),
      ));
    });
    test('after sunset is night until tomorrow sunrise', () {
      expect(sunPhase(DateTime(2026, 3, 5, 22), rise, set), (
        false,
        DateTime(2026, 3, 6, 6, 30),
      ));
    });
  });

  group('dashboard geometry', () {
    test(
      'landscape head unit puts the dock on the left with preset ratios',
      () {
        final g = computeDashboardGeometry(
          const Size(1280, 720),
          DashboardLayout.mapFocused,
        );
        expect(g.dockOnLeft, isTrue);
        expect(g.stacked, isFalse);
        expect((g.mapFlex, g.sideFlex), (66, 34));
      },
    );
    test('small screens fall back to compact', () {
      final g = computeDashboardGeometry(
        const Size(720, 450),
        DashboardLayout.mediaFocused,
      );
      expect((g.mapFlex, g.sideFlex), (58, 42));
    });
    test('portrait stacks', () {
      expect(
        computeDashboardGeometry(
          const Size(800, 1280),
          DashboardLayout.balanced,
        ).stacked,
        isTrue,
      );
    });
    test('wide head units give the pager its own column', () {
      final g = computeDashboardGeometry(
        const Size(1280, 800),
        DashboardLayout.balanced,
      );
      expect(g.pagerBeside, isTrue);
      expect(g.column, [DashboardWidget.notifications, DashboardWidget.media]);
      expect(g.pager, [DashboardWidget.weather, DashboardWidget.speed]);
    });
    test('narrower screens share one column and page notifications', () {
      for (final size in const [Size(933, 420), Size(683, 400)]) {
        final g = computeDashboardGeometry(size, DashboardLayout.balanced);
        expect(g.pagerBeside, isFalse, reason: '$size');
        expect(g.column, [DashboardWidget.media]);
        expect(g.pager, contains(DashboardWidget.notifications));
      }
      expect(
        computeDashboardGeometry(
          const Size(1280, 800),
          DashboardLayout.mapFocused,
        ).pagerBeside,
        isFalse,
        reason: 'a narrow side panel does not split',
      );
    });
    test('hidden speed and an unconfigured radio are left out', () {
      final g = computeDashboardGeometry(
        const Size(1920, 720),
        DashboardLayout.mediaFocused,
        showSpeed: false,
      );
      expect(g.widgets, isNot(contains(DashboardWidget.speed)));
      expect(g.widgets, isNot(contains(DashboardWidget.radio)));
      final r = computeDashboardGeometry(
        const Size(1920, 720),
        DashboardLayout.mediaFocused,
        radioConfigured: true,
      );
      expect(r.widgets, contains(DashboardWidget.radio));
    });
  });

  test(
    'essential notifications exclude low importance and promo categories',
    () {
      NotificationItem n({int? importance, String? category}) =>
          NotificationItem(
            key: 'k',
            packageName: 'p',
            appLabel: 'P',
            postTime: DateTime(2026),
            clearable: true,
            importance: importance,
            category: category,
          );
      expect(
        isEssentialNotification(n(importance: 4, category: 'msg')),
        isTrue,
      );
      expect(isEssentialNotification(n()), isTrue);
      expect(isEssentialNotification(n(importance: 2)), isFalse);
      expect(
        isEssentialNotification(n(importance: 4, category: 'promo')),
        isFalse,
      );
    },
  );

  group('format', () {
    test('distance', () {
      expect(formatDistance(234, SpeedUnit.kmh), '230 m');
      expect(formatDistance(2345, SpeedUnit.kmh), '2.3 km');
      expect(formatDistance(23456, SpeedUnit.kmh), '23 km');
      expect(formatDistance(50, SpeedUnit.mph), '160 ft');
      expect(formatDistance(3218.7, SpeedUnit.mph), '2.0 mi');
    });
    test('duration', () {
      expect(formatDuration(600), '10 min');
      expect(formatDuration(3900), '1 h 5 min');
    });
    test('clock', () {
      final t = DateTime(2026, 1, 1, 14, 5);
      expect(formatClock(t, use24h: true), '14:05');
      expect(formatClock(t, use24h: false), '2:05 PM');
    });
    test('age', () {
      final now = DateTime(2026, 1, 1, 12);
      expect(
        formatAge(now.subtract(const Duration(seconds: 30)), now),
        'just now',
      );
      expect(
        formatAge(now.subtract(const Duration(minutes: 5)), now),
        '5 min ago',
      );
      expect(formatAge(now.subtract(const Duration(hours: 3)), now), '3 h ago');
    });
    test('temperature', () {
      expect(formatTemperature(21.6, TempUnit.celsius), '22°C');
      expect(formatTemperature(0, TempUnit.fahrenheit), '32°F');
      expect(formatDegrees(21.6, TempUnit.celsius), '22°');
      expect(formatDegrees(0, TempUnit.fahrenheit), '32°');
    });
  });

  group('weather forecast', () {
    test('parses hourly and daily data and skips incomplete entries', () {
      const h = 1793365200; // a whole hour, unix seconds
      final w = WeatherData.fromOpenMeteo({
        'current': {
          'temperature_2m': 20.3,
          'weather_code': 0,
          'is_day': 0,
          'apparent_temperature': 19.5,
        },
        'hourly': {
          'time': [h, h + 3600, h + 7200],
          'temperature_2m': [20.8, null, 19.0],
          'weather_code': [0, 1, 2],
          'is_day': [1, 0, 0],
        },
        'daily': {
          'time': [h, h + 86400],
          'sunrise': [h - 40000, h + 46400],
          'sunset': [h - 2000, h + 84400],
          'temperature_2m_max': [25.8, 25.7],
          'temperature_2m_min': [16.1, 15.2],
          'weather_code': [0, 3],
        },
      }, DateTime(2026));
      expect(w.feelsLikeC, 19.5);
      expect(w.hourly.map((p) => p.tempC), [20.8, 19.0]);
      expect(w.hourly.last.isDay, isFalse);
      expect(w.daily.map((p) => (p.tempC, p.minC, p.code)), [
        (25.8, 16.1, 0),
        (25.7, 15.2, 3),
      ]);
      // Round trip through the cache keeps the forecast.
      final cached = WeatherData.fromJson(w.toJson());
      expect(cached.daily.last.minC, 15.2);
      expect(cached.hourly, hasLength(2));
    });

    test('a cache written before forecasts existed still loads', () {
      final w = WeatherData.fromJson({
        't': 21.0,
        'code': 1,
        'isDay': true,
        'fetchedAt': '2026-10-30T10:00:00.000',
      });
      expect(w.hourly, isEmpty);
      expect(w.daily, isEmpty);
      expect(w.feelsLikeC, isNull);
    });
  });
}

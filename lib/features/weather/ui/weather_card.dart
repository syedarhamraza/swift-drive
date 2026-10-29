import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../location/state/location_providers.dart';
import '../data/weather_repository.dart';
import '../state/weather_providers.dart';

class WeatherSummary extends ConsumerWidget {
  const WeatherSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(weatherProvider);
    final unit = ref.watch(settingsProvider.select((s) => s.tempUnit));
    final hasFix = ref.watch(locationProvider.select((s) => s.fix != null));
    final t = Theme.of(context).textTheme;
    final data = weather.data;

    if (data == null) {
      final reason = weather.failed
          ? 'Offline — no cached weather'
          : (hasFix ? 'Loading weather…' : 'Weather needs a location');
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: SdSpace.sm),
          Flexible(child: Text(reason, style: t.bodySmall, maxLines: 2)),
        ],
      );
    }

    final (label, icon) = describeWeatherCode(data.code, isDay: data.isDay);
    final age = formatAge(data.fetchedAt, DateTime.now());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40),
        const SizedBox(width: SdSpace.md),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatTemperature(data.temperatureC, unit),
                style: t.headlineSmall,
              ),
              Text(
                [label, ?data.locationName].join(' · '),
                style: t.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                weather.failed ? 'Offline · updated $age' : 'Updated $age',
                style: t.bodySmall?.copyWith(
                  color: weather.failed ? SdColors.warning : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

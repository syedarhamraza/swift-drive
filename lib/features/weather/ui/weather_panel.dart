import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../data/weather_repository.dart';
import '../state/weather_providers.dart';
import 'weather_card.dart';

/// Full weather page: now, feels-like, today's range, the next hours and the next days. Rows that do not
/// fit the available height are left out instead of scrolling.
class WeatherPanel extends ConsumerWidget {
  const WeatherPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(weatherProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24h));
    final data = weather.data;
    // The sky gradient is dark in both themes, so text and icons are light.
    final theme = onDarkBackdrop(Theme.of(context));
    final t = theme.textTheme;

    if (data == null) {
      return Theme(
        data: theme,
        child: SdCard(
          gradient: _sky(null),
          child: const Center(child: WeatherSummary()),
        ),
      );
    }

    final now = DateTime.now();
    final (label, icon) = describeWeatherCode(data.code, isDay: data.isDay);
    final today = data.daily.firstOrNull;
    final hours = data.hourlyFrom(now).take(5).toList();
    final days = data.daily.skip(1).take(3).toList();

    return Theme(
      data: theme,
      child: SdCard(
        gradient: _sky(data),
        // Extra right padding keeps content clear of the pager dots.
        padding: const EdgeInsets.fromLTRB(
          SdSpace.lg,
          SdSpace.md,
          36,
          SdSpace.sm,
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            // Short cards (a phone in landscape) trade the place line for the hourly row.
            final short = box.maxHeight < 190;
            final showHours = hours.length > 1 && box.maxHeight >= 140;
            final showDays = days.isNotEmpty && box.maxHeight >= 330;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!short) ...[
                  Text(
                    data.locationName ?? DateFormat.MMMEd().format(now),
                    style: t.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: SdSpace.xs),
                ],
                _Now(data: data, today: today, label: label, icon: icon),
                if (showHours) ...[
                  SizedBox(height: short ? SdSpace.sm : SdSpace.md),
                  _Hours(hours: hours, use24h: use24h),
                ],
                if (showDays) ...[
                  const SizedBox(height: SdSpace.md),
                  _Days(days: days),
                ],
                const Spacer(),
                // Open-Meteo data is CC BY 4.0: credit the source.
                Text(
                  weather.failed
                      ? 'Offline · updated ${formatAge(data.fetchedAt, now)} · Open-Meteo'
                      : 'Weather: Open-Meteo · ${formatAge(data.fetchedAt, now)}',
                  style: t.bodySmall?.copyWith(
                    fontSize: 12,
                    color: weather.failed ? SdColors.warning : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Sky colours: blue by day, indigo at night, slate when overcast, foggy, raining or snowing.
LinearGradient _sky(WeatherData? d) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: switch (d) {
    null => const [Color(0xFF2C3E5C), Color(0xFF16202F)],
    WeatherData(code: >= 3) => const [Color(0xFF4A5A70), Color(0xFF1F2733)],
    WeatherData(isDay: true) => const [Color(0xFF3A86D4), Color(0xFF1C4F91)],
    _ => const [Color(0xFF2E3A78), Color(0xFF111633)],
  },
);

class _Now extends ConsumerWidget {
  const _Now({
    required this.data,
    required this.today,
    required this.label,
    required this.icon,
  });

  final WeatherData data;
  final ForecastPoint? today;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(settingsProvider.select((s) => s.tempUnit));
    final t = Theme.of(context).textTheme;
    final low = today?.minC;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 28),
                  const SizedBox(width: SdSpace.sm),
                  Flexible(
                    child: Text(
                      label,
                      style: t.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // One line, so the hourly row still fits on short screens.
              Text(
                [
                  if (data.feelsLikeC != null)
                    'Feels like ${formatDegrees(data.feelsLikeC!, unit)}',
                  if (today != null && low != null)
                    '${formatDegrees(today!.tempC, unit)} / ${formatDegrees(low, unit)}',
                ].join(' · '),
                style: t.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatDegrees(data.temperatureC, unit),
            style: t.displayMedium,
          ),
        ),
      ],
    );
  }
}

class _Hours extends ConsumerWidget {
  const _Hours({required this.hours, required this.use24h});

  final List<ForecastPoint> hours;
  final bool use24h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(settingsProvider.select((s) => s.tempUnit));
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final (i, h) in hours.indexed)
          Expanded(
            child: Column(
              children: [
                Text(formatDegrees(h.tempC, unit), style: t.bodyMedium),
                const SizedBox(height: SdSpace.xs),
                Icon(describeWeatherCode(h.code, isDay: h.isDay).$2, size: 22),
                const SizedBox(height: SdSpace.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    i == 0
                        ? 'Now'
                        : (use24h ? DateFormat.H() : DateFormat.j()).format(
                            h.time,
                          ),
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Days extends ConsumerWidget {
  const _Days({required this.days});

  final List<ForecastPoint> days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(settingsProvider.select((s) => s.tempUnit));
    final t = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(SdRadius.button),
      ),
      child: Column(
        children: [
          for (final d in days)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SdSpace.md,
                vertical: SdSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat.EEEE().format(d.time),
                      style: t.bodyLarge,
                    ),
                  ),
                  Text(
                    [
                      formatDegrees(d.tempC, unit),
                      if (d.minC != null) formatDegrees(d.minC!, unit),
                    ].join('  '),
                    style: t.bodyMedium,
                  ),
                  const SizedBox(width: SdSpace.sm),
                  Icon(describeWeatherCode(d.code, isDay: true).$2, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

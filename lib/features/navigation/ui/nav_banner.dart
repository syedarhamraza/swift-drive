import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../data/navigation_models.dart';
import '../state/navigation_providers.dart';
import 'destination_sheet.dart';

IconData maneuverIcon(RouteStep step) {
  final m = step.modifier ?? 'straight';
  return switch (step.type) {
    'arrive' => Icons.flag,
    'roundabout' || 'rotary' => Icons.roundabout_right,
    'merge' => Icons.merge,
    'fork' => m.contains('left') ? Icons.fork_left : Icons.fork_right,
    'on ramp' ||
    'off ramp' => m.contains('left') ? Icons.ramp_left : Icons.ramp_right,
    _ => switch (m) {
      'left' => Icons.turn_left,
      'right' => Icons.turn_right,
      'slight left' => Icons.turn_slight_left,
      'slight right' => Icons.turn_slight_right,
      'sharp left' => Icons.turn_sharp_left,
      'sharp right' => Icons.turn_sharp_right,
      'uturn' => Icons.u_turn_left,
      _ => Icons.straight,
    },
  };
}

/// Route status over the map. Maneuvers come only from the routing provider's step data.
class NavBanner extends ConsumerWidget {
  const NavBanner({super.key, required this.mapAvailable});

  final bool mapAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigationProvider);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(navigationProvider.notifier);
    final t = Theme.of(context).textTheme;
    final progress = nav.progress;
    final step = progress?.nextStep;

    final Widget headline = switch (nav.phase) {
      NavPhase.calculating => const Text('Calculating route…'),
      NavPhase.rerouting => const Text('Rerouting…'),
      NavPhase.arrived => const Text('You have arrived'),
      NavPhase.error ||
      NavPhase.unavailable => Text(nav.message ?? 'Route unavailable'),
      NavPhase.routeReady => Text(
        nav.destination?.name ?? 'Route ready',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      _ when step != null => Row(
        children: [
          Icon(maneuverIcon(step), size: 44),
          const SizedBox(width: SdSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDistance(
                    progress!.metersToNextStep ?? 0,
                    settings.speedUnit,
                  ),
                  style: t.headlineSmall,
                ),
                Text(
                  step.instruction,
                  style: t.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      _ => Text('Head to ${nav.destination?.name ?? 'destination'}'),
    };

    final remaining = progress == null
        ? null
        : '${formatDistance(progress.remainingMeters, settings.speedUnit)} · ${formatDuration(progress.remainingSeconds)} · '
              'ETA ${formatClock(DateTime.now().add(Duration(seconds: progress.remainingSeconds.round())), use24h: settings.use24h)}';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(SdSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle(style: t.titleMedium!, child: headline),
              if (remaining != null && nav.phase != NavPhase.arrived) ...[
                const SizedBox(height: SdSpace.xs),
                Text(remaining, style: t.bodyMedium),
              ],
              const SizedBox(height: SdSpace.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (nav.phase == NavPhase.routeReady && mapAvailable)
                    FilledButton(
                      onPressed: controller.start,
                      child: const Text('Start'),
                    ),
                  if (nav.destination != null && nav.phase != NavPhase.arrived)
                    IconButton(
                      tooltip: 'Open in navigation app',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => openExternalNavigation(
                        context,
                        ref,
                        nav.destination!,
                      ),
                    ),
                  if (nav.isGuiding)
                    IconButton(
                      tooltip: settings.voiceMuted
                          ? 'Unmute voice'
                          : 'Mute voice',
                      icon: Icon(
                        settings.voiceMuted
                            ? Icons.volume_off
                            : Icons.volume_up,
                      ),
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .update((s) => s.copyWith(voiceMuted: !s.voiceMuted)),
                    ),
                  IconButton(
                    tooltip: 'End route',
                    icon: const Icon(Icons.close),
                    onPressed: controller.cancel,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

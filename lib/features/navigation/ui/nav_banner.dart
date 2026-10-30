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

/// Next maneuver (green while guiding) or the route status, top-left over the map. Maneuvers come only
/// from the routing provider's step data.
class ManeuverCard extends ConsumerWidget {
  const ManeuverCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigationProvider);
    final unit = ref.watch(settingsProvider.select((s) => s.speedUnit));
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final progress = nav.progress;
    final step = progress?.nextStep;
    final guiding =
        step != null &&
        (nav.phase == NavPhase.navigating || nav.phase == NavPhase.rerouting);
    final fg = guiding ? Colors.white : scheme.onSurface;

    final Widget content = guiding
        ? Row(
            children: [
              Icon(maneuverIcon(step), size: 52, color: fg),
              const SizedBox(width: SdSpace.md),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nav.phase == NavPhase.rerouting
                          ? 'Rerouting…'
                          : formatDistance(
                              progress!.metersToNextStep ?? 0,
                              unit,
                            ),
                      style: t.titleMedium?.copyWith(color: Colors.white70),
                    ),
                    Text(
                      step.instruction,
                      style: t.titleLarge?.copyWith(color: fg),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          )
        : Text(
            switch (nav.phase) {
              NavPhase.calculating => 'Calculating route…',
              NavPhase.rerouting => 'Rerouting…',
              NavPhase.arrived => 'You have arrived',
              NavPhase.error ||
              NavPhase.unavailable => nav.message ?? 'Route unavailable',
              NavPhase.routeReady => nav.destination?.name ?? 'Route ready',
              _ => 'Head to ${nav.destination?.name ?? 'destination'}',
            },
            style: t.titleMedium?.copyWith(color: fg),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: AnimatedContainer(
        duration: SdMotion.of(context, SdMotion.medium),
        curve: SdMotion.curve,
        padding: const EdgeInsets.symmetric(
          horizontal: SdSpace.lg,
          vertical: SdSpace.md,
        ),
        decoration: BoxDecoration(
          color: guiding ? SdColors.navGreen : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(SdRadius.card),
        ),
        // Each new maneuver slides up into place.
        child: AnimatedSwitcher(
          duration: SdMotion.of(context, SdMotion.medium),
          switchInCurve: SdMotion.curve,
          switchOutCurve: SdMotion.exitCurve,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey((nav.phase, progress?.nextStepIndex)),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Bottom-left pill: end route, remaining time and arrival, and the route actions.
class EtaPill extends ConsumerWidget {
  const EtaPill({super.key, required this.mapAvailable});

  final bool mapAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigationProvider);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(navigationProvider.notifier);
    final t = Theme.of(context).textTheme;
    final progress = nav.progress;
    final arrived = nav.phase == NavPhase.arrived;

    final Widget summary;
    if (progress != null && !arrived) {
      final arrival = DateTime.now().add(
        Duration(seconds: progress.remainingSeconds.round()),
      );
      summary = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: formatDuration(progress.remainingSeconds),
              style: const TextStyle(
                color: SdColors.etaGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text:
                  ' · ${formatClock(arrival, use24h: settings.use24h)} · '
                  '${formatDistance(progress.remainingMeters, settings.speedUnit)}',
            ),
          ],
        ),
        style: t.titleMedium,
        maxLines: 1,
      );
    } else {
      summary = Text(
        nav.destination?.name ?? 'Route',
        style: t.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SdSpace.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'End route',
              icon: const Icon(Icons.close),
              onPressed: controller.cancel,
            ),
            Flexible(child: summary),
            const SizedBox(width: SdSpace.sm),
            if (nav.phase == NavPhase.routeReady && mapAvailable)
              FilledButton(
                onPressed: controller.start,
                child: const Text('Start'),
              ),
            if (nav.destination != null && !arrived)
              IconButton(
                tooltip: 'Open in navigation app',
                icon: const Icon(Icons.open_in_new),
                onPressed: () =>
                    openExternalNavigation(context, ref, nav.destination!),
              ),
            if (nav.isGuiding)
              IconButton(
                tooltip: settings.voiceMuted ? 'Unmute voice' : 'Mute voice',
                icon: Icon(
                  settings.voiceMuted ? Icons.volume_off : Icons.volume_up,
                ),
                onPressed: () => ref
                    .read(settingsProvider.notifier)
                    .update((s) => s.copyWith(voiceMuted: !s.voiceMuted)),
              ),
          ],
        ),
      ),
    );
  }
}

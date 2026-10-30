import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../launcher/data/launcher_repository.dart';
import '../../launcher/state/launcher_providers.dart';
import '../domain/speed.dart';
import '../state/location_providers.dart';

/// Informational GPS speed. Not a replacement for the instrument cluster.
class SpeedCard extends ConsumerWidget {
  const SpeedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(locationProvider.select((s) => s.speed));
    final unit = ref.watch(settingsProvider.select((s) => s.speedUnit));
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final unitLabel = unit == SpeedUnit.kmh ? 'km/h' : 'mph';
    final valid =
        speed.status == SpeedStatus.valid && speed.metersPerSecond != null;

    final Widget body = valid
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                convertSpeed(speed.metersPerSecond!, unit).round().toString(),
                style: t.displayLarge?.copyWith(
                  fontSize: 112,
                  height: 1,
                  fontWeight: FontWeight.w300,
                ),
              ),
              Text(
                unitLabel,
                style: t.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          )
        : _Status(status: speed.status);

    // Fills its pager page: a header, then the reading centred in the remaining space.
    return SdCard(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.alphaBlend(
            scheme.secondary.withValues(alpha: 0.22),
            scheme.surface,
          ),
          scheme.surface,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                valid ? Icons.gps_fixed : Icons.gps_not_fixed,
                size: 18,
                color: valid ? SdColors.etaGreen : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: SdSpace.sm),
              Text('GPS speed', style: t.titleSmall),
              const SizedBox(width: SdSpace.sm),
              Expanded(
                child: Text(
                  'Informational',
                  textAlign: TextAlign.end,
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Clear of the pager dots.
              const SizedBox(width: 28),
            ],
          ),
          Expanded(
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: body),
            ),
          ),
        ],
      ),
    );
  }
}

class _Status extends ConsumerWidget {
  const _Status({required this.status});

  final SpeedStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final (text, icon, action, onAction) = switch (status) {
      SpeedStatus.acquiring => (
        'Acquiring GPS…',
        Icons.location_searching,
        null,
        null,
      ),
      SpeedStatus.poorAccuracy => (
        'GPS signal weak',
        Icons.gps_not_fixed,
        null,
        null,
      ),
      SpeedStatus.stale => (
        'No recent GPS fix',
        Icons.gps_not_fixed,
        null,
        null,
      ),
      SpeedStatus.gpsDisabled => (
        'GPS is off',
        Icons.gps_off,
        'Turn on',
        () => ref
            .read(launcherRepositoryProvider)
            .openSettings(SettingsPage.location),
      ),
      SpeedStatus.permissionDenied => (
        'Location not allowed',
        Icons.location_disabled,
        'Allow',
        () => requestLocation(ref),
      ),
      SpeedStatus.unavailable => (
        'No GPS on this device',
        Icons.gps_off,
        null,
        null,
      ),
      SpeedStatus.valid => ('—', Icons.gps_fixed, null, null),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: scheme.secondaryContainer,
          child: Icon(icon, size: 32, color: scheme.onSecondaryContainer),
        ),
        const SizedBox(height: SdSpace.md),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
        if (action != null) ...[
          const SizedBox(height: SdSpace.md),
          FilledButton.tonal(onPressed: onAction, child: Text(action)),
        ],
      ],
    );
  }
}

/// Requests location permission and restarts updates if granted. If the system no longer shows the
/// dialog (permanently denied), opens the app's settings page instead.
Future<void> requestLocation(WidgetRef ref) async {
  final repo = ref.read(launcherRepositoryProvider);
  try {
    if (await repo.requestPermission(AppPermission.location)) {
      ref.invalidate(permissionsProvider);
      await ref.read(locationProvider.notifier).restart();
    } else {
      await repo.openSettings(SettingsPage.appDetails);
    }
  } catch (_) {
    // Failures are logged by guardPlatform; the card keeps showing the permission state.
  }
}

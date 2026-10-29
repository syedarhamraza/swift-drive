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
    final t = Theme.of(context).textTheme;
    final unitLabel = unit == SpeedUnit.kmh ? 'km/h' : 'mph';

    Widget body;
    if (speed.status == SpeedStatus.valid && speed.metersPerSecond != null) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            convertSpeed(speed.metersPerSecond!, unit).round().toString(),
            style: t.displayMedium,
          ),
          const SizedBox(width: SdSpace.sm),
          Text(unitLabel, style: t.titleMedium),
        ],
      );
    } else {
      body = _StatusLine(status: speed.status);
    }

    return SdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('GPS speed', style: t.bodySmall),
          const SizedBox(height: SdSpace.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: body,
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends ConsumerWidget {
  const _StatusLine({required this.status});

  final SpeedStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (text, action, onAction) = switch (status) {
      SpeedStatus.acquiring => ('Acquiring GPS…', null, null),
      SpeedStatus.poorAccuracy => ('GPS signal weak', null, null),
      SpeedStatus.stale => ('No recent GPS fix', null, null),
      SpeedStatus.gpsDisabled => (
        'GPS is off',
        'Turn on',
        () => ref
            .read(launcherRepositoryProvider)
            .openSettings(SettingsPage.location),
      ),
      SpeedStatus.permissionDenied => (
        'Location not allowed',
        'Allow',
        () => requestLocation(ref),
      ),
      SpeedStatus.unavailable => ('No GPS on this device', null, null),
      SpeedStatus.valid => ('—', null, null),
    };
    return Row(
      children: [
        Text(text, style: Theme.of(context).textTheme.titleMedium),
        if (action != null) ...[
          const SizedBox(width: SdSpace.md),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../bluetooth/state/bluetooth_providers.dart';
import '../../location/ui/speed_card.dart';
import '../../notifications/state/notifications_providers.dart';
import '../data/launcher_repository.dart';
import '../state/launcher_providers.dart';

/// Each permission is requested individually, only when the user asks for the feature.
class PermissionsSection extends ConsumerWidget {
  const PermissionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider).value;
    final notifAccess = ref.watch(
      notificationsProvider.select((s) => s.access),
    );
    final repo = ref.read(launcherRepositoryProvider);
    final noBluetooth = ref.watch(
      bluetoothProvider.select((b) => b != null && !b.supported),
    );

    Widget tile(
      IconData icon,
      String title,
      String why,
      bool? granted,
      VoidCallback onRequest, {
      bool unavailable = false,
    }) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(why),
      trailing: unavailable
          ? const Text('Not on this device')
          : granted == true
          ? const Icon(Icons.check_circle, color: SdColors.success)
          : FilledButton.tonal(
              onPressed: onRequest,
              child: const Text('Allow'),
            ),
    );

    return Column(
      children: [
        tile(
          Icons.location_on_outlined,
          'Location',
          'Map position, GPS speed, weather and routing',
          perms?.location,
          () => requestLocation(ref),
        ),
        tile(
          Icons.notifications_outlined,
          'Notification access',
          'Now-playing media controls and notification list',
          notifAccess,
          () => repo.openSettings(SettingsPage.notificationAccess),
        ),
        tile(
          Icons.bluetooth,
          'Nearby devices (Bluetooth)',
          'Show connected phone/audio device names',
          perms?.bluetooth,
          () async {
            try {
              if (await repo.requestPermission(AppPermission.bluetooth)) {
                ref
                  ..invalidate(permissionsProvider)
                  ..invalidate(bluetoothProvider);
              } else {
                await repo.openSettings(SettingsPage.appDetails);
              }
            } catch (_) {}
          },
          unavailable: noBluetooth,
        ),
      ],
    );
  }
}

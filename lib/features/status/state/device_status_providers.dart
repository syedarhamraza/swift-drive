import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_state.dart';
import '../../../core/logging/app_log.dart';
import '../data/device_status_repository.dart';

final deviceStatusRepositoryProvider = Provider<DeviceStatusRepository>(
  (ref) => ChannelDeviceStatusRepository(),
);

/// null until the first native event. Subscribed only in the foreground, like the other native streams.
final deviceStatusProvider =
    NotifierProvider<DeviceStatusController, DeviceStatus?>(
      DeviceStatusController.new,
    );

class DeviceStatusController extends Notifier<DeviceStatus?> {
  @override
  DeviceStatus? build() {
    if (!ref.watch(foregroundProvider) || !ref.stageReached(3)) {
      return stateOrNull;
    }
    final sub = ref
        .watch(deviceStatusRepositoryProvider)
        .statusChanges()
        .listen(
          (s) => state = s,
          onError: (Object e) => AppLog.w('status', 'stream failed: $e'),
        );
    ref.onDispose(sub.cancel);
    return stateOrNull;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_state.dart';
import '../../../core/logging/app_log.dart';
import '../data/bluetooth_repository.dart';

final bluetoothRepositoryProvider = Provider<BluetoothRepository>(
  (ref) => ChannelBluetoothRepository(),
);

/// null while unknown (before stage 3 or if the native call failed).
final bluetoothProvider =
    NotifierProvider<BluetoothController, BluetoothStatus?>(
      BluetoothController.new,
    );

class BluetoothController extends Notifier<BluetoothStatus?> {
  @override
  BluetoothStatus? build() {
    ref.watch(
      resumeTickProvider,
    ); // Permission may have been granted in Settings.
    if (!ref.watch(foregroundProvider) || !ref.stageReached(3)) {
      return stateOrNull;
    }
    final sub = ref
        .watch(bluetoothRepositoryProvider)
        .statusChanges()
        .listen(
          (s) => state = s,
          onError: (Object e) =>
              AppLog.w('bluetooth', 'status stream failed: $e'),
        );
    ref.onDispose(sub.cancel);
    return stateOrNull;
  }
}

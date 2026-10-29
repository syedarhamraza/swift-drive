import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_state.dart';
import '../data/device_repository.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => ChannelDeviceRepository(),
);

/// Non-sensitive capability report; refreshed on resume. Loaded at stage 5 or when a screen asks for it.
final deviceReportProvider = FutureProvider<DeviceReport>((ref) {
  ref.watch(resumeTickProvider);
  return ref.watch(deviceRepositoryProvider).getReport();
});

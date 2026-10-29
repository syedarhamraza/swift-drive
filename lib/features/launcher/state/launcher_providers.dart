import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_state.dart';
import '../data/launcher_repository.dart';

final launcherRepositoryProvider = Provider<LauncherRepository>(
  (ref) => ChannelLauncherRepository(),
);

/// Re-checked on every resume because the user may have changed the default launcher in Settings.
final homeStatusProvider = FutureProvider<HomeStatus>((ref) {
  ref.watch(resumeTickProvider);
  return ref.watch(launcherRepositoryProvider).getHomeStatus();
});

final permissionsProvider = FutureProvider<PermissionsState>((ref) {
  ref.watch(resumeTickProvider);
  return ref.watch(launcherRepositoryProvider).getPermissions();
});

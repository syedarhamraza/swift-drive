import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_state.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/platform/platform_failure.dart';
import '../../../core/storage/settings_providers.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => ChannelNotificationsRepository(),
);

class NotificationsState {
  const NotificationsState({this.access, this.items = const []});

  final bool? access;
  final List<NotificationItem> items;
}

final notificationsProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );

class NotificationsController extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    ref.watch(resumeTickProvider);
    if (!ref.watch(foregroundProvider) || !ref.stageReached(3)) {
      return stateOrNull ?? const NotificationsState();
    }
    final repo = ref.watch(notificationsRepositoryProvider);
    var disposed = false;
    ref.onDispose(() => disposed = true);
    repo.hasAccess().then(
      (access) {
        if (disposed) return;
        state = NotificationsState(
          access: access,
          items: access ? state.items : const [],
        );
        if (!access) return;
        final sub = repo.notifications().listen(
          (items) => state = NotificationsState(access: true, items: items),
          onError: (Object e) => AppLog.e('notifications', 'stream failed: $e'),
        );
        ref.onDispose(sub.cancel);
      },
      onError: (Object e) =>
          AppLog.w('notifications', 'access check failed: $e'),
    );
    // Contents are dropped whenever the launcher leaves the foreground (privacy).
    return NotificationsState(access: stateOrNull?.access);
  }

  Future<PlatformFailure?> dismiss(String key) async {
    try {
      await ref.read(notificationsRepositoryProvider).dismiss(key);
      return null;
    } on PlatformFailure catch (f) {
      return f;
    }
  }
}

final visibleNotificationsProvider = Provider<List<NotificationItem>>((ref) {
  final items = ref.watch(notificationsProvider.select((s) => s.items));
  final suppress = ref.watch(
    settingsProvider.select((s) => s.suppressNonEssential),
  );
  return suppress ? items.where(isEssentialNotification).toList() : items;
});

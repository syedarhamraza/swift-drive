import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_state.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/platform/platform_failure.dart';
import '../../../core/storage/settings_providers.dart';
import '../../location/data/location_repository.dart';
import '../data/media_repository.dart';
import '../domain/source_selection.dart';

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => ChannelMediaRepository(),
);

class MediaState {
  const MediaState({
    this.access,
    this.sessions = const [],
    this.selected,
    this.nativeNow = 0,
    this.receivedAt = Duration.zero,
  });

  /// null until the first snapshot arrives.
  final bool? access;
  final List<MediaSession> sessions;
  final MediaSession? selected;
  final int nativeNow;
  final Duration receivedAt;

  /// Android elapsedRealtime estimate for progress extrapolation, without asking the native side.
  int nativeNowEstimate() =>
      nativeNow + (monotonicNow() - receivedAt).inMilliseconds;
}

final mediaProvider = NotifierProvider<MediaController, MediaState>(
  MediaController.new,
);

class MediaController extends Notifier<MediaState> {
  String? _userSelectedId;
  final _art =
      <String, Uint8List>{}; // Insertion-ordered: oldest artwork evicted first.

  Uint8List? artFor(String? key) => key == null ? null : _art[key];

  @override
  MediaState build() {
    final previous = stateOrNull ?? const MediaState();
    ref.watch(
      resumeTickProvider,
    ); // Re-attach after notification access is granted.
    if (!ref.watch(foregroundProvider) || !ref.stageReached(3)) return previous;

    final sub = ref
        .watch(mediaRepositoryProvider)
        .snapshots()
        .listen(
          _onSnapshot,
          onError: (Object e) => AppLog.e('media', 'media stream failed: $e'),
        );
    ref.onDispose(sub.cancel);
    return previous;
  }

  void _onSnapshot(MediaSnapshot snap) {
    _art.addAll(snap.art);
    while (_art.length > 12) {
      _art.remove(_art.keys.first);
    }
    if (snap.sessions.length != state.sessions.length) {
      AppLog.i('media', '${snap.sessions.length} media session(s)');
    }
    final selected = selectMediaSession(
      snap.sessions,
      userSelectedId: _userSelectedId,
      currentId: state.selected?.id,
      preferredPackage: ref.read(settingsProvider).lastMediaPackage,
    );
    state = MediaState(
      access: snap.access,
      sessions: snap.sessions,
      selected: selected,
      nativeNow: snap.nativeNow,
      receivedAt: monotonicNow(),
    );
  }

  void select(MediaSession session) {
    _userSelectedId = session.id;
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(lastMediaPackage: session.packageName));
    state = MediaState(
      access: state.access,
      sessions: state.sessions,
      selected: session,
      nativeNow: state.nativeNow,
      receivedAt: state.receivedAt,
    );
  }

  Future<PlatformFailure?> command(
    MediaAction action, {
    int? positionMs,
  }) async {
    final session = state.selected;
    if (session == null) {
      return const PlatformFailure(FailureKind.serviceUnavailable);
    }
    try {
      await ref
          .read(mediaRepositoryProvider)
          .command(session.id, action, positionMs: positionMs);
      return null;
    } on PlatformFailure catch (f) {
      return f;
    }
  }
}

import 'package:flutter/services.dart';

import '../../../core/platform/platform_failure.dart';

/// Subset of android.media.session.PlaybackState constants and action bits.
abstract final class PlaybackStates {
  static const none = 0;
  static const stopped = 1;
  static const paused = 2;
  static const playing = 3;
  static const buffering = 6;
  static const error = 7;

  static const actionPause = 1 << 1;
  static const actionPlay = 1 << 2;
  static const actionSkipToPrevious = 1 << 4;
  static const actionSkipToNext = 1 << 5;
  static const actionSeekTo = 1 << 8;
  static const actionPlayPause = 1 << 9;
}

class MediaSession {
  const MediaSession({
    required this.id,
    required this.packageName,
    required this.appLabel,
    required this.state,
    required this.position,
    required this.updateTime,
    required this.speed,
    required this.actions,
    this.title,
    this.artist,
    this.album,
    this.duration = 0,
    this.artKey,
  });

  factory MediaSession.fromMap(Map<Object?, Object?> m) => MediaSession(
    id: m['id']! as String,
    packageName: m['packageName']! as String,
    appLabel: m['appLabel'] as String? ?? m['packageName']! as String,
    state: m['state'] as int? ?? PlaybackStates.none,
    position: (m['position'] as num? ?? 0).toInt(),
    updateTime: (m['updateTime'] as num? ?? 0).toInt(),
    speed: (m['speed'] as num? ?? 0).toDouble(),
    actions: (m['actions'] as num? ?? 0).toInt(),
    title: m['title'] as String?,
    artist: m['artist'] as String?,
    album: m['album'] as String?,
    duration: (m['duration'] as num? ?? 0).toInt(),
    artKey: m['artKey'] as String?,
  );

  final String id;
  final String packageName;
  final String appLabel;
  final int state;

  /// Position in ms at [updateTime] (Android elapsedRealtime, ms).
  final int position;
  final int updateTime;
  final double speed;
  final int actions;
  final String? title;
  final String? artist;
  final String? album;
  final int duration;
  final String? artKey;

  bool get isPlaying => state == PlaybackStates.playing;
  bool get isBuffering => state == PlaybackStates.buffering;
  bool get hasMetadata => (title ?? '').isNotEmpty;

  // Many apps leave the action bitmask at 0; then the transport is assumed to accept basic commands.
  bool supports(int action) => actions == 0 || actions & action != 0;
  bool get canSeek =>
      actions & PlaybackStates.actionSeekTo != 0 && duration > 0;

  /// Extrapolated position for an Android elapsedRealtime [nativeNow], clamped to the track length.
  int positionAt(int nativeNow) {
    var p = position;
    if (isPlaying && updateTime > 0) {
      p += ((nativeNow - updateTime) * speed).round();
    }
    if (p < 0) return 0;
    return duration > 0 && p > duration ? duration : p;
  }
}

class MediaSnapshot {
  const MediaSnapshot({
    required this.access,
    required this.sessions,
    required this.nativeNow,
    required this.art,
  });

  final bool access;
  final List<MediaSession> sessions;
  final int nativeNow;

  /// Newly transmitted artwork by art key; already-sent artwork is omitted by the native side.
  final Map<String, Uint8List> art;
}

enum MediaAction { play, pause, next, previous, seekTo }

abstract interface class MediaRepository {
  Stream<MediaSnapshot> snapshots();
  Future<bool> hasAccess();
  Future<void> refresh();
  Future<void> command(String sessionId, MediaAction action, {int? positionMs});
}

class ChannelMediaRepository implements MediaRepository {
  static const _channel = MethodChannel('swiftdrive/media');
  static const _events = EventChannel('swiftdrive/media/events');

  @override
  Stream<MediaSnapshot> snapshots() =>
      _events.receiveBroadcastStream().map((e) {
        final m = e as Map<Object?, Object?>;
        final raw = (m['sessions'] as List? ?? const [])
            .cast<Map<Object?, Object?>>();
        return MediaSnapshot(
          access: m['access'] as bool? ?? false,
          nativeNow: (m['now'] as num? ?? 0).toInt(),
          sessions: raw.map(MediaSession.fromMap).toList(),
          art: {
            for (final s in raw)
              if (s['art'] is Uint8List && s['artKey'] is String)
                s['artKey']! as String: s['art']! as Uint8List,
          },
        );
      });

  @override
  Future<bool> hasAccess() => guardPlatform(
    'media',
    () async => await _channel.invokeMethod<bool>('hasAccess') ?? false,
  );

  @override
  Future<void> refresh() =>
      guardPlatform('media', () => _channel.invokeMethod('refresh'));

  @override
  Future<void> command(
    String sessionId,
    MediaAction action, {
    int? positionMs,
  }) => guardPlatform(
    'media',
    () => _channel.invokeMethod('command', {
      'id': sessionId,
      'action': action.name,
      'position': positionMs,
    }),
  );
}

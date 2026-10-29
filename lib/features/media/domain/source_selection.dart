import '../data/media_repository.dart';

/// Picks the session the media widget shows.
///
/// 1. An explicit user choice wins while that session exists.
/// 2. The currently shown session is kept unless it stopped playing and another one is playing
///    (the driver started that playback, so following it is expected rather than surprising).
/// 3. Otherwise: playing > buffering > has metadata, with the remembered app breaking ties.
MediaSession? selectMediaSession(
  List<MediaSession> sessions, {
  String? userSelectedId,
  String? currentId,
  String? preferredPackage,
}) {
  if (sessions.isEmpty) return null;
  MediaSession? byId(String? id) =>
      id == null ? null : sessions.where((s) => s.id == id).firstOrNull;

  final chosen = byId(userSelectedId);
  if (chosen != null) return chosen;

  final current = byId(currentId);
  final anyPlaying = sessions.any((s) => s.isPlaying);
  if (current != null && (current.isPlaying || !anyPlaying)) return current;

  int rank(MediaSession s) {
    final activity = s.isPlaying
        ? 3
        : (s.isBuffering ? 2 : (s.hasMetadata ? 1 : 0));
    return activity * 2 + (s.packageName == preferredPackage ? 1 : 0);
  }

  var best = sessions.first;
  for (final s in sessions.skip(1)) {
    if (rank(s) > rank(best)) best = s;
  }
  return best;
}

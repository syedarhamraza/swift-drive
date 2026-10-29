import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/storage/settings_providers.dart';
import '../domain/route_geometry.dart';

final voiceGuidanceProvider = Provider<VoiceGuidance>((ref) {
  final voice = VoiceGuidance(() => ref.read(settingsProvider).voiceMuted);
  ref.onDispose(voice.dispose);
  return voice;
});

/// Spoken prompts from real route maneuvers only. Speech requests transient, duckable audio focus and
/// releases it when done, so other audio is lowered briefly rather than paused.
class VoiceGuidance {
  VoiceGuidance(this._muted);

  static const thresholds = [500.0, 100.0];

  final bool Function() _muted;
  FlutterTts? _tts;
  final _spoken = <(int, double)>{};

  Future<FlutterTts> _engine() async {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = FlutterTts();
    await tts.setAudioAttributesForNavigation();
    // flutter_tts does not release focus on error; stopping does.
    tts.setErrorHandler((msg) {
      AppLog.w('voice', 'tts error: $msg');
      tts.stop();
    });
    return _tts = tts;
  }

  Future<void> say(String text) async {
    if (_muted()) return;
    try {
      await (await _engine()).speak(text, focus: true);
    } catch (e) {
      AppLog.w('voice', 'speech unavailable: ${e.runtimeType}');
    }
  }

  /// Announces the next maneuver once when crossing each distance threshold.
  void onProgress(RouteProgress p) {
    final idx = p.nextStepIndex;
    final d = p.metersToNextStep;
    final step = p.nextStep;
    if (idx == null || d == null || step == null) return;
    // The smallest threshold already crossed; larger ones are skipped so a late start says only the turn.
    final crossed = thresholds
        .where((t) => d <= t)
        .fold<double?>(null, (min, t) => min == null || t < min ? t : min);
    if (crossed == null || !_spoken.add((idx, crossed))) return;
    for (final t in thresholds.where((t) => t > crossed)) {
      _spoken.add((idx, t));
    }
    say(
      crossed >= 500
          ? 'In ${crossed.round()} metres, ${step.instruction}'
          : step.instruction,
    );
  }

  void reset() => _spoken.clear();

  void dispose() => _tts?.stop();
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../apps/data/apps_repository.dart';
import '../../media/data/media_repository.dart';
import '../../media/state/media_providers.dart';

/// What the radio widget may show. [frequency] stays null unless a verified adapter supplies it:
/// the generic adapter never parses or guesses a frequency.
class RadioInfo {
  const RadioInfo({required this.session, this.frequency});

  final MediaSession session;
  final String? frequency;

  String? get stationName => session.title;
}

/// Integration order (spec §12): standard MediaSession of the configured radio app → (future) verified
/// vendor adapters → fallback: launch the stock radio app.
final radioInfoProvider = Provider<RadioInfo?>((ref) {
  final radioId = ref.watch(
    settingsProvider.select((s) => s.shortcuts[FactoryRole.radio]),
  );
  if (radioId == null) return null;
  final (pkg, _) = parseAppId(radioId);
  final sessions = ref.watch(mediaProvider.select((m) => m.sessions));
  final session = sessions.where((s) => s.packageName == pkg).firstOrNull;
  return session == null ? null : RadioInfo(session: session);
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../apps/state/apps_providers.dart';
import '../../apps/ui/app_picker.dart';
import '../../media/data/media_repository.dart';
import '../../media/state/media_providers.dart';
import '../domain/radio_adapter.dart';

/// Shows radio metadata only if the configured radio app publishes a standard media session.
/// Otherwise it is an honest "Open Radio" shortcut; it never claims to know the frequency.
class RadioCard extends ConsumerWidget {
  const RadioCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(radioInfoProvider);
    final configured = ref.watch(
      settingsProvider.select(
        (s) => s.shortcuts.containsKey(FactoryRole.radio),
      ),
    );
    final appName = configured
        ? ref.read(appLauncherProvider).shortcutApp(FactoryRole.radio)?.label
        : null;
    final t = Theme.of(context).textTheme;

    return SdCard(
      onTap: () => launchRole(context, ref, FactoryRole.radio),
      child: Row(
        children: [
          const Icon(Icons.radio, size: 36),
          const SizedBox(width: SdSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info?.stationName ?? 'Radio',
                  style: t.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  info != null
                      ? (info.session.isPlaying
                            ? 'Playing · ${info.session.appLabel}'
                            : 'Paused · ${info.session.appLabel}')
                      : (appName == null
                            ? 'Tap to choose your radio app'
                            : 'Open $appName'),
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          if (info != null)
            IconButton(
              iconSize: 36,
              tooltip: info.session.isPlaying ? 'Pause' : 'Play',
              icon: Icon(
                info.session.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              onPressed: () async {
                final media = ref.read(mediaProvider.notifier)
                  ..select(info.session);
                final failure = await media.command(
                  info.session.isPlaying ? MediaAction.pause : MediaAction.play,
                );
                if (context.mounted) showFailure(context, failure);
              },
            ),
        ],
      ),
    );
  }
}

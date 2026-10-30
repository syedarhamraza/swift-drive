import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../apps/state/apps_providers.dart';
import '../../apps/ui/app_picker.dart';
import '../../launcher/data/launcher_repository.dart';
import '../../launcher/state/launcher_providers.dart';
import '../data/media_repository.dart';
import '../state/media_providers.dart';

class MediaCard extends ConsumerWidget {
  const MediaCard({super.key, this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(mediaProvider.select((m) => m.access));
    final session = ref.watch(mediaProvider.select((m) => m.selected));
    final count = ref.watch(mediaProvider.select((m) => m.sessions.length));

    final Widget body;
    if (access == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!access) {
      body = StatusMessage(
        icon: Icons.music_off_outlined,
        title: 'Media controls need notification access',
        body: 'Android only shares now-playing info with apps that have it.',
        actionLabel: 'Enable access',
        onAction: () => ref
            .read(launcherRepositoryProvider)
            .openSettings(SettingsPage.notificationAccess),
        dense: !large,
      );
    } else if (session == null) {
      final music = ref
          .read(appLauncherProvider)
          .shortcutApp(FactoryRole.music);
      body = StatusMessage(
        icon: Icons.music_note_outlined,
        title: 'Nothing playing',
        actionLabel: music == null ? 'Choose music app' : 'Open ${music.label}',
        onAction: () => launchRole(context, ref, FactoryRole.music),
        dense: !large,
      );
    } else {
      body = _NowPlaying(
        session: session,
        large: large,
        multipleSources: count > 1,
      );
    }
    return SdCard(child: body);
  }
}

class _NowPlaying extends ConsumerWidget {
  const _NowPlaying({
    required this.session,
    required this.large,
    required this.multipleSources,
  });

  final MediaSession session;
  final bool large;
  final bool multipleSources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final showArt = ref.watch(settingsProvider.select((s) => s.showArtwork));
    final controller = ref.read(mediaProvider.notifier);
    final art = showArt ? controller.artFor(session.artKey) : null;
    final artSize = large ? 128.0 : 72.0;

    Future<void> run(MediaAction a) async {
      final failure = await controller.command(a);
      if (context.mounted) showFailure(context, failure);
    }

    final controls = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: 36,
          tooltip: 'Previous',
          onPressed: session.supports(PlaybackStates.actionSkipToPrevious)
              ? () => run(MediaAction.previous)
              : null,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        IconButton.filled(
          iconSize: 44,
          style: IconButton.styleFrom(
            minimumSize: const Size(SdSize.driveTarget, SdSize.driveTarget),
          ),
          tooltip: session.isPlaying ? 'Pause' : 'Play',
          onPressed: () =>
              run(session.isPlaying ? MediaAction.pause : MediaAction.play),
          icon: Icon(
            session.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
        ),
        IconButton(
          iconSize: 36,
          tooltip: 'Next',
          onPressed: session.supports(PlaybackStates.actionSkipToNext)
              ? () => run(MediaAction.next)
              : null,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (art != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  art,
                  width: artSize,
                  height: artSize,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth: (artSize * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                ),
              )
            else
              Container(
                width: artSize,
                height: artSize,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.music_note, size: 32),
              ),
            const SizedBox(width: SdSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title ?? 'Unknown title',
                    style: t.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (session.artist != null)
                    Text(
                      session.artist!,
                      style: t.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    session.appLabel,
                    style: t.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (multipleSources)
              IconButton(
                tooltip: 'Choose source',
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => _chooseSource(context, ref),
              ),
          ],
        ),
        if (session.duration > 0) ...[
          const SizedBox(height: SdSpace.sm),
          _Progress(session: session),
        ],
        const SizedBox(height: SdSpace.xs),
        controls,
      ],
    );
  }

  void _chooseSource(BuildContext context, WidgetRef ref) {
    final sessions = ref.read(mediaProvider).sessions;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Media source')),
            for (final s in sessions)
              ListTile(
                leading: Icon(
                  s.isPlaying ? Icons.equalizer : Icons.music_note_outlined,
                ),
                title: Text(s.appLabel),
                subtitle: Text(
                  s.title ?? 'No track info',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: s.id == session.id ? const Icon(Icons.check) : null,
                onTap: () {
                  ref.read(mediaProvider.notifier).select(s);
                  Navigator.pop(sheet);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Progress extrapolated locally from the last reported position. Ticks once a second, only while
/// playing and visible (TickerMode is off when a route covers the dashboard) and not in performance mode,
/// where it moves only when the player reports a new position.
class _Progress extends ConsumerStatefulWidget {
  const _Progress({required this.session});

  final MediaSession session;

  @override
  ConsumerState<_Progress> createState() => _ProgressState();
}

class _ProgressState extends ConsumerState<_Progress> {
  Timer? _timer;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          widget.session.isPlaying &&
          TickerMode.valuesOf(context).enabled &&
          !ref.read(settingsProvider).performanceMode &&
          _dragValue == null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final pos = s.positionAt(ref.read(mediaProvider).nativeNowEstimate());
    final value = _dragValue ?? (s.duration == 0 ? 0.0 : pos / s.duration);
    final t = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        Text(_fmt(pos), style: t),
        Expanded(
          child: s.canSeek
              ? Slider(
                  value: value.clamp(0.0, 1.0),
                  onChanged: (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) async {
                    final f = await ref
                        .read(mediaProvider.notifier)
                        .command(
                          MediaAction.seekTo,
                          positionMs: (v * s.duration).round(),
                        );
                    if (mounted) setState(() => _dragValue = null);
                    if (context.mounted) showFailure(context, f);
                  },
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SdSpace.md),
                  child: LinearProgressIndicator(value: value.clamp(0.0, 1.0)),
                ),
        ),
        Text(_fmt(s.duration), style: t),
      ],
    );
  }
}

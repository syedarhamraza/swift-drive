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
  const MediaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(mediaProvider.select((m) => m.access));
    final session = ref.watch(mediaProvider.select((m) => m.selected));
    final count = ref.watch(mediaProvider.select((m) => m.sessions.length));

    final Widget body;
    if (access == null) {
      body = const SdCard(
        key: ValueKey('loading'),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (!access) {
      body = SdCard(
        key: const ValueKey('no-access'),
        child: Center(
          child: StatusMessage(
            icon: Icons.music_off_outlined,
            title: 'Media controls need notification access',
            body:
                'Android only shares now-playing info with apps that have it.',
            actionLabel: 'Enable access',
            onAction: () => ref
                .read(launcherRepositoryProvider)
                .openSettings(SettingsPage.notificationAccess),
            dense: true,
          ),
        ),
      );
    } else if (session == null) {
      final music = ref
          .read(appLauncherProvider)
          .shortcutApp(FactoryRole.music);
      final scheme = Theme.of(context).colorScheme;
      body = SdCard(
        key: const ValueKey('idle'),
        color: Color.alphaBlend(
          scheme.tertiaryContainer.withValues(alpha: 0.45),
          scheme.surface,
        ),
        child: Center(
          child: StatusMessage(
            icon: Icons.music_note_outlined,
            title: 'Nothing playing',
            actionLabel: music == null
                ? 'Choose music app'
                : 'Open ${music.label}',
            onAction: () => launchRole(context, ref, FactoryRole.music),
            dense: true,
          ),
        ),
      );
    } else {
      body = _NowPlaying(
        key: const ValueKey('playing'),
        session: session,
        multipleSources: count > 1,
      );
    }
    return AnimatedSwitcher(
      duration: SdMotion.of(context, SdMotion.medium),
      switchInCurve: SdMotion.curve,
      switchOutCurve: SdMotion.exitCurve,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.passthrough, children: [...previous, ?current]),
      child: body,
    );
  }
}

/// Artwork fills the card under a fixed dark scrim, so the white text and controls read on any cover.
class _NowPlaying extends ConsumerWidget {
  const _NowPlaying({
    super.key,
    required this.session,
    required this.multipleSources,
  });

  final MediaSession session;
  final bool multipleSources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showArt = ref.watch(settingsProvider.select((s) => s.showArtwork));
    final controller = ref.read(mediaProvider.notifier);
    final art = showArt ? controller.artFor(session.artKey) : null;
    final apps = ref.watch(installedAppsProvider).value ?? const [];
    final appIcon = apps
        .where((a) => a.packageName == session.packageName)
        .firstOrNull
        ?.icon;
    final slow = SdMotion.of(context, SdMotion.long);
    final fast = SdMotion.of(context, SdMotion.short);

    Future<void> run(MediaAction a) async {
      final failure = await controller.command(a);
      if (context.mounted) showFailure(context, failure);
    }

    // Content always sits on a dark scrim: force light foreground colours whatever the app theme is.
    final onArt = onDarkBackdrop(theme).copyWith(
      sliderTheme: theme.sliderTheme.copyWith(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Colors.white,
        linearTrackColor: Colors.white24,
      ),
    );

    final background = art != null
        ? Image.memory(
            art,
            key: ValueKey(session.artKey),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: 256,
          )
        : DecoratedBox(
            key: const ValueKey('no-art'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.tertiary],
              ),
            ),
          );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: slow,
            layoutBuilder: (current, previous) =>
                Stack(fit: StackFit.expand, children: [...previous, ?current]),
            child: background,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x55000000), Color(0xDD000000)],
              ),
            ),
          ),
          Theme(
            data: onArt,
            child: LayoutBuilder(
              builder: (context, box) {
                final roomy = box.maxHeight >= 240;
                final t = onArt.textTheme;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SdSpace.lg,
                    SdSpace.md,
                    SdSpace.sm,
                    SdSpace.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (roomy)
                        Row(
                          children: [
                            if (appIcon != null) ...[
                              AppIconImage(appIcon, size: 22),
                              const SizedBox(width: SdSpace.sm),
                            ],
                            Expanded(
                              child: Text(
                                session.appLabel,
                                style: t.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: slow,
                        switchInCurve: SdMotion.curve,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.15),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.bottomLeft,
                          children: [...previous, ?current],
                        ),
                        child: Column(
                          key: ValueKey((session.title, session.artist)),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Some players publish a session without track info: name the app instead
                            // of showing a placeholder.
                            Text(
                              session.title ?? session.appLabel,
                              style: t.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              session.title == null
                                  ? (session.isPlaying ? 'Playing' : 'Paused')
                                  : session.artist ?? session.appLabel,
                              style: t.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (roomy && session.duration > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: SdSpace.sm),
                          child: _Progress(session: session),
                        )
                      else
                        const SizedBox(height: SdSpace.sm),
                      // Three equal pills, so each control is as easy to hit as the others.
                      Row(
                        children: [
                          _Control(
                            tooltip: 'Previous',
                            onPressed:
                                session.supports(
                                  PlaybackStates.actionSkipToPrevious,
                                )
                                ? () => run(MediaAction.previous)
                                : null,
                            child: const Icon(Icons.skip_previous_rounded),
                          ),
                          const SizedBox(width: SdSpace.sm),
                          _Control(
                            tooltip: session.isPlaying ? 'Pause' : 'Play',
                            onPressed: () => run(
                              session.isPlaying
                                  ? MediaAction.pause
                                  : MediaAction.play,
                            ),
                            child: AnimatedSwitcher(
                              duration: fast,
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Icon(
                                session.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                key: ValueKey(session.isPlaying),
                              ),
                            ),
                          ),
                          const SizedBox(width: SdSpace.sm),
                          _Control(
                            tooltip: 'Next',
                            onPressed:
                                session.supports(
                                  PlaybackStates.actionSkipToNext,
                                )
                                ? () => run(MediaAction.next)
                                : null,
                            child: const Icon(Icons.skip_next_rounded),
                          ),
                          const SizedBox(width: SdSpace.sm),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
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

class _Control extends StatelessWidget {
  const _Control({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Tooltip(
      message: tooltip,
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, SdSize.driveTarget),
          padding: EdgeInsets.zero,
          iconSize: 32,
        ),
        onPressed: onPressed,
        child: child,
      ),
    ),
  );
}

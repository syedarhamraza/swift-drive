import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../apps/state/apps_providers.dart';
import '../../launcher/data/launcher_repository.dart';
import '../../launcher/state/launcher_providers.dart';
import '../../navigation/state/voice_guidance.dart';
import '../data/notifications_repository.dart';
import '../state/notifications_providers.dart';

/// The newest notification with quick actions; the rest are one tap away in the full sheet.
class NotificationsCard extends ConsumerWidget {
  const NotificationsCard({super.key, this.expand = false});

  /// Fill the given height (a pager page): the message at the top, the actions at the bottom.
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(notificationsProvider.select((s) => s.access));
    final items = ref.watch(visibleNotificationsProvider);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget fill(Widget row) => expand ? Center(child: row) : row;
    final Widget child;
    if (access == false) {
      child = SdCard(
        key: const ValueKey('no-access'),
        child: fill(
          Row(
            children: [
              const Icon(Icons.notifications_off_outlined),
              const SizedBox(width: SdSpace.md),
              Expanded(
                child: Text('Notifications need access', style: t.bodyMedium),
              ),
              TextButton(
                onPressed: () => ref
                    .read(launcherRepositoryProvider)
                    .openSettings(SettingsPage.notificationAccess),
                child: const Text('Enable'),
              ),
            ],
          ),
        ),
      );
    } else if (items.isEmpty) {
      child = SdCard(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.symmetric(
          horizontal: SdSpace.lg,
          vertical: SdSpace.md,
        ),
        child: fill(
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.secondaryContainer,
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: SdSpace.md),
              Flexible(
                child: Text(
                  'No new notifications',
                  style: t.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      child = _Latest(
        key: ValueKey(items.first.key),
        item: items.first,
        count: items.length,
        expand: expand,
      );
    }
    // A new notification slides in from the top. In a column the card grows or shrinks smoothly with
    // its content; on a pager page it fills the page.
    final switcher = AnimatedSwitcher(
      duration: SdMotion.of(context, SdMotion.medium),
      switchInCurve: SdMotion.curve,
      switchOutCurve: SdMotion.exitCurve,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        fit: expand ? StackFit.expand : StackFit.loose,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.15),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
    return expand
        ? switcher
        : AnimatedSize(
            duration: SdMotion.of(context, SdMotion.medium),
            curve: SdMotion.curve,
            alignment: Alignment.topCenter,
            child: switcher,
          );
  }
}

class _Latest extends ConsumerWidget {
  const _Latest({
    super.key,
    required this.item,
    required this.count,
    required this.expand,
  });

  final NotificationItem item;
  final int count;
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final apps = ref.watch(installedAppsProvider).value ?? const [];
    final app = apps
        .where((a) => a.packageName == item.packageName)
        .firstOrNull;

    Future<void> readAloud() async {
      if (ref.read(settingsProvider).voiceMuted) {
        showMessage(context, 'Voice is muted');
        return;
      }
      // Spoken only on request and never stored.
      await ref
          .read(voiceGuidanceProvider)
          .say([item.appLabel, ?item.title, ?item.body].join('. '));
    }

    // Lighter than the theme's tonal grey so it stands out on the card.
    final secondStyle = FilledButton.styleFrom(
      backgroundColor: scheme.onSurface.withValues(alpha: 0.16),
      foregroundColor: scheme.onSurface,
    );
    final Widget? second = item.clearable
        ? FilledButton.tonalIcon(
            style: secondStyle,
            onPressed: () async {
              final failure = await ref
                  .read(notificationsProvider.notifier)
                  .dismiss(item.key);
              if (context.mounted) showFailure(context, failure);
            },
            icon: const Icon(Icons.close),
            label: const Text('Dismiss'),
          )
        : app == null
        ? null
        : FilledButton.tonalIcon(
            style: secondStyle,
            onPressed: () async {
              final failure = await ref
                  .read(appLauncherProvider)
                  .launch(app.id);
              if (context.mounted) {
                showFailure(context, failure, what: app.label);
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
          );

    final muted = t.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return LayoutBuilder(
      builder: (context, box) {
        // Short pager pages (a phone in landscape) drop the source line and keep the text to one line.
        final compact = box.maxHeight < 230;
        return SdCard(
          onTap: () => showNotificationsSheet(context),
          padding: compact
              ? const EdgeInsets.fromLTRB(
                  SdSpace.lg,
                  SdSpace.md,
                  SdSpace.lg,
                  SdSpace.md,
                )
              : const EdgeInsets.all(SdSpace.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                scheme.tertiary.withValues(alpha: 0.18),
                scheme.surface,
              ),
              scheme.surface,
            ],
          ),
          child: Column(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIconImage(app?.icon, size: compact ? 28 : 24),
                  const SizedBox(width: SdSpace.sm),
                  Expanded(
                    child: Text(
                      compact
                          ? item.title ?? item.appLabel
                          : '${item.appLabel} · ${formatAge(item.postTime, DateTime.now())}',
                      style: compact ? t.titleMedium : muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (compact) ...[
                    const SizedBox(width: SdSpace.sm),
                    Text(
                      formatAge(item.postTime, DateTime.now()),
                      style: muted,
                    ),
                    const SizedBox(width: SdSpace.sm),
                  ],
                  if (count > 1)
                    Tooltip(
                      message: '$count notifications',
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 28),
                        padding: const EdgeInsets.symmetric(
                          horizontal: SdSpace.sm,
                          vertical: 2,
                        ),
                        decoration: ShapeDecoration(
                          shape: const StadiumBorder(),
                          color: scheme.primaryContainer,
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: t.labelLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: SdSpace.sm),
                Text(
                  item.title ?? item.appLabel,
                  style: t.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (item.body != null)
                Text(
                  item.body!,
                  style: (compact ? t.bodyMedium : t.bodyLarge)?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  // A page has room for a second line; a short card in a column does not.
                  maxLines: compact && !expand ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (expand)
                const Spacer()
              else
                SizedBox(height: compact ? SdSpace.sm : SdSpace.md),
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: 'Read aloud',
                      child: FilledButton.icon(
                        onPressed: readAloud,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Read'),
                      ),
                    ),
                  ),
                  if (second != null) ...[
                    const SizedBox(width: SdSpace.sm),
                    Expanded(child: second),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

void showNotificationsSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.8,
    child: Consumer(
      builder: (context, ref, _) {
        final items = ref.watch(visibleNotificationsProvider);
        if (items.isEmpty) {
          return const Center(
            child: StatusMessage(
              icon: Icons.notifications_none,
              title: 'No notifications',
            ),
          );
        }
        return ListView(
          children: [for (final n in items) NotificationTile(item: n)],
        );
      },
    ),
  ),
);

class NotificationTile extends ConsumerWidget {
  const NotificationTile({super.key, required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(installedAppsProvider).value ?? const [];
    final icon = apps
        .where((a) => a.packageName == item.packageName)
        .firstOrNull
        ?.icon;
    return ListTile(
      leading: AppIconImage(icon, size: 36),
      title: Text(
        item.title ?? item.appLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          item.appLabel,
          formatAge(item.postTime, DateTime.now()),
          ?item.body,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: item.clearable
          ? IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close),
              onPressed: () async {
                final failure = await ref
                    .read(notificationsProvider.notifier)
                    .dismiss(item.key);
                if (context.mounted) showFailure(context, failure);
              },
            )
          : null,
    );
  }
}

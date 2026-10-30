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
  const NotificationsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(notificationsProvider.select((s) => s.access));
    final items = ref.watch(visibleNotificationsProvider);
    final t = Theme.of(context).textTheme;

    final Widget child;
    if (access == false) {
      child = SdCard(
        key: const ValueKey('no-access'),
        child: Row(
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
      );
    } else if (items.isEmpty) {
      child = SdCard(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.symmetric(
          horizontal: SdSpace.lg,
          vertical: SdSpace.md,
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_none),
            const SizedBox(width: SdSpace.md),
            Flexible(
              child: Text(
                'No notifications',
                style: t.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      child = _Latest(
        key: ValueKey(items.first.key),
        item: items.first,
        count: items.length,
      );
    }
    // A new notification slides in from the top; the card grows or shrinks smoothly with its content.
    return AnimatedSize(
      duration: SdMotion.of(context, SdMotion.medium),
      curve: SdMotion.curve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: SdMotion.of(context, SdMotion.medium),
        switchInCurve: SdMotion.curve,
        switchOutCurve: SdMotion.exitCurve,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
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
      ),
    );
  }
}

class _Latest extends ConsumerWidget {
  const _Latest({super.key, required this.item, required this.count});

  final NotificationItem item;
  final int count;

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
          .say([item.appLabel, ?item.title, ?item.text].join('. '));
    }

    final Widget? second = item.clearable
        ? FilledButton.tonalIcon(
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

    return SdCard(
      onTap: () => showNotificationsSheet(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipOval(child: AppIconImage(app?.icon, size: 44)),
              const SizedBox(width: SdSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title ?? item.appLabel,
                      style: t.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.text ??
                          '${item.appLabel} · ${formatAge(item.postTime, DateTime.now())}',
                      style: t.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
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
          const SizedBox(height: SdSpace.md),
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
          ?item.text,
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

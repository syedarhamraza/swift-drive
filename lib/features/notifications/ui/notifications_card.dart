import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../apps/state/apps_providers.dart';
import '../../launcher/data/launcher_repository.dart';
import '../../launcher/state/launcher_providers.dart';
import '../data/notifications_repository.dart';
import '../state/notifications_providers.dart';

/// Compact, non-animated list. Shows at most [maxItems]; the rest are behind "Show all".
class NotificationsCard extends ConsumerWidget {
  const NotificationsCard({super.key, this.maxItems = 2});

  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(notificationsProvider.select((s) => s.access));
    final items = ref.watch(visibleNotificationsProvider);
    final t = Theme.of(context).textTheme;

    if (access == false) {
      return SdCard(
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
    }
    if (items.isEmpty) {
      return SdCard(
        child: Row(
          children: [
            const Icon(Icons.notifications_none),
            const SizedBox(width: SdSpace.md),
            Text('No notifications', style: t.bodyMedium),
          ],
        ),
      );
    }
    return SdCard(
      padding: const EdgeInsets.symmetric(vertical: SdSpace.xs),
      onTap: () => showNotificationsSheet(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in items.take(maxItems)) NotificationTile(item: n),
          if (items.length > maxItems)
            Padding(
              padding: const EdgeInsets.only(bottom: SdSpace.sm),
              child: Text(
                '+${items.length - maxItems} more — tap to show all',
                style: t.bodySmall,
              ),
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

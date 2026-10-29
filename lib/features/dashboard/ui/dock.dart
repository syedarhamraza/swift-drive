import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../apps/data/apps_repository.dart';
import '../../apps/state/apps_providers.dart';
import '../../apps/ui/app_drawer_screen.dart';
import '../../apps/ui/app_picker.dart';
import '../../bluetooth/domain/calling_adapter.dart';
import '../../navigation/ui/destination_sheet.dart';
import '../../settings/ui/settings_screen.dart';

/// Parsed dock entry: `builtin:<id>` or `app:<package>/<activity>`.
sealed class DockEntry {
  const DockEntry();

  static DockEntry? parse(String raw) {
    if (raw.startsWith('builtin:')) {
      final id = raw.substring(8);
      return builtinDockIds.contains(id) ? BuiltinEntry(id) : null;
    }
    if (raw.startsWith('app:')) return AppEntry(raw.substring(4));
    return null;
  }
}

class BuiltinEntry extends DockEntry {
  const BuiltinEntry(this.id);

  final String id;
}

class AppEntry extends DockEntry {
  const AppEntry(this.appId);

  final String appId;
}

(String, IconData) builtinInfo(String id) => switch (id) {
  'home' => ('Home', Icons.home_rounded),
  'maps' => ('Maps', Icons.map_outlined),
  'music' => ('Music', Icons.music_note_outlined),
  'phone' => ('Phone', Icons.phone_outlined),
  'radio' => ('Radio', Icons.radio_outlined),
  'apps' => ('Apps', Icons.apps_rounded),
  'settings' => ('Settings', Icons.settings_outlined),
  _ => (id, Icons.help_outline),
};

class Dock extends ConsumerWidget {
  const Dock({super.key, required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref
        .watch(settingsProvider.select((s) => s.dock))
        .map(DockEntry.parse)
        .nonNulls
        .toList();
    final hasSettings = entries.any(
      (e) => e is BuiltinEntry && e.id == 'settings',
    );
    final children = [
      for (final e in entries) _DockButton(entry: e),
      // Settings must always be reachable, even if the user removed it from the dock.
      if (!hasSettings) const _DockButton(entry: BuiltinEntry('settings')),
    ];
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        right: !vertical,
        top: vertical,
        child: SizedBox(
          width: vertical ? 88 : null,
          height: vertical ? null : 80,
          child: ListView(
            scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
            padding: const EdgeInsets.all(SdSpace.sm),
            children: children,
          ),
        ),
      ),
    );
  }
}

class _DockButton extends ConsumerWidget {
  const _DockButton({required this.entry});

  final DockEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget icon;
    final String label;
    VoidCallback onTap;
    switch (entry) {
      case BuiltinEntry(:final id):
        final (l, i) = builtinInfo(id);
        label = l;
        icon = Icon(i, size: 30);
        onTap = () => _builtinAction(context, ref, id);
      case AppEntry(:final appId):
        final apps = ref.watch(installedAppsProvider).value;
        final app = apps == null ? null : findApp(apps, appId);
        final missing = apps != null && app == null;
        label = app?.label ?? (missing ? 'Missing app' : '…');
        icon = missing
            ? const Icon(
                Icons.warning_amber_rounded,
                size: 30,
                color: SdColors.warning,
              )
            : AppIconImage(app?.icon, size: 36);
        onTap = missing
            ? () => _replaceMissing(context, ref, appId)
            : () async {
                if (app == null) return;
                final failure = await ref
                    .read(appLauncherProvider)
                    .launch(app.id);
                if (context.mounted) {
                  showFailure(context, failure, what: app.label);
                }
              };
    }
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(SdRadius.button),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _builtinAction(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final nav = Navigator.of(context);
    switch (id) {
      case 'home':
        nav.popUntil((r) => r.isFirst);
      case 'maps':
        if (ref.read(settingsProvider).mapEnabled) {
          await showDestinationSheet(context, mapAvailable: true);
        } else {
          await launchRole(context, ref, FactoryRole.navigation);
        }
      case 'music':
        await launchRole(context, ref, FactoryRole.music);
      case 'phone':
        final failure = await ref.read(callingAdapterProvider).openCallingApp();
        if (context.mounted) showFailure(context, failure, what: 'Phone');
      case 'radio':
        await launchRole(context, ref, FactoryRole.radio);
      case 'apps':
        await nav.pushNamed(AppDrawerScreen.route);
      case 'settings':
        await nav.pushNamed(SettingsScreen.route);
    }
  }

  Future<void> _replaceMissing(
    BuildContext context,
    WidgetRef ref,
    String appId,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('App not available'),
        content: Text(
          '${parseAppId(appId).$1} is no longer installed or cannot be opened.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, 'remove'),
            child: const Text('Remove from dock'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, 'replace'),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    final settings = ref.read(settingsProvider.notifier);
    if (choice == 'remove') {
      settings.update(
        (s) =>
            s.copyWith(dock: s.dock.where((e) => e != 'app:$appId').toList()),
      );
      return;
    }
    final app = await pickApp(context, title: 'Replace with');
    if (app == null) return;
    settings.update(
      (s) => s.copyWith(
        dock: [for (final e in s.dock) e == 'app:$appId' ? 'app:${app.id}' : e],
      ),
    );
  }
}

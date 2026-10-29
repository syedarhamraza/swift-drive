import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/widgets/common.dart';
import '../../apps/state/apps_providers.dart';
import '../../apps/ui/app_picker.dart';
import '../../dashboard/ui/dock.dart';

class DockEditorScreen extends ConsumerWidget {
  const DockEditorScreen({super.key});

  static const route = '/settings/dock';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dock = ref.watch(settingsProvider.select((s) => s.dock));
    final apps = ref.watch(installedAppsProvider).value ?? const [];
    final c = ref.read(settingsProvider.notifier);
    final missingBuiltins = builtinDockIds
        .where((id) => !dock.contains('builtin:$id'))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customise dock'),
        actions: [
          TextButton(
            onPressed: () => c.update((s) => s.copyWith(dock: defaultDock)),
            child: const Text('Reset'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () => _add(context, ref, missingBuiltins),
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: dock.length,
        onReorderItem: (from, to) => c.update((s) {
          final list = [...s.dock];
          list.insert(to, list.removeAt(from));
          return s.copyWith(dock: list);
        }),
        itemBuilder: (context, i) {
          final raw = dock[i];
          final entry = DockEntry.parse(raw);
          final (title, leading) = switch (entry) {
            BuiltinEntry(:final id) => (
              builtinInfo(id).$1,
              Icon(builtinInfo(id).$2),
            ),
            AppEntry(:final appId) => switch (findApp(apps, appId)) {
              final app? => (
                app.label,
                AppIconImage(app.icon, size: 36) as Widget,
              ),
              null => (
                'Missing app',
                const Icon(Icons.warning_amber_rounded) as Widget,
              ),
            },
            null => ('Unknown entry', const Icon(Icons.help_outline) as Widget),
          };
          return ListTile(
            key: ValueKey(raw),
            leading: leading,
            title: Text(title),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => c.update(
                    (s) => s.copyWith(dock: [...s.dock]..removeAt(i)),
                  ),
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    List<String> builtins,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(
        title: const Text('Add to dock'),
        children: [
          for (final id in builtins)
            ListTile(
              leading: Icon(builtinInfo(id).$2),
              title: Text(builtinInfo(id).$1),
              onTap: () => Navigator.pop(d, 'builtin:$id'),
            ),
          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text('An installed app…'),
            onTap: () => Navigator.pop(d, 'app'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    var entry = choice;
    if (choice == 'app') {
      final app = await pickApp(context, title: 'Pin an app');
      if (app == null) return;
      entry = 'app:${app.id}';
    }
    ref
        .read(settingsProvider.notifier)
        .update(
          (s) =>
              s.dock.contains(entry) ? s : s.copyWith(dock: [...s.dock, entry]),
        );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/widgets/common.dart';
import '../data/apps_repository.dart';
import '../state/apps_providers.dart';

String roleLabel(FactoryRole role) => switch (role) {
  FactoryRole.navigation => 'Navigation',
  FactoryRole.music => 'Music',
  FactoryRole.phone => 'Phone',
  FactoryRole.radio => 'Radio',
  FactoryRole.vehicleSettings => 'Vehicle settings',
};

IconData roleIcon(FactoryRole role) => switch (role) {
  FactoryRole.navigation => Icons.navigation_outlined,
  FactoryRole.music => Icons.music_note_outlined,
  FactoryRole.phone => Icons.phone_outlined,
  FactoryRole.radio => Icons.radio_outlined,
  FactoryRole.vehicleSettings => Icons.directions_car_outlined,
};

Future<AppInfo?> pickApp(BuildContext context, {required String title}) =>
    showDialog<AppInfo>(
      context: context,
      builder: (_) => _AppPickerDialog(title: title),
    );

/// Lets the user (re)assign the app used for [role]. Returns the chosen app, or null if cancelled.
Future<AppInfo?> chooseRoleApp(
  BuildContext context,
  WidgetRef ref,
  FactoryRole role,
) async {
  final app = await pickApp(
    context,
    title: 'Choose ${roleLabel(role).toLowerCase()} app',
  );
  if (app != null) {
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(shortcuts: {...s.shortcuts, role: app.id}));
  }
  return app;
}

/// Opens the app configured for [role]. When none is set (or it was uninstalled) the user picks one.
Future<void> launchRole(
  BuildContext context,
  WidgetRef ref,
  FactoryRole role,
) async {
  final launcher = ref.read(appLauncherProvider);
  final app =
      launcher.shortcutApp(role) ?? await chooseRoleApp(context, ref, role);
  if (app == null) return;
  final failure = await launcher.launch(app.id);
  if (!context.mounted) return;
  showFailure(
    context,
    failure,
    what: app.label,
    action: SnackBarAction(
      label: 'Choose another',
      onPressed: () => chooseRoleApp(context, ref, role),
    ),
  );
}

class _AppPickerDialog extends ConsumerStatefulWidget {
  const _AppPickerDialog({required this.title});

  final String title;

  @override
  ConsumerState<_AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends ConsumerState<_AppPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(installedAppsProvider);
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search apps',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: apps.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const StatusMessage(
                  icon: Icons.error_outline,
                  title: 'Could not load installed apps',
                ),
                data: (list) {
                  final filtered = filterApps(list, query: _query);
                  if (filtered.isEmpty) {
                    return const StatusMessage(
                      icon: Icons.apps,
                      title: 'No matching apps',
                    );
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final app = filtered[i];
                      return ListTile(
                        leading: AppIconImage(app.icon, size: 40),
                        title: Text(app.label),
                        subtitle: Text(
                          app.packageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, app),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

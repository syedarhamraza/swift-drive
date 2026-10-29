import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../state/apps_providers.dart';
import 'app_picker.dart';

/// Maps each role (radio, phone, …) to an installed app chosen by the user. No package names are assumed.
class FactoryAppsSection extends ConsumerWidget {
  const FactoryAppsSection({super.key, this.roles = FactoryRole.values});

  final List<FactoryRole> roles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortcuts = ref.watch(settingsProvider.select((s) => s.shortcuts));
    final apps = ref.watch(installedAppsProvider).value;
    return Column(
      children: [
        for (final role in roles)
          Builder(
            builder: (context) {
              final id = shortcuts[role];
              final app = id == null || apps == null ? null : findApp(apps, id);
              final missing = id != null && apps != null && app == null;
              return ListTile(
                leading: app == null
                    ? Icon(roleIcon(role))
                    : AppIconImage(app.icon, size: 36),
                title: Text(roleLabel(role)),
                subtitle: Text(
                  missing
                      ? 'Previously selected app is missing — tap to choose another'
                      : (app?.label ?? 'Not set'),
                ),
                trailing: missing
                    ? const Icon(
                        Icons.warning_amber_rounded,
                        color: SdColors.warning,
                      )
                    : (id == null
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.clear),
                              onPressed: () => ref
                                  .read(settingsProvider.notifier)
                                  .update(
                                    (s) => s.copyWith(
                                      shortcuts: {...s.shortcuts}..remove(role),
                                    ),
                                  ),
                            )),
                onTap: () => chooseRoleApp(context, ref, role),
              );
            },
          ),
      ],
    );
  }
}

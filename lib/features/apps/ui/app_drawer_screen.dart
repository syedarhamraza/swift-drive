import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../data/apps_repository.dart';
import '../state/apps_providers.dart';
import 'app_picker.dart';

class AppDrawerScreen extends ConsumerStatefulWidget {
  const AppDrawerScreen({super.key});

  static const route = '/apps';

  @override
  ConsumerState<AppDrawerScreen> createState() => _AppDrawerScreenState();
}

class _AppDrawerScreenState extends ConsumerState<AppDrawerScreen> {
  String _query = '';
  bool _showHidden = false;

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(installedAppsProvider);
    final hidden = ref.watch(settingsProvider.select((s) => s.hidden));
    final favorites = ref.watch(settingsProvider.select((s) => s.favorites));
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'Search apps',
            prefixIcon: Icon(Icons.search),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          IconButton(
            tooltip: _showHidden ? 'Hide hidden apps' : 'Show hidden apps',
            icon: Icon(
              _showHidden ? Icons.visibility : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _showHidden = !_showHidden),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(installedAppsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: apps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: StatusMessage(
            icon: Icons.error_outline,
            title: 'Could not load installed apps',
            actionLabel: 'Retry',
            onAction: () => ref.read(installedAppsProvider.notifier).refresh(),
          ),
        ),
        data: (list) {
          final visible = filterApps(
            list,
            query: _query,
            hidden: hidden,
            favorites: favorites,
            showHidden: _showHidden,
          );
          if (visible.isEmpty) {
            return const Center(
              child: StatusMessage(icon: Icons.apps, title: 'No apps found'),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(SdSpace.lg),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 132,
              mainAxisExtent: 128,
              crossAxisSpacing: SdSpace.sm,
              mainAxisSpacing: SdSpace.sm,
            ),
            itemCount: visible.length,
            itemBuilder: (context, i) => _AppTile(
              app: visible[i],
              favorite: favorites.contains(visible[i].id),
              hidden: hidden.contains(visible[i].id),
            ),
          );
        },
      ),
    );
  }
}

class _AppTile extends ConsumerWidget {
  const _AppTile({
    required this.app,
    required this.favorite,
    required this.hidden,
  });

  final AppInfo app;
  final bool favorite;
  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = Theme.of(context).textTheme.bodyMedium;
    return InkWell(
      borderRadius: BorderRadius.circular(SdRadius.button),
      onTap: () async {
        final failure = await ref.read(appLauncherProvider).launch(app.id);
        if (context.mounted) showFailure(context, failure, what: app.label);
      },
      onLongPress: () => _showActions(context, ref),
      child: Opacity(
        opacity: hidden ? 0.45 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppIconImage(app.icon, size: 56),
                if (favorite)
                  const Positioned(
                    right: -6,
                    top: -6,
                    child: Icon(Icons.star, size: 18, color: SdColors.warning),
                  ),
              ],
            ),
            const SizedBox(height: SdSpace.sm),
            Text(
              app.label,
              style: label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider.notifier);
    final pinned = ref.read(settingsProvider).dock.contains('app:${app.id}');
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: AppIconImage(app.icon, size: 40),
              title: Text(app.label),
              subtitle: Text(app.packageName),
            ),
            const Divider(),
            ListTile(
              leading: Icon(favorite ? Icons.star : Icons.star_border),
              title: Text(
                favorite ? 'Remove from favourites' : 'Add to favourites',
              ),
              onTap: () {
                settings.update(
                  (s) => s.copyWith(
                    favorites: favorite
                        ? ({...s.favorites}..remove(app.id))
                        : {...s.favorites, app.id},
                  ),
                );
                Navigator.pop(sheet);
              },
            ),
            ListTile(
              leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(pinned ? 'Unpin from dock' : 'Pin to dock'),
              onTap: () {
                settings.update(
                  (s) => s.copyWith(
                    dock: pinned
                        ? s.dock.where((e) => e != 'app:${app.id}').toList()
                        : [...s.dock, 'app:${app.id}'],
                  ),
                );
                Navigator.pop(sheet);
              },
            ),
            ListTile(
              leading: Icon(
                hidden ? Icons.visibility : Icons.visibility_off_outlined,
              ),
              title: Text(hidden ? 'Show in app list' : 'Hide from app list'),
              onTap: () {
                settings.update(
                  (s) => s.copyWith(
                    hidden: hidden
                        ? ({...s.hidden}..remove(app.id))
                        : {...s.hidden, app.id},
                  ),
                );
                Navigator.pop(sheet);
              },
            ),
            for (final role in FactoryRole.values)
              ListTile(
                leading: Icon(roleIcon(role)),
                title: Text('Use as ${roleLabel(role).toLowerCase()} app'),
                onTap: () {
                  settings.update(
                    (s) =>
                        s.copyWith(shortcuts: {...s.shortcuts, role: app.id}),
                  );
                  Navigator.pop(sheet);
                },
              ),
          ],
        ),
      ),
    );
  }
}

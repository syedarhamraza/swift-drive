import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_failure.dart';
import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../dashboard/state/dashboard_providers.dart';
import '../../launcher/data/launcher_repository.dart';
import '../../launcher/state/launcher_providers.dart';
import '../data/apps_repository.dart';
import '../state/apps_providers.dart';
import 'app_picker.dart';

/// Full-screen drawer for routes outside the dashboard; the dashboard shows [AppDrawerPanel] in place.
class AppDrawerScreen extends StatelessWidget {
  const AppDrawerScreen({super.key});

  static const route = '/apps';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SdSpace.sm),
        child: AppDrawerPanel(onClose: () => Navigator.maybePop(context)),
      ),
    ),
  );
}

/// App grid with search, paged by large up/down buttons (easier than flinging while parked).
class AppDrawerPanel extends ConsumerStatefulWidget {
  const AppDrawerPanel({super.key, this.onClose});

  /// Defaults to closing the dashboard's drawer.
  final VoidCallback? onClose;

  @override
  ConsumerState<AppDrawerPanel> createState() => _AppDrawerPanelState();
}

class _AppDrawerPanelState extends ConsumerState<AppDrawerPanel> {
  final _scroll = ScrollController();
  String _query = '';
  bool _showHidden = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _close() => widget.onClose != null
      ? widget.onClose!()
      : ref.read(drawerOpenProvider.notifier).set(false);

  void _page(int direction) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final target = (p.pixels + direction * p.viewportDimension * 0.9).clamp(
      0.0,
      p.maxScrollExtent,
    );
    final d = SdMotion.of(context, SdMotion.long);
    if (d == Duration.zero) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: d, curve: SdMotion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(installedAppsProvider);
    final hidden = ref.watch(settingsProvider.select((s) => s.hidden));
    final favorites = ref.watch(settingsProvider.select((s) => s.favorites));
    final homes = ref.watch(
      homeStatusProvider.select((h) => h.value?.otherHomes ?? const []),
    );
    final scheme = Theme.of(context).colorScheme;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        SdSpace.md,
        SdSpace.md,
        SdSpace.sm,
        SdSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search apps',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
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
          IconButton(
            tooltip: 'Close apps',
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
        ],
      ),
    );

    final body = apps.when(
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
        // The way back to the factory launcher comes first, unless the user is searching.
        final factory = _query.isEmpty ? homes : const <HomeApp>[];
        if (visible.isEmpty && factory.isEmpty) {
          return const Center(
            child: StatusMessage(icon: Icons.apps, title: 'No apps found'),
          );
        }
        return Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Page up',
                  iconSize: 32,
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  onPressed: () => _page(-1),
                ),
                const SizedBox(height: SdSpace.lg),
                IconButton(
                  tooltip: 'Page down',
                  iconSize: 32,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  onPressed: () => _page(1),
                ),
              ],
            ),
            Expanded(
              child: GridView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                  0,
                  0,
                  SdSpace.md,
                  SdSpace.md,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisExtent: 116,
                  crossAxisSpacing: SdSpace.xs,
                  mainAxisSpacing: SdSpace.xs,
                ),
                itemCount: factory.length + visible.length,
                itemBuilder: (context, i) {
                  if (i < factory.length) return _FactoryTile(home: factory[i]);
                  final app = visible[i - factory.length];
                  return _AppTile(
                    app: app,
                    favorite: favorites.contains(app.id),
                    hidden: hidden.contains(app.id),
                    onLaunched: _close,
                  );
                },
              ),
            ),
          ],
        );
      },
    );

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SdRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          header,
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Opens the device's original launcher (the spec's guaranteed way back).
class _FactoryTile extends ConsumerWidget {
  const _FactoryTile({required this.home});

  final HomeApp home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return _Tile(
      label: 'Exit to ${home.label}',
      tooltip: 'Open ${home.label} (factory launcher)',
      icon: CircleAvatar(
        radius: 28,
        backgroundColor: scheme.primaryContainer,
        child: Icon(
          Icons.exit_to_app_rounded,
          size: 28,
          color: scheme.onPrimaryContainer,
        ),
      ),
      onTap: () async {
        try {
          await ref.read(launcherRepositoryProvider).launchHome(home);
        } on PlatformFailure catch (f) {
          if (context.mounted) showFailure(context, f, what: home.label);
        }
      },
    );
  }
}

/// Icon over a two-line label, the shared shape of every drawer entry.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.onLongPress,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final String? tooltip;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tile = InkWell(
      borderRadius: BorderRadius.circular(SdRadius.button),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(height: SdSpace.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return tooltip == null ? tile : Tooltip(message: tooltip, child: tile);
  }
}

class _AppTile extends ConsumerWidget {
  const _AppTile({
    required this.app,
    required this.favorite,
    required this.hidden,
    required this.onLaunched,
  });

  final AppInfo app;
  final bool favorite;
  final bool hidden;
  final VoidCallback onLaunched;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Opacity(
    opacity: hidden ? 0.45 : 1,
    child: _Tile(
      label: app.label,
      onTap: () async {
        final failure = await ref.read(appLauncherProvider).launch(app.id);
        if (!context.mounted) return;
        // Coming back to the launcher should show the dashboard, not the drawer.
        if (failure == null) {
          onLaunched();
        } else {
          showFailure(context, failure, what: app.label);
        }
      },
      onLongPress: () => _showActions(context, ref),
      icon: Stack(
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
    ),
  );

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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../apps/data/apps_repository.dart';
import '../../apps/state/apps_providers.dart';
import '../../apps/ui/app_picker.dart';
import '../../bluetooth/domain/calling_adapter.dart';
import '../../location/state/location_providers.dart';
import '../../settings/ui/settings_screen.dart';
import '../domain/dashboard_layout.dart';
import '../state/dashboard_providers.dart';
import 'clock_card.dart';

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
  'maps' => ('Maps', Icons.map_rounded),
  'music' => ('Music', Icons.music_note_rounded),
  'phone' => ('Phone', Icons.phone_rounded),
  'radio' => ('Radio', Icons.radio_rounded),
  'apps' => ('Apps', Icons.apps_rounded),
  'settings' => ('Settings', Icons.settings_rounded),
  _ => (id, Icons.help_outline),
};

class Dock extends ConsumerWidget {
  const Dock({super.key, required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Apps and Settings are pinned at the end so they stay reachable even when the user removed them from
    // the dock or added more entries than fit. Home is left out: the rail only exists on the home screen.
    const fixed = [BuiltinEntry('apps'), BuiltinEntry('settings')];
    final entries = ref
        .watch(settingsProvider.select((s) => s.dock))
        .map(DockEntry.parse)
        .nonNulls
        .where(
          (e) =>
              !(e is BuiltinEntry &&
                  (e.id == 'settings' || e.id == 'apps' || e.id == 'home')),
        )
        .toList();
    final drawerOpen = ref.watch(drawerOpenProvider);
    final scheme = Theme.of(context).colorScheme;
    final axis = vertical ? Axis.vertical : Axis.horizontal;

    final rail = Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SdRadius.rail),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // Buttons shrink so the rail fits (e.g. 1024x600 at hdpi is only ~400 dp tall). If even minimum
          // touch targets do not fit, the last pinned entries are left out (they stay in the drawer)
          // rather than showing a half-cut icon.
          final main =
              (vertical ? box.maxHeight - _RailHeader.height : box.maxWidth) -
              SdSpace.sm;
          final room = (main / SdSize.minTarget).floor() - fixed.length;
          final shown = entries.take(room.clamp(0, entries.length)).toList();
          final extent = (main / (shown.length + fixed.length)).clamp(
            SdSize.minTarget,
            64.0,
          );
          Widget button(DockEntry e) => _DockButton(
            entry: e,
            extent: extent,
            vertical: vertical,
            active: drawerOpen && e is BuiltinEntry && e.id == 'apps',
          );
          return Flex(
            direction: axis,
            children: [
              if (vertical) const _RailHeader(),
              for (final e in shown) button(e),
              const Spacer(),
              for (final e in fixed) button(e),
              const SizedBox(width: SdSpace.sm, height: SdSpace.sm),
            ],
          );
        },
      ),
    );
    return SafeArea(
      right: !vertical,
      top: vertical,
      child: Padding(
        padding: vertical
            ? const EdgeInsets.fromLTRB(SdSpace.sm, SdSpace.sm, 0, SdSpace.sm)
            : const EdgeInsets.fromLTRB(SdSpace.sm, 0, SdSpace.sm, SdSpace.sm),
        child: SizedBox(
          width: vertical ? railExtent - 2 * SdSpace.sm : null,
          height: vertical ? null : 72,
          child: rail,
        ),
      ),
    );
  }
}

/// Small clock and GPS state at the top of the vertical rail.
class _RailHeader extends ConsumerWidget {
  const _RailHeader();

  static const height = 76.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFix = ref.watch(locationProvider.select((s) => s.fix != null));
    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: SdSpace.sm),
            child: ClockText(compact: true),
          ),
          const SizedBox(height: SdSpace.xs),
          Icon(
            hasFix ? Icons.gps_fixed : Icons.gps_not_fixed,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            semanticLabel: hasFix
                ? 'GPS position available'
                : 'No GPS position',
          ),
        ],
      ),
    );
  }
}

class _DockButton extends ConsumerWidget {
  const _DockButton({
    required this.entry,
    required this.extent,
    required this.vertical,
    this.active = false,
  });

  final DockEntry entry;

  /// Size along the rail; the circle shrinks with it (the tooltip carries the label).
  final double extent;
  final bool vertical;

  /// Highlighted, e.g. Apps while the drawer is open.
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final circle = (extent - SdSpace.sm).clamp(44.0, 56.0);
    final Widget icon;
    final String label;
    VoidCallback onTap;
    switch (entry) {
      case BuiltinEntry(:final id):
        final (l, i) = builtinInfo(id);
        label = l;
        // Music, Phone and Radio open the user's chosen app, so they show that app's own icon.
        final role = switch (id) {
          'music' => FactoryRole.music,
          'phone' => FactoryRole.phone,
          'radio' => FactoryRole.radio,
          _ => null,
        };
        final chosen = role == null
            ? null
            : ref.watch(settingsProvider.select((s) => s.shortcuts[role]));
        final apps = ref.watch(installedAppsProvider).value;
        final app = chosen == null || apps == null
            ? null
            : findApp(apps, chosen);
        // Glyphs sit straight on the rail, sized like app icons, rather than in a circle of their own.
        icon = app?.icon != null
            ? AppIconImage(app!.icon, size: circle)
            : Icon(
                i,
                size: circle * 0.7,
                color: active ? scheme.onPrimaryContainer : scheme.onSurface,
              );
        onTap = () => _builtinAction(context, ref, id);
      case AppEntry(:final appId):
        final apps = ref.watch(installedAppsProvider).value;
        final app = apps == null ? null : findApp(apps, appId);
        final missing = apps != null && app == null;
        label = app?.label ?? (missing ? 'Missing app' : '…');
        icon = missing
            ? Icon(
                Icons.warning_amber_rounded,
                size: circle * 0.7,
                color: SdColors.warning,
              )
            : AppIconImage(app?.icon, size: circle);
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
    final background = active ? scheme.primaryContainer : Colors.transparent;
    return SizedBox(
      width: vertical ? railExtent - 2 * SdSpace.sm : extent,
      height: vertical ? extent : 72,
      child: Center(
        child: Tooltip(
          message: label,
          child: AnimatedContainer(
            duration: SdMotion.of(context, SdMotion.medium),
            curve: SdMotion.curve,
            width: circle,
            height: circle,
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              color: background,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Center(child: icon),
              ),
            ),
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
        ref.read(drawerOpenProvider.notifier).set(false);
        nav.popUntil((r) => r.isFirst);
      case 'maps':
        // The dashboard map is for orientation; turn-by-turn runs in the user's navigation app.
        await launchRole(context, ref, FactoryRole.navigation);
      case 'music':
        await launchRole(context, ref, FactoryRole.music);
      case 'phone':
        final failure = await ref.read(callingAdapterProvider).openCallingApp();
        if (context.mounted) showFailure(context, failure, what: 'Phone');
      case 'radio':
        await launchRole(context, ref, FactoryRole.radio);
      case 'apps':
        ref.read(drawerOpenProvider.notifier).toggle();
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

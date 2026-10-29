import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../apps/data/apps_repository.dart';
import '../../apps/state/apps_providers.dart';
import '../data/navigation_models.dart';
import '../state/navigation_providers.dart';

Future<void> showDestinationSheet(
  BuildContext context, {
  required bool mapAvailable,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.85,
    child: _DestinationSheet(mapAvailable: mapAvailable),
  ),
);

/// Opens [place] in the user's navigation app (or the system chooser) via a documented geo: intent.
Future<void> openExternalNavigation(
  BuildContext context,
  WidgetRef ref,
  Place place,
) async {
  final appId = ref.read(settingsProvider).shortcuts[FactoryRole.navigation];
  final pkg = appId == null ? null : parseAppId(appId).$1;
  final p = place.point;
  final uri =
      'geo:${p.lat},${p.lon}?q=${p.lat},${p.lon}(${Uri.encodeComponent(place.name)})';
  final failure = await ref
      .read(appLauncherProvider)
      .openGeo(uri, packageName: pkg);
  if (context.mounted) showFailure(context, failure, what: 'Navigation app');
}

class _DestinationSheet extends ConsumerStatefulWidget {
  const _DestinationSheet({required this.mapAvailable});

  final bool mapAvailable;

  @override
  ConsumerState<_DestinationSheet> createState() => _DestinationSheetState();
}

class _DestinationSheetState extends ConsumerState<_DestinationSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = ref.watch(navigationProvider);
    final unit = ref.watch(settingsProvider.select((s) => s.speedUnit));
    final controller = ref.read(navigationProvider.notifier);
    final t = Theme.of(context).textTheme;

    Widget content;
    switch (nav.phase) {
      case NavPhase.searching || NavPhase.calculating:
        content = const Center(child: CircularProgressIndicator());
      case NavPhase.routeReady
          when nav.route != null && nav.destination != null:
        final route = nav.route!;
        final eta = DateTime.now().add(
          Duration(seconds: route.durationSeconds.round()),
        );
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nav.destination!.name, style: t.titleLarge),
            if (nav.destination!.detail != null)
              Text(nav.destination!.detail!, style: t.bodySmall, maxLines: 2),
            const SizedBox(height: SdSpace.md),
            Text(
              '${formatDistance(route.distanceMeters, unit)} · ${formatDuration(route.durationSeconds)} · '
              'arrive ${formatClock(eta, use24h: ref.read(settingsProvider).use24h)}',
              style: t.titleMedium,
            ),
            const SizedBox(height: SdSpace.lg),
            Wrap(
              spacing: SdSpace.md,
              runSpacing: SdSpace.md,
              children: [
                if (widget.mapAvailable)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(160, SdSize.driveTarget),
                    ),
                    onPressed: () {
                      controller.start();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('Start'),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(160, SdSize.driveTarget),
                  ),
                  onPressed: () =>
                      openExternalNavigation(context, ref, nav.destination!),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in navigation app'),
                ),
                TextButton(
                  onPressed: controller.cancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        );
      case NavPhase.error || NavPhase.unavailable:
        content = StatusMessage(
          icon: nav.phase == NavPhase.unavailable
              ? Icons.gps_not_fixed
              : Icons.wifi_off,
          title: nav.message ?? 'Something went wrong',
          actionLabel: nav.destination != null
              ? 'Open in navigation app'
              : null,
          onAction: nav.destination != null
              ? () => openExternalNavigation(context, ref, nav.destination!)
              : null,
        );
      default:
        content = nav.results.isEmpty
            ? Center(
                child: Text(
                  nav.message ?? 'Search for an address or place. Enter destinations while parked.',
                  style: t.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              )
            : ListView(
                children: [
                  for (final p in nav.results)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(p.name),
                      subtitle: p.detail == null
                          ? null
                          : Text(
                              p.detail!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => controller.choose(p),
                    ),
                ],
              );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        SdSpace.lg,
        SdSpace.lg,
        SdSpace.lg,
        SdSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Where to?',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => controller.search(_text.text),
              ),
            ),
            onSubmitted: controller.search,
          ),
          const SizedBox(height: SdSpace.md),
          Expanded(child: content),
          Text(
            'Search © OpenStreetMap contributors (Nominatim) · Routes: OSRM',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}

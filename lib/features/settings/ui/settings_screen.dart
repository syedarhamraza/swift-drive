import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../apps/ui/factory_apps_section.dart';
import '../../diagnostics/state/diagnostics_providers.dart';
import '../../diagnostics/ui/diagnostics_screen.dart';
import '../../launcher/ui/launcher_setup.dart';
import '../../launcher/ui/permissions_section.dart';
import '../../media/state/media_providers.dart';
import '../../weather/state/weather_providers.dart';
import 'dock_editor_screen.dart';

String themeLabel(AppThemeMode m) => switch (m) {
  AppThemeMode.dark => 'Dark',
  AppThemeMode.light => 'Light',
  AppThemeMode.system => 'Follow system',
  AppThemeMode.auto => 'Automatic (sunrise/sunset)',
};

String layoutLabel(DashboardLayout l) => switch (l) {
  DashboardLayout.balanced => 'Balanced',
  DashboardLayout.mapFocused => 'Map focused',
  DashboardLayout.mediaFocused => 'Media focused',
  DashboardLayout.compact => 'Compact',
};

/// Configuration lives here, away from the driving dashboard.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const route = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: SdSpace.xl),
        children: [
          const _Header('Appearance'),
          ChoiceTile<AppThemeMode>(
            title: 'Theme',
            value: s.themeMode,
            values: AppThemeMode.values,
            label: themeLabel,
            onChanged: (v) => c.update((x) => x.copyWith(themeMode: v)),
          ),
          ListTile(
            title: const Text('Accent colour'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: SdSpace.sm),
              child: AccentPicker(selected: s.accentIndex),
            ),
          ),
          ChoiceTile<DashboardLayout>(
            title: 'Dashboard layout',
            value: s.layout,
            values: DashboardLayout.values,
            label: layoutLabel,
            onChanged: (v) => c.update((x) => x.copyWith(layout: v)),
          ),

          const _Header('Dashboard'),
          ListTile(
            leading: const Icon(Icons.dock_outlined),
            title: const Text('Customise dock'),
            subtitle: const Text('Add, remove and reorder shortcuts'),
            onTap: () => Navigator.pushNamed(context, DockEditorScreen.route),
          ),
          SwitchListTile(
            title: const Text('Show GPS speed'),
            value: s.showSpeed,
            onChanged: (v) => c.update((x) => x.copyWith(showSpeed: v)),
          ),
          SwitchListTile(
            title: const Text('Use 24-hour clock'),
            value: s.use24h,
            onChanged: (v) => c.update((x) => x.copyWith(use24h: v)),
          ),

          const _Header('Default and factory apps'),
          const FactoryAppsSection(),

          const _Header('Navigation'),
          SwitchListTile(
            title: const Text('Embedded map'),
            subtitle: const Text(
              'Turn off if the map misbehaves on this head unit; navigation apps still work',
            ),
            value: s.mapEnabled,
            onChanged: (v) => c.update((x) => x.copyWith(mapEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('Heading-up map'),
            subtitle: const Text(
              'Rotate the map to the direction of travel while following',
            ),
            value: s.headingUp,
            onChanged: (v) => c.update((x) => x.copyWith(headingUp: v)),
          ),
          SwitchListTile(
            title: const Text('Voice guidance muted'),
            value: s.voiceMuted,
            onChanged: (v) => c.update((x) => x.copyWith(voiceMuted: v)),
          ),
          ChoiceTile<SpeedUnit>(
            title: 'Speed and distance units',
            value: s.speedUnit,
            values: SpeedUnit.values,
            label: (u) => u == SpeedUnit.kmh ? 'km/h, metres' : 'mph, miles',
            onChanged: (v) => c.update((x) => x.copyWith(speedUnit: v)),
          ),
          UrlTile(
            title: 'Light map style URL',
            value: s.mapStyleLight,
            fallback: defaultMapStyleLight,
            onChanged: (v) => c.update((x) => x.copyWith(mapStyleLight: v)),
          ),
          UrlTile(
            title: 'Dark map style URL',
            value: s.mapStyleDark,
            fallback: defaultMapStyleDark,
            onChanged: (v) => c.update((x) => x.copyWith(mapStyleDark: v)),
          ),
          UrlTile(
            title: 'Routing server (OSRM)',
            value: s.routingUrl,
            fallback: defaultRoutingUrl,
            onChanged: (v) => c.update((x) => x.copyWith(routingUrl: v)),
          ),
          UrlTile(
            title: 'Geocoding server (Nominatim)',
            value: s.geocodingUrl,
            fallback: defaultGeocodingUrl,
            onChanged: (v) => c.update((x) => x.copyWith(geocodingUrl: v)),
          ),

          const _Header('Media'),
          SwitchListTile(
            title: const Text('Show album artwork'),
            value: s.showArtwork,
            onChanged: (v) => c.update((x) => x.copyWith(showArtwork: v)),
          ),
          ListTile(
            title: const Text('Preferred media source'),
            subtitle: Text(_mediaSourceLabel(ref, s.lastMediaPackage)),
          ),

          const _Header('Weather'),
          ChoiceTile<TempUnit>(
            title: 'Temperature unit',
            value: s.tempUnit,
            values: TempUnit.values,
            label: (u) => u == TempUnit.celsius ? 'Celsius' : 'Fahrenheit',
            onChanged: (v) => c.update((x) => x.copyWith(tempUnit: v)),
          ),
          ChoiceTile<int>(
            title: 'Refresh interval',
            value: s.weatherRefreshMinutes,
            values: const [15, 30, 60, 120],
            label: (m) => '$m minutes',
            onChanged: (v) =>
                c.update((x) => x.copyWith(weatherRefreshMinutes: v)),
          ),
          const _WeatherStatusTile(),
          UrlTile(
            title: 'Weather API (Open-Meteo)',
            value: s.weatherUrl,
            fallback: defaultWeatherUrl,
            onChanged: (v) => c.update((x) => x.copyWith(weatherUrl: v)),
          ),

          const _Header('Notifications'),
          SwitchListTile(
            title: const Text('Hide non-essential notifications'),
            subtitle: const Text(
              'Low-priority, promotional and background notifications are not shown',
            ),
            value: s.suppressNonEssential,
            onChanged: (v) =>
                c.update((x) => x.copyWith(suppressNonEssential: v)),
          ),

          const _Header('Permissions'),
          const PermissionsSection(),

          const _Header('Launcher'),
          const LauncherSetupSection(),

          const _Header('Display'),
          SwitchListTile(
            title: const Text('Full screen'),
            subtitle: const Text(
              'Hide the status and navigation bars. Swipe from an edge to show them briefly.',
            ),
            value: s.fullScreen,
            onChanged: (v) => c.update((x) => x.copyWith(fullScreen: v)),
          ),

          const _Header('Performance'),
          SwitchListTile(
            title: const Text('Performance mode'),
            subtitle: const Text(
              'No page transitions or progress animation, simpler map, less frequent weather',
            ),
            value: s.performanceMode,
            onChanged: (v) => c.update((x) => x.copyWith(performanceMode: v)),
          ),
          SwitchListTile(
            title: const Text('Map compatibility rendering (TextureView)'),
            subtitle: const Text(
              'Helps head units where the map turns black after sleep. Applies after restarting SwiftDrive.',
            ),
            value: s.mapTextureMode,
            onChanged: (v) => c.update((x) => x.copyWith(mapTextureMode: v)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Clear diagnostic log'),
            onTap: () {
              AppLog.clear();
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Log cleared')));
            },
          ),

          const _Header('Compatibility'),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('Device diagnostics'),
            subtitle: const Text('Capabilities, logs and report export'),
            onTap: () => Navigator.pushNamed(context, DiagnosticsScreen.route),
          ),

          const _Header('About'),
          const _AboutTiles(),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset all settings'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Reset settings?'),
                  content: const Text(
                    'Dock, shortcuts, theme and endpoints return to their defaults.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (ok == true) c.reset();
            },
          ),
        ],
      ),
    );
  }

  String _mediaSourceLabel(WidgetRef ref, String? pkg) {
    if (pkg == null) return 'Automatic (the app that is playing)';
    final label = ref
        .read(mediaProvider)
        .sessions
        .where((x) => x.packageName == pkg)
        .firstOrNull
        ?.appLabel;
    return '${label ?? pkg} — change it with the source button on the media card';
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      SdSpace.lg,
      SdSpace.xl,
      SdSpace.lg,
      SdSpace.xs,
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class ChoiceTile<T> extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.title,
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: Text(label(value)),
    trailing: const Icon(Icons.chevron_right),
    onTap: () async {
      final picked = await showDialog<T>(
        context: context,
        builder: (d) => SimpleDialog(
          title: Text(title),
          children: [
            for (final v in values)
              ListTile(
                leading: Icon(
                  v == value
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(label(v)),
                onTap: () => Navigator.pop(d, v),
              ),
          ],
        ),
      );
      if (picked != null) onChanged(picked);
    },
  );
}

class AccentPicker extends ConsumerWidget {
  const AccentPicker({super.key, required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: SdSpace.md,
    children: [
      for (var i = 0; i < SdColors.accents.length; i++)
        Semantics(
          button: true,
          selected: i == selected,
          label: 'Accent ${i + 1}',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => ref
                .read(settingsProvider.notifier)
                .update((s) => s.copyWith(accentIndex: i)),
            child: Container(
              width: SdSize.minTarget,
              height: SdSize.minTarget,
              decoration: BoxDecoration(
                color: SdColors.accents[i],
                shape: BoxShape.circle,
                border: i == selected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: 3,
                      )
                    : null,
              ),
            ),
          ),
        ),
    ],
  );
}

/// Editable endpoint. Only http(s) URLs are accepted; "Reset" restores the documented default.
class UrlTile extends StatelessWidget {
  const UrlTile({
    super.key,
    required this.title,
    required this.value,
    required this.fallback,
    required this.onChanged,
  });

  final String title;
  final String value;
  final String fallback;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    onTap: () async {
      final text = TextEditingController(text: value);
      final result = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: text,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(hintText: 'https://…'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, fallback),
              child: const Text('Reset to default'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, text.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      text.dispose();
      if (result == null) return;
      final uri = Uri.tryParse(result);
      if (uri == null ||
          !(uri.scheme == 'https' || uri.scheme == 'http') ||
          uri.host.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not a valid http(s) URL')),
          );
        }
        return;
      }
      onChanged(
        result.endsWith('/') ? result.substring(0, result.length - 1) : result,
      );
    },
  );
}

class _WeatherStatusTile extends ConsumerWidget {
  const _WeatherStatusTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider);
    final data = w.data;
    return ListTile(
      title: const Text('Cached weather'),
      subtitle: Text(
        data == null
            ? 'No weather data yet'
            : 'Updated ${formatAge(data.fetchedAt, DateTime.now())}${w.failed ? ' · last refresh failed' : ''}',
      ),
      trailing: IconButton(
        tooltip: 'Refresh now',
        icon: const Icon(Icons.refresh),
        onPressed: ref.read(weatherProvider.notifier).refresh,
      ),
    );
  }
}

class _AboutTiles extends ConsumerWidget {
  const _AboutTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceReportProvider).value?.device;
    final version = device == null
        ? '…'
        : '${device['appVersion']} (build ${device['appBuild']})';
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('SwiftDrive'),
          subtitle: Text('Version $version'),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Open-source licences'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'SwiftDrive',
            applicationVersion: version,
          ),
        ),
        const ListTile(
          leading: Icon(Icons.public),
          title: Text('Data sources'),
          subtitle: Text(
            'Map data © OpenStreetMap contributors · Tiles: OpenFreeMap · Search: Nominatim · Routing: OSRM (FOSSGIS) · '
            'Weather: Open-Meteo (CC BY 4.0). SwiftDrive is an independent launcher, not affiliated with Google, '
            'Android Auto or any vehicle manufacturer.',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.system_update_outlined),
          title: Text('Updates'),
          subtitle: Text(
            'SwiftDrive does not update itself. Install new APKs manually (see README).',
          ),
        ),
      ],
    );
  }
}

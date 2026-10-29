import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../apps/ui/factory_apps_section.dart';
import '../../diagnostics/state/diagnostics_providers.dart';
import '../../diagnostics/ui/diagnostics_screen.dart';
import '../../launcher/ui/launcher_setup.dart';
import '../../launcher/ui/permissions_section.dart';
import '../../settings/ui/settings_screen.dart';

/// First-run setup. Every step is optional; "Skip" goes straight to the dashboard.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _count = 6;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish() => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(onboardingDone: true));

  void _next() {
    if (_index == _count - 1) return _finish();
    _pages.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);

    Widget page(String title, String body, List<Widget> children) => ListView(
      padding: const EdgeInsets.all(SdSpace.xl),
      children: [
        Text(title, style: t.headlineMedium),
        const SizedBox(height: SdSpace.sm),
        Text(body, style: t.bodyLarge),
        const SizedBox(height: SdSpace.lg),
        ...children,
      ],
    );

    final report = ref.watch(deviceReportProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  page(
                    'Welcome to SwiftDrive',
                    'An independent, driver-friendly launcher for Android head units and tablets. It is not Android Auto '
                        'and is not affiliated with Google or any car maker. Factory apps (radio, phone, camera, vehicle '
                        'settings) are never changed or disabled.',
                    const [
                      Icon(Icons.directions_car_filled_outlined, size: 96),
                    ],
                  ),
                  page(
                    'Device check',
                    'What this device offers. Missing features simply show as unavailable; nothing else is affected.',
                    [
                      report.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) =>
                            const Text('Could not run the device check.'),
                        data: (r) => CapabilityList(report: r),
                      ),
                    ],
                  ),
                  page(
                    'Permissions',
                    'Grant only what you want to use. You can change this later in Settings.',
                    const [PermissionsSection()],
                  ),
                  page(
                    'Your apps',
                    'Choose the apps the dashboard shortcuts open, including factory radio and phone apps.',
                    const [
                      FactoryAppsSection(
                        roles: [
                          FactoryRole.navigation,
                          FactoryRole.music,
                          FactoryRole.phone,
                          FactoryRole.radio,
                        ],
                      ),
                    ],
                  ),
                  page(
                    'Look and layout',
                    'Dark is recommended for night driving.',
                    [
                      ChoiceTile<AppThemeMode>(
                        title: 'Theme',
                        value: s.themeMode,
                        values: AppThemeMode.values,
                        label: themeLabel,
                        onChanged: (v) =>
                            c.update((x) => x.copyWith(themeMode: v)),
                      ),
                      ChoiceTile<DashboardLayout>(
                        title: 'Dashboard layout',
                        value: s.layout,
                        values: DashboardLayout.values,
                        label: layoutLabel,
                        onChanged: (v) =>
                            c.update((x) => x.copyWith(layout: v)),
                      ),
                      ListTile(
                        title: const Text('Accent colour'),
                        subtitle: AccentPicker(selected: s.accentIndex),
                      ),
                    ],
                  ),
                  page(
                    'Home screen (optional)',
                    'SwiftDrive can be the screen the Home button opens. This is optional and reversible.',
                    const [LauncherSetupSection()],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(SdSpace.lg),
              child: Row(
                children: [
                  TextButton(onPressed: _finish, child: const Text('Skip')),
                  const Spacer(),
                  Text('${_index + 1} / $_count', style: t.bodyMedium),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(140, SdSize.driveTarget),
                    ),
                    onPressed: _next,
                    child: Text(_index == _count - 1 ? 'Done' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

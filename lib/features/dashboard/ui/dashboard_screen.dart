import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../launcher/state/launcher_providers.dart';
import '../../location/ui/speed_card.dart';
import '../../maps/ui/map_panel.dart';
import '../../media/ui/media_card.dart';
import '../../notifications/ui/notifications_card.dart';
import '../../radio/ui/radio_card.dart';
import '../../weather/ui/weather_card.dart';
import '../domain/dashboard_layout.dart';
import 'clock_card.dart';
import 'dock.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// Keeps the same map element (and native view) when the layout preset or orientation changes.
  static final _mapKey = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(settingsProvider.select((s) => s.layout));
    final showSpeed = ref.watch(settingsProvider.select((s) => s.showSpeed));
    final radio = ref.watch(
      settingsProvider.select(
        (s) => s.shortcuts.containsKey(FactoryRole.radio),
      ),
    );
    // As the default HOME app, Back must not leave the dashboard; as a normal app it may.
    final isHome = ref.watch(
      homeStatusProvider.select((h) => h.value?.isDefault ?? false),
    );

    return PopScope(
      canPop: !isHome,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, box) {
            final g = computeDashboardGeometry(
              box.biggest,
              preset,
              showSpeed: showSpeed,
              radioConfigured: radio,
            );
            final map = ClipRRect(
              borderRadius: BorderRadius.circular(SdRadius.card),
              child: MapPanel(key: _mapKey),
            );
            final side = _InfoPanel(widgets: g.widgets);
            final content = Padding(
              padding: const EdgeInsets.all(SdSpace.sm),
              child: Flex(
                direction: g.stacked ? Axis.vertical : Axis.horizontal,
                children: [
                  Expanded(flex: g.mapFlex, child: map),
                  const SizedBox(width: SdSpace.sm, height: SdSpace.sm),
                  Expanded(flex: g.sideFlex, child: side),
                ],
              ),
            );
            return g.dockOnLeft
                ? Row(
                    children: [
                      const Dock(vertical: true),
                      Expanded(child: SafeArea(left: false, child: content)),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: SafeArea(bottom: false, child: content)),
                      const Dock(vertical: false),
                    ],
                  );
          },
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.widgets});

  final List<DashboardWidget> widgets;

  @override
  Widget build(BuildContext context) {
    Widget build(DashboardWidget w) => switch (w) {
      DashboardWidget.clockWeather => const SdCard(
        child: Row(
          children: [
            Expanded(child: ClockText()),
            SizedBox(width: SdSpace.md),
            Flexible(child: WeatherSummary()),
          ],
        ),
      ),
      DashboardWidget.media => MediaCard(large: widgets.length <= 3),
      DashboardWidget.radio => const RadioCard(),
      DashboardWidget.speed => const SpeedCard(),
      DashboardWidget.notifications => const NotificationsCard(),
    };
    // Scrolls only when a small screen cannot fit every card.
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: widgets.length,
      separatorBuilder: (_, _) => const SizedBox(height: SdSpace.sm),
      itemBuilder: (_, i) => RepaintBoundary(child: build(widgets[i])),
    );
  }
}

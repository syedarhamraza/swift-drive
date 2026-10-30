import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../apps/ui/app_drawer_screen.dart';
import '../../launcher/state/launcher_providers.dart';
import '../../location/ui/speed_card.dart';
import '../../maps/ui/map_panel.dart';
import '../../media/ui/media_card.dart';
import '../../notifications/ui/notifications_card.dart';
import '../../radio/ui/radio_card.dart';
import '../../weather/ui/weather_panel.dart';
import '../domain/dashboard_layout.dart';
import '../state/dashboard_providers.dart';
import 'dock.dart';
import 'side_pager.dart';

const _gap = SizedBox(width: SdSpace.sm, height: SdSpace.sm);

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
    final drawerOpen = ref.watch(drawerOpenProvider);

    return PopScope(
      canPop: !isHome && !drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && drawerOpen) {
          ref.read(drawerOpenProvider.notifier).set(false);
        }
      },
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
            final content = Padding(
              padding: const EdgeInsets.all(SdSpace.sm),
              child: Flex(
                direction: g.stacked ? Axis.vertical : Axis.horizontal,
                children: [
                  Expanded(flex: g.mapFlex, child: map),
                  _gap,
                  Expanded(
                    flex: g.sideFlex,
                    child: _SidePanel(geometry: g, drawerOpen: drawerOpen),
                  ),
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

/// Cards beside the map. The app drawer slides in over them so the map stays visible.
class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.geometry, required this.drawerOpen});

  final DashboardGeometry geometry;
  final bool drawerOpen;

  static Widget _card(DashboardWidget w) => RepaintBoundary(
    child: switch (w) {
      DashboardWidget.notifications => const NotificationsCard(),
      DashboardWidget.media => const MediaCard(),
      DashboardWidget.radio => const RadioCard(),
      DashboardWidget.weather => const WeatherPanel(),
      DashboardWidget.speed => const SpeedCard(),
    },
  );

  static String _label(DashboardWidget w) => switch (w) {
    DashboardWidget.notifications => 'Notifications',
    DashboardWidget.media => 'Media',
    DashboardWidget.radio => 'Radio',
    DashboardWidget.weather => 'Weather',
    DashboardWidget.speed => 'Speed',
  };

  @override
  Widget build(BuildContext context) {
    final g = geometry;
    final pager = g.pager.isEmpty
        ? null
        : SidePager(
            pages: [for (final w in g.pager) _card(w)],
            labels: [for (final w in g.pager) _label(w)],
          );
    final column = Column(
      children: [
        for (final (i, w) in g.column.indexed) ...[
          if (i > 0) _gap,
          // Media takes the height the other cards leave.
          if (w == DashboardWidget.media)
            Expanded(child: _card(w))
          else
            _card(w),
        ],
        if (!g.pagerBeside && pager != null) ...[
          if (g.column.isNotEmpty) _gap,
          Expanded(child: pager),
        ],
      ],
    );
    final cards = g.pagerBeside && pager != null
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: column),
              _gap,
              Expanded(child: pager),
            ],
          )
        : column;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cards stay alive under the drawer (keeping the pager page) but stop ticking.
        TickerMode(enabled: !drawerOpen, child: cards),
        AnimatedSwitcher(
          duration: SdMotion.of(context, SdMotion.medium),
          switchInCurve: SdMotion.curve,
          switchOutCurve: SdMotion.exitCurve,
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(-0.04, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: drawerOpen
              ? const AppDrawerPanel(key: ValueKey('drawer'))
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

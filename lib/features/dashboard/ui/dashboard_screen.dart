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
            // The side rail floats over the left edge of the map and the drawer, so they start behind it.
            final area = Padding(
              padding: const EdgeInsets.all(SdSpace.sm),
              child: LayoutBuilder(
                builder: (context, inner) => _Panes(
                  geometry: g,
                  size: inner.biggest,
                  drawerOpen: drawerOpen,
                  cover: g.dockOnLeft ? railExtent - SdSpace.sm : 0,
                ),
              ),
            );
            return g.dockOnLeft
                ? Stack(
                    children: [
                      Positioned.fill(child: SafeArea(child: area)),
                      const Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Dock(vertical: true),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: SafeArea(bottom: false, child: area)),
                      const Dock(vertical: false),
                    ],
                  );
          },
        ),
      ),
    );
  }
}

/// Map and cards side by side. Opening the drawer puts it where the map was and pushes the map into the
/// cards' place (the cards slide off screen), so the map stays visible while picking an app.
class _Panes extends StatelessWidget {
  const _Panes({
    required this.geometry,
    required this.size,
    required this.drawerOpen,
    required this.cover,
  });

  final DashboardGeometry geometry;
  final Size size;
  final bool drawerOpen;

  /// How far the rail overlaps the first pane.
  final double cover;

  @override
  Widget build(BuildContext context) {
    final g = geometry;
    final horizontal = !g.stacked;
    final length = horizontal ? size.width : size.height;
    final split =
        cover +
        (length - cover - SdSpace.sm) * g.mapFlex / (g.mapFlex + g.sideFlex);
    final sideStart = split + SdSpace.sm;
    Rect span(double start, double end) => horizontal
        ? Rect.fromLTRB(start, 0, end, size.height)
        : Rect.fromLTRB(0, start, size.width, end);
    final duration = SdMotion.of(context, SdMotion.medium);

    return Stack(
      children: [
        // The map pushes the cards off the far edge; they stay alive (keeping the pager page) but stop ticking.
        AnimatedPositioned.fromRect(
          duration: duration,
          curve: SdMotion.curve,
          rect: drawerOpen
              ? span(length + SdSpace.sm, 2 * length - split)
              : span(sideStart, length),
          child: TickerMode(
            enabled: !drawerOpen,
            child: _SidePanel(geometry: g),
          ),
        ),
        AnimatedPositioned.fromRect(
          duration: duration,
          curve: SdMotion.curve,
          rect: drawerOpen ? span(sideStart, length) : span(0, split),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SdRadius.card),
            child: MapPanel(
              key: DashboardScreen._mapKey,
              leftInset: drawerOpen || !horizontal ? 0 : cover,
            ),
          ),
        ),
        Positioned.fromRect(
          rect: span(0, split),
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: SdMotion.curve,
            switchOutCurve: SdMotion.exitCurve,
            layoutBuilder: (current, previous) =>
                Stack(fit: StackFit.expand, children: [...previous, ?current]),
            // Slides out from behind the rail.
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: horizontal
                      ? const Offset(-0.15, 0)
                      : const Offset(0, -0.15),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: drawerOpen
                ? AppDrawerPanel(
                    key: const ValueKey('drawer'),
                    inset: EdgeInsets.only(left: horizontal ? cover : 0),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

/// Cards beside the map: a column and, when there is room or nothing else, the pager.
class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.geometry});

  final DashboardGeometry geometry;

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
    return g.pagerBeside && pager != null
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: column),
              _gap,
              Expanded(child: pager),
            ],
          )
        : column;
  }
}

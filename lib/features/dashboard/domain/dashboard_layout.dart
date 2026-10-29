import 'package:flutter/widgets.dart';

import '../../../core/storage/settings.dart';

enum DashboardWidget { clockWeather, media, radio, speed, notifications }

class DashboardGeometry {
  const DashboardGeometry({
    required this.dockOnLeft,
    required this.stacked,
    required this.mapFlex,
    required this.sideFlex,
    required this.widgets,
  });

  /// Landscape screens put the dock on the left: vertical space is the scarce dimension on head units.
  final bool dockOnLeft;

  /// Portrait (phone testing): map above the information panel.
  final bool stacked;
  final int mapFlex;
  final int sideFlex;

  /// Information-panel widgets, top to bottom.
  final List<DashboardWidget> widgets;
}

/// Pure layout decision, shared by every preset so the dashboard has one code path.
DashboardGeometry computeDashboardGeometry(
  Size size,
  DashboardLayout preset, {
  bool showSpeed = true,
  bool radioConfigured = false,
}) {
  final stacked = size.width < size.height;
  // Small screens (e.g. 1024x600 at high density) fall back to the compact preset automatically.
  final small = size.shortestSide < 480 || (!stacked && size.width < 760);
  final layout = small ? DashboardLayout.compact : preset;
  List<DashboardWidget> only(List<DashboardWidget> w) => w
      .where(
        (x) =>
            (showSpeed || x != DashboardWidget.speed) &&
            (radioConfigured || x != DashboardWidget.radio),
      )
      .toList();

  final (map, side, widgets) = switch (layout) {
    DashboardLayout.balanced => (
      62,
      38,
      [
        DashboardWidget.clockWeather,
        DashboardWidget.media,
        DashboardWidget.speed,
        DashboardWidget.notifications,
      ],
    ),
    DashboardLayout.mapFocused => (
      72,
      28,
      [
        DashboardWidget.clockWeather,
        DashboardWidget.speed,
        DashboardWidget.media,
      ],
    ),
    DashboardLayout.mediaFocused => (
      45,
      55,
      [
        DashboardWidget.clockWeather,
        DashboardWidget.media,
        DashboardWidget.radio,
        DashboardWidget.speed,
      ],
    ),
    DashboardLayout.compact => (
      60,
      40,
      [
        DashboardWidget.clockWeather,
        DashboardWidget.media,
        DashboardWidget.speed,
      ],
    ),
  };
  return DashboardGeometry(
    dockOnLeft: !stacked,
    stacked: stacked,
    mapFlex: map,
    sideFlex: side,
    widgets: only(widgets),
  );
}

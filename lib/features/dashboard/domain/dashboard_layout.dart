import 'package:flutter/widgets.dart';

import '../../../core/storage/settings.dart';

enum DashboardWidget { notifications, media, radio, weather, speed }

class DashboardGeometry {
  const DashboardGeometry({
    required this.dockOnLeft,
    required this.stacked,
    required this.mapFlex,
    required this.sideFlex,
    required this.pagerBeside,
    required this.column,
    required this.pager,
  });

  /// Landscape screens put the dock on the left: vertical space is the scarce dimension on head units.
  final bool dockOnLeft;

  /// Portrait (phone testing): map above the information panel.
  final bool stacked;
  final int mapFlex;
  final int sideFlex;

  /// Wide screens give the pager its own column beside [column]; otherwise it fills the bottom of [column].
  final bool pagerBeside;

  /// Cards stacked top to bottom; the media card takes the remaining height.
  final List<DashboardWidget> column;

  /// Cards shown one at a time in the vertical pager.
  final List<DashboardWidget> pager;

  List<DashboardWidget> get widgets => [...column, ...pager];
}

/// Width of the rail including its margin; the layout decision uses what is left.
const railExtent = 92.0;

/// Below this side-panel width the pager shares the card column instead of getting its own.
const _minSideForTwoColumns = 560.0;

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
  final (map, side) = switch (layout) {
    DashboardLayout.balanced => (52, 48),
    DashboardLayout.mapFocused => (66, 34),
    DashboardLayout.mediaFocused => (40, 60),
    DashboardLayout.compact => (58, 42),
  };
  final sideWidth = (size.width - railExtent) * side / 100;
  final beside = !stacked && sideWidth >= _minSideForTwoColumns;

  bool shown(DashboardWidget w) =>
      (showSpeed || w != DashboardWidget.speed) &&
      (radioConfigured || w != DashboardWidget.radio);
  final column = beside
      ? [DashboardWidget.notifications, DashboardWidget.media]
      : [DashboardWidget.media];
  final pager = [
    DashboardWidget.weather,
    DashboardWidget.speed,
    if (!beside) DashboardWidget.notifications,
    DashboardWidget.radio,
  ];
  return DashboardGeometry(
    dockOnLeft: !stacked,
    stacked: stacked,
    mapFlex: map,
    sideFlex: side,
    pagerBeside: beside,
    column: column.where(shown).toList(),
    pager: pager.where(shown).toList(),
  );
}

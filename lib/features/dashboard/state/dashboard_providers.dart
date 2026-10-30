import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app drawer panel is shown in place of the dashboard cards.
final drawerOpenProvider = NotifierProvider<DrawerOpen, bool>(DrawerOpen.new);

class DrawerOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) => state = open;

  void toggle() => state = !state;
}

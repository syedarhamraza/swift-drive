import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_state.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/platform/platform_failure.dart';
import '../../../core/storage/settings.dart';
import '../../../core/storage/settings_providers.dart';
import '../data/apps_repository.dart';

final appsRepositoryProvider = Provider<AppsRepository>(
  (ref) => ChannelAppsRepository(),
);

final installedAppsProvider =
    AsyncNotifierProvider<InstalledAppsNotifier, List<AppInfo>>(
      InstalledAppsNotifier.new,
    );

class InstalledAppsNotifier extends AsyncNotifier<List<AppInfo>> {
  @override
  Future<List<AppInfo>> build() async {
    if (!ref.stageReached(2)) return const [];
    final repo = ref.watch(appsRepositoryProvider);
    Timer? debounce;
    final sub = repo.packageChanges().listen((pkg) {
      AppLog.i('apps', 'package changed: $pkg');
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 500), refresh);
    }, onError: (Object e) => AppLog.w('apps', 'package events failed: $e'));
    ref.onDispose(() {
      sub.cancel();
      debounce?.cancel();
    });
    return sortApps(await repo.getInstalledApps());
  }

  Future<void> refresh() async {
    final next = await AsyncValue.guard(
      () async =>
          sortApps(await ref.read(appsRepositoryProvider).getInstalledApps()),
    );
    if (ref.mounted) state = next;
  }
}

List<AppInfo> sortApps(List<AppInfo> apps) =>
    [...apps]
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

/// Drawer contents: search by label or package, hidden apps removed unless [showHidden], favourites first.
List<AppInfo> filterApps(
  List<AppInfo> apps, {
  String query = '',
  Set<String> hidden = const {},
  Set<String> favorites = const {},
  bool showHidden = false,
}) {
  final q = query.trim().toLowerCase();
  final result = apps.where((a) {
    if (!showHidden && hidden.contains(a.id)) return false;
    return q.isEmpty ||
        a.label.toLowerCase().contains(q) ||
        a.packageName.toLowerCase().contains(q);
  }).toList();
  if (favorites.isEmpty) return result;
  return [
    ...result.where((a) => favorites.contains(a.id)),
    ...result.where((a) => !favorites.contains(a.id)),
  ];
}

/// Finds a stored app id. Falls back to the same package if its launch activity changed.
AppInfo? findApp(List<AppInfo> apps, String id) {
  final exact = apps.where((a) => a.id == id).firstOrNull;
  if (exact != null) return exact;
  final (pkg, _) = parseAppId(id);
  return apps.where((a) => a.packageName == pkg).firstOrNull;
}

final appLauncherProvider = Provider<AppLauncher>(AppLauncher.new);

class AppLauncher {
  AppLauncher(this._ref);

  final Ref _ref;

  /// Returns null on success, otherwise the failure to show. Never throws.
  Future<PlatformFailure?> launch(String appId) async {
    try {
      await _ref.read(appsRepositoryProvider).launch(appId);
      return null;
    } on PlatformFailure catch (f) {
      AppLog.w('apps', 'launch failed for $appId: ${f.kind.name}');
      return f;
    }
  }

  /// The configured app for [role], or null when unset or no longer installed.
  AppInfo? shortcutApp(FactoryRole role) {
    final id = _ref.read(settingsProvider).shortcuts[role];
    final apps = _ref.read(installedAppsProvider).value;
    if (id == null || apps == null) return null;
    return findApp(apps, id);
  }

  Future<PlatformFailure?> openGeo(String uri, {String? packageName}) async {
    try {
      await _ref
          .read(appsRepositoryProvider)
          .openGeo(uri, packageName: packageName);
      return null;
    } on PlatformFailure catch (f) {
      return f;
    }
  }

  Future<PlatformFailure?> dial() async {
    try {
      await _ref.read(appsRepositoryProvider).dial();
      return null;
    } on PlatformFailure catch (f) {
      return f;
    }
  }
}

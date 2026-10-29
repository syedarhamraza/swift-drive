import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_failure.dart';
import '../../../core/storage/settings.dart';
import '../../apps/state/apps_providers.dart';

class CallInfo {
  const CallInfo({required this.state, this.displayName});

  final String state;
  final String? displayName;
}

/// Integration point for calling. A verified head-unit adapter may later provide call state and
/// controls; the generic one only opens the user's phone app (or the system dialer).
abstract interface class CallingAdapter {
  /// Supported optional features. The generic adapter supports none of them.
  bool get supportsCallState;
  bool get supportsCallActions;

  /// null = unsupported. A custom incoming-call UI is only shown when this is non-null.
  Stream<CallInfo>? get callStates;

  Future<PlatformFailure?> openCallingApp();
  Future<PlatformFailure?> answer();
  Future<PlatformFailure?> hangUp();
}

class GenericCallingAdapter implements CallingAdapter {
  GenericCallingAdapter(this._launcher);

  final AppLauncher _launcher;

  @override
  bool get supportsCallState => false;
  @override
  bool get supportsCallActions => false;
  @override
  Stream<CallInfo>? get callStates => null;

  @override
  Future<PlatformFailure?> openCallingApp() {
    final app = _launcher.shortcutApp(FactoryRole.phone);
    return app != null ? _launcher.launch(app.id) : _launcher.dial();
  }

  @override
  Future<PlatformFailure?> answer() async =>
      const PlatformFailure(FailureKind.unsupported, 'call control');
  @override
  Future<PlatformFailure?> hangUp() async =>
      const PlatformFailure(FailureKind.unsupported, 'call control');
}

final callingAdapterProvider = Provider<CallingAdapter>(
  (ref) => GenericCallingAdapter(ref.watch(appLauncherProvider)),
);

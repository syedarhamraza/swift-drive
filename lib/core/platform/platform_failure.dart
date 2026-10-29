import 'dart:async';

import 'package:flutter/services.dart';

import '../logging/app_log.dart';

enum FailureKind {
  permissionDenied,
  unsupported,
  serviceUnavailable,
  activityMissing,
  timeout,
  security,
  unexpected,
}

/// Typed error for every native call. Repositories throw only this, so the UI can show a precise state.
class PlatformFailure implements Exception {
  const PlatformFailure(this.kind, [this.message = '']);

  final FailureKind kind;
  final String message;

  /// Maps the error codes produced by the Kotlin side (see ChannelUtil.kt) to [FailureKind].
  static FailureKind kindForCode(String code) => switch (code) {
    'PERMISSION_DENIED' => FailureKind.permissionDenied,
    'UNSUPPORTED' => FailureKind.unsupported,
    'SERVICE_UNAVAILABLE' => FailureKind.serviceUnavailable,
    'ACTIVITY_NOT_FOUND' => FailureKind.activityMissing,
    'SECURITY' => FailureKind.security,
    'TIMEOUT' => FailureKind.timeout,
    _ => FailureKind.unexpected,
  };

  String get userMessage => switch (kind) {
    FailureKind.permissionDenied => 'Permission required',
    FailureKind.unsupported => 'Not supported on this device',
    FailureKind.serviceUnavailable => 'Service unavailable',
    FailureKind.activityMissing => 'App not installed or cannot be opened',
    FailureKind.timeout => 'Timed out',
    FailureKind.security => 'Blocked by the system',
    FailureKind.unexpected => 'Something went wrong',
  };

  @override
  String toString() => 'PlatformFailure($kind, $message)';
}

/// Runs a native call, converting every platform error into a [PlatformFailure] and logging it.
Future<T> guardPlatform<T>(
  String tag,
  Future<T> Function() call, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    return await call().timeout(timeout);
  } on PlatformException catch (e) {
    final failure = PlatformFailure(
      PlatformFailure.kindForCode(e.code),
      e.message ?? '',
    );
    AppLog.w(tag, 'native error ${e.code}: ${e.message}');
    throw failure;
  } on MissingPluginException {
    AppLog.e(tag, 'channel not implemented');
    throw const PlatformFailure(FailureKind.unsupported, 'channel missing');
  } on TimeoutException {
    AppLog.w(tag, 'native call timed out');
    throw const PlatformFailure(FailureKind.timeout);
  }
}

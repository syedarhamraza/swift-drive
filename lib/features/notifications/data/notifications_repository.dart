import 'package:flutter/services.dart';

import '../../../core/platform/platform_failure.dart';

class NotificationItem {
  const NotificationItem({
    required this.key,
    required this.packageName,
    required this.appLabel,
    required this.postTime,
    required this.clearable,
    this.title,
    this.text,
    this.category,
    this.importance,
    this.hidden = false,
  });

  factory NotificationItem.fromMap(Map<Object?, Object?> m) => NotificationItem(
    key: m['key']! as String,
    packageName: m['packageName']! as String,
    appLabel: m['appLabel'] as String? ?? m['packageName']! as String,
    title: m['title'] as String?,
    text: m['text'] as String?,
    postTime: DateTime.fromMillisecondsSinceEpoch(
      (m['postTime'] as num? ?? 0).toInt(),
    ),
    clearable: m['clearable'] as bool? ?? false,
    category: m['category'] as String?,
    importance: m['importance'] as int?,
    hidden: m['hidden'] as bool? ?? false,
  );

  final String key;
  final String packageName;
  final String appLabel;
  final String? title;
  final String? text;
  final DateTime postTime;
  final bool clearable;
  final String? category;
  final int? importance;

  /// The app marked it private and the user has not chosen to show private content.
  final bool hidden;

  /// What to show and read: the text, or a note that the app hid it.
  String? get body =>
      text ?? (hidden ? 'Private notification, content hidden' : null);
}

/// Android NotificationManager.IMPORTANCE_DEFAULT.
const _importanceDefault = 3;
const _nonEssentialCategories = {
  'promo',
  'recommendation',
  'status',
  'sys',
  'service',
  'progress',
  'social',
  'event',
};

/// Essential = default importance or higher and not a promotional/system/background category.
bool isEssentialNotification(NotificationItem n) =>
    (n.importance == null || n.importance! >= _importanceDefault) &&
    !_nonEssentialCategories.contains(n.category);

abstract interface class NotificationsRepository {
  Future<bool> hasAccess();

  /// [showPrivate] includes the content of notifications their app marked private.
  Stream<List<NotificationItem>> notifications({bool showPrivate = false});
  Future<void> dismiss(String key);
}

class ChannelNotificationsRepository implements NotificationsRepository {
  static const _channel = MethodChannel('swiftdrive/notifications');
  static const _events = EventChannel('swiftdrive/notifications/events');

  @override
  Future<bool> hasAccess() => guardPlatform(
    'notifications',
    () async => await _channel.invokeMethod<bool>('hasAccess') ?? false,
  );

  @override
  Stream<List<NotificationItem>> notifications({bool showPrivate = false}) =>
      _events
          .receiveBroadcastStream({'showPrivate': showPrivate})
          .map(
            (e) => (e as List)
                .cast<Map<Object?, Object?>>()
                .map(NotificationItem.fromMap)
                .toList(),
          );

  @override
  Future<void> dismiss(String key) => guardPlatform(
    'notifications',
    () => _channel.invokeMethod('dismiss', {'key': key}),
  );
}

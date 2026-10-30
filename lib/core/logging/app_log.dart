import 'dart:collection';

import 'package:flutter/foundation.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  LogEntry(this.level, this.tag, this.message) : time = DateTime.now();

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  Map<String, Object> toJson() => {
    'time': time.toIso8601String(),
    'level': level.name,
    'tag': tag,
    'message': message,
  };
}

/// In-memory structured log (ring buffer). Never log precise coordinates or notification contents here.
abstract final class AppLog {
  static const capacity = 500;
  static final _entries = ListQueue<LogEntry>(capacity);

  static List<LogEntry> get entries => List.unmodifiable(_entries);

  static void i(String tag, String message) =>
      _add(LogLevel.info, tag, message);
  static void w(String tag, String message) =>
      _add(LogLevel.warning, tag, message);
  static void e(String tag, String message) =>
      _add(LogLevel.error, tag, message);

  static void _add(LogLevel level, String tag, String message) {
    if (_entries.length == capacity) _entries.removeFirst();
    _entries.add(LogEntry(level, tag, message));
    if (!kReleaseMode) debugPrint('[${level.name}] $tag: $message');
  }

  static void clear() => _entries.clear();
}

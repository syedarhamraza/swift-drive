import 'package:intl/intl.dart';

import 'storage/settings.dart';

String formatDistance(double meters, SpeedUnit unit) {
  if (unit == SpeedUnit.mph) {
    final miles = meters / 1609.344;
    if (miles < 0.1) return '${(meters * 3.28084 / 10).round() * 10} ft';
    return miles < 10
        ? '${miles.toStringAsFixed(1)} mi'
        : '${miles.round()} mi';
  }
  if (meters < 1000) return '${(meters / 10).round() * 10} m';
  return meters < 10000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${(meters / 1000).round()} km';
}

String formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60} h ${minutes % 60} min';
}

String formatClock(DateTime t, {required bool use24h}) =>
    DateFormat(use24h ? 'HH:mm' : 'h:mm a').format(t);

/// "just now", "5 min ago", "3 h ago", or a date for older values.
String formatAge(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return DateFormat.MMMd().format(then);
}

String formatTemperature(double celsius, TempUnit unit) =>
    unit == TempUnit.celsius
    ? '${celsius.round()}°C'
    : '${(celsius * 9 / 5 + 32).round()}°F';

/// Temperature without the unit letter, for forecast rows where the unit is already clear.
String formatDegrees(double celsius, TempUnit unit) =>
    '${(unit == TempUnit.celsius ? celsius : celsius * 9 / 5 + 32).round()}°';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/storage/settings_providers.dart';

/// Self-contained clock: only this widget rebuilds, once per minute, aligned to the minute boundary.
/// It re-syncs on resume, so time-zone or manual clock changes show up immediately.
class ClockText extends ConsumerStatefulWidget {
  const ClockText({super.key, this.large = true, this.compact = false});

  final bool large;

  /// Time only, centred and scaled to fit (the rail).
  final bool compact;

  @override
  ConsumerState<ClockText> createState() => _ClockTextState();
}

class _ClockTextState extends ConsumerState<ClockText>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _now = DateTime.now());
      _schedule();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final use24h = ref.watch(settingsProvider.select((s) => s.use24h));
    final t = Theme.of(context).textTheme;
    if (widget.compact) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        // No AM/PM on the narrow rail, as on car displays.
        child: Text(
          DateFormat(use24h ? 'HH:mm' : 'h:mm').format(_now),
          style: t.titleMedium,
          maxLines: 1,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatClock(_now, use24h: use24h),
            style: widget.large ? t.displayMedium : t.headlineMedium,
          ),
        ),
        Text(DateFormat.MMMEd().format(_now), style: t.bodyMedium),
      ],
    );
  }
}

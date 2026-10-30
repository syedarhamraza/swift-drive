import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/perf/perf_metrics.dart';
import '../../../core/platform/platform_failure.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../launcher/state/launcher_providers.dart';
import '../../media/state/media_providers.dart';
import '../data/device_repository.dart';
import '../state/diagnostics_providers.dart';

(IconData, Color?) statusVisual(CapabilityStatus s) => switch (s) {
  CapabilityStatus.available => (Icons.check_circle, SdColors.success),
  CapabilityStatus.permissionRequired => (Icons.lock_outline, SdColors.warning),
  CapabilityStatus.unavailable => (Icons.remove_circle_outline, null),
  CapabilityStatus.unsupported => (Icons.block, null),
  CapabilityStatus.unknown => (Icons.help_outline, null),
  CapabilityStatus.error => (Icons.error_outline, SdColors.danger),
};

String statusLabel(CapabilityStatus s) => switch (s) {
  CapabilityStatus.available => 'Available',
  CapabilityStatus.permissionRequired => 'Permission required',
  CapabilityStatus.unavailable => 'Unavailable',
  CapabilityStatus.unsupported => 'Not supported',
  CapabilityStatus.unknown => 'Unknown / not verified',
  CapabilityStatus.error => 'Error',
};

class CapabilityList extends StatelessWidget {
  const CapabilityList({super.key, required this.report});

  final DeviceReport report;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final c in report.capabilities)
        Builder(
          builder: (context) {
            final (icon, color) = statusVisual(c.status);
            return ListTile(
              leading: Icon(icon, color: color),
              title: Text(c.label),
              subtitle: Text(
                c.detail.isEmpty
                    ? statusLabel(c.status)
                    : '${statusLabel(c.status)} · ${c.detail}',
              ),
            );
          },
        ),
    ],
  );
}

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  static const route = '/settings/diagnostics';

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  bool _includeExtra = false;

  Future<void> _export(String fileName, Object content) async {
    try {
      final ok = await ref
          .read(launcherRepositoryProvider)
          .exportFile(
            fileName,
            const JsonEncoder.withIndent('  ').convert(content),
          );
      if (mounted) {
        showMessage(context, ok ? 'Saved $fileName' : 'Export cancelled');
      }
    } on PlatformFailure catch (f) {
      if (mounted) showFailure(context, f, what: 'Export');
    }
  }

  Future<void> _exportReport() async {
    try {
      final report = await ref
          .read(deviceRepositoryProvider)
          .getReport(extra: _includeExtra);
      await _export('swiftdrive-compatibility.json', {
        'generatedAt': DateTime.now().toIso8601String(),
        'adapter': report.adapterName,
        'device': report.device,
        'capabilities': [for (final c in report.capabilities) c.toJson()],
        if (report.extra != null) 'extra': report.extra,
      });
    } on PlatformFailure catch (f) {
      if (mounted) showFailure(context, f, what: 'Report');
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(deviceReportProvider);
    final t = Theme.of(context).textTheme;
    final logs = AppLog.entries.reversed.take(100).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(deviceReportProvider),
          ),
        ],
      ),
      body: ListView(
        children: [
          report.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(SdSpace.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const ListTile(
              leading: Icon(Icons.error_outline),
              title: Text('Diagnostics unavailable'),
            ),
            data: (r) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(
                    '${r.device['manufacturer']} ${r.device['model']}',
                    style: t.titleMedium,
                  ),
                  subtitle: Text(
                    'Android ${r.device['release']} (API ${r.device['sdkInt']}) · ${r.device['displayWidthPx']}×${r.device['displayHeightPx']} px · '
                    '${r.device['densityDpi']} dpi · RAM ${r.device['totalMemMb']} MB · ABIs ${(r.device['abis'] as List?)?.join(', ')} · '
                    'Profile: ${r.adapterName}',
                  ),
                ),
                CapabilityList(report: r),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Include extra details in export'),
            subtitle: const Text(
              'Build fingerprint and installed launcher-visible package names. Off by default.',
            ),
            value: _includeExtra,
            onChanged: (v) => setState(() => _includeExtra = v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SdSpace.lg),
            child: Wrap(
              spacing: SdSpace.md,
              runSpacing: SdSpace.sm,
              children: [
                FilledButton.icon(
                  onPressed: _exportReport,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Export report (JSON)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _export('swiftdrive-log.json', [
                    for (final e in AppLog.entries) e.toJson(),
                  ]),
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('Export log'),
                ),
              ],
            ),
          ),
          if (!kReleaseMode) _DebugMetrics(),
          const Divider(),
          ListTile(
            title: Text(
              'Log (newest first, ${AppLog.entries.length} entries)',
              style: t.titleMedium,
            ),
          ),
          for (final e in logs)
            ListTile(
              dense: true,
              leading: Icon(switch (e.level) {
                LogLevel.info => Icons.info_outline,
                LogLevel.warning => Icons.warning_amber_rounded,
                LogLevel.error => Icons.error_outline,
              }, size: 20),
              title: Text('${e.tag}: ${e.message}'),
              subtitle: Text(e.time.toIso8601String()),
            ),
        ],
      ),
    );
  }
}

class _DebugMetrics extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (frames, build, raster, slow) = PerfMetrics.summary();
    final sessions = ref.watch(mediaProvider.select((m) => m.sessions.length));
    return ListTile(
      leading: const Icon(Icons.speed),
      title: const Text('Debug metrics (not in release builds)'),
      subtitle: Text(
        'Last $frames frames: build ${build.toStringAsFixed(1)} ms, raster ${raster.toStringAsFixed(1)} ms, $slow over 16 ms\n'
        'First frame: ${PerfMetrics.firstFrameTime?.inMilliseconds ?? '–'} ms · '
        'Map style load: ${PerfMetrics.mapInitTime?.inMilliseconds ?? '–'} ms · Media sessions: $sessions\n'
        'Frames per 10 s (oldest first): ${PerfMetrics.framesPer10s.join(', ')}',
      ),
    );
  }
}

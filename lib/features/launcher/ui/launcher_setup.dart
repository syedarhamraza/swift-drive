import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_failure.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../state/launcher_providers.dart';

/// Default-launcher status, the (optional) request, and recovery back to the factory launcher.
class LauncherSetupSection extends ConsumerWidget {
  const LauncherSetupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(homeStatusProvider);
    final repo = ref.read(launcherRepositoryProvider);
    final t = Theme.of(context).textTheme;

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } on PlatformFailure catch (f) {
        if (context.mounted) showFailure(context, f);
      }
      ref.invalidate(homeStatusProvider);
    }

    return status.when(
      loading: () => const ListTile(title: Text('Checking launcher status…')),
      error: (e, _) => const ListTile(
        leading: Icon(Icons.error_outline),
        title: Text('Launcher status unavailable'),
      ),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(
              s.isDefault ? Icons.check_circle : Icons.home_outlined,
              color: s.isDefault ? SdColors.success : null,
            ),
            title: Text(
              s.isDefault
                  ? 'SwiftDrive is the default launcher'
                  : 'SwiftDrive is running as a normal app',
            ),
            subtitle: Text(
              s.isDefault ? 'The Home button opens SwiftDrive.' : 'Setting it as default is optional. Everything also works as a normal app.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SdSpace.lg),
            child: Wrap(
              spacing: SdSpace.md,
              runSpacing: SdSpace.sm,
              children: [
                if (!s.isDefault)
                  FilledButton(
                    onPressed: () => run(repo.requestHomeRole),
                    child: const Text('Set as default launcher'),
                  ),
                OutlinedButton(
                  onPressed: () => run(repo.openHomeSettings),
                  child: const Text('Open Home app settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: SdSpace.md),
          ListTile(
            title: Text('Return to the factory launcher', style: t.titleMedium),
          ),
          if (s.otherHomes.isEmpty)
            const ListTile(
              subtitle: Text('No other launcher was found on this device.'),
            )
          else
            for (final h in s.otherHomes)
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: Text('Open ${h.label}'),
                subtitle: Text(h.packageName),
                onTap: () => run(() => repo.launchHome(h)),
              ),
          const Padding(
            padding: EdgeInsets.fromLTRB(SdSpace.lg, 0, SdSpace.lg, SdSpace.md),
            child: Text(
              'To stop using SwiftDrive as the launcher: tap "Open Home app settings" and choose the original launcher, '
              'or open Android Settings › Apps › SwiftDrive › "Open by default" / "Home app" and clear the default. '
              'Uninstalling SwiftDrive also restores the previous launcher. SwiftDrive never disables or modifies factory apps.',
            ),
          ),
        ],
      ),
    );
  }
}

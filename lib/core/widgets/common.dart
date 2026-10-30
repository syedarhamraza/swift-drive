import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../platform/platform_failure.dart';
import '../theme/tokens.dart';

/// Rounded dashboard card with consistent padding.
class SdCard extends StatelessWidget {
  const SdCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SdSpace.lg),
    this.onTap,
    this.color,
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Defaults to the theme's card colour.
  final Color? color;

  /// Painted over [color]; static, so it costs nothing after the first frame.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(gradient: gradient),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding + EdgeInsets.only(right: CardEndInset.of(context)),
          child: child,
        ),
      ),
    ),
  );
}

/// Extra right padding for [SdCard]s below it, where something overlays the cards' right edge (the
/// pager dots).
class CardEndInset extends InheritedWidget {
  const CardEndInset({super.key, required this.width, required super.child});

  final double width;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardEndInset>()?.width ?? 0;

  @override
  bool updateShouldNotify(CardEndInset old) => width != old.width;
}

/// Light text and icons for content on artwork or a dark gradient, whatever the app theme is.
ThemeData onDarkBackdrop(ThemeData theme) => theme.copyWith(
  colorScheme: theme.colorScheme.copyWith(
    onSurface: Colors.white,
    onSurfaceVariant: Colors.white70,
  ),
  textTheme: theme.textTheme.apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
  iconTheme: theme.iconTheme.copyWith(color: Colors.white),
);

/// Explicit state for missing data/permissions: what is wrong and, when possible, how to fix it.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.dense = false,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: dense ? 28 : 40, color: scheme.onSurfaceVariant),
        const SizedBox(height: SdSpace.sm),
        Text(
          title,
          style: dense ? t.titleSmall : t.titleMedium,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (body != null) ...[
          const SizedBox(height: SdSpace.xs),
          Text(
            body!,
            style: t.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: SdSpace.md),
          FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

/// Round app icon, decoded at display size to keep the image cache small.
class AppIconImage extends StatelessWidget {
  const AppIconImage(this.bytes, {super.key, this.size = 48});

  final Uint8List? bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = bytes;
    if (b == null) return Icon(Icons.android, size: size);
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipOval(
      child: Image.memory(
        b,
        width: size,
        height: size,
        cacheWidth: px,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

void showFailure(
  BuildContext context,
  PlatformFailure? failure, {
  String? what,
  SnackBarAction? action,
}) {
  if (failure == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          what == null ? failure.userMessage : '$what: ${failure.userMessage}',
        ),
        action: action,
      ),
    );
}

void showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

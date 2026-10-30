import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildTheme(
  Brightness brightness,
  Color accent, {
  required bool reduceMotion,
}) {
  final dark = brightness == Brightness.dark;
  final background = dark ? SdColors.darkBackground : SdColors.lightBackground;
  final surface = dark ? SdColors.darkSurface : SdColors.lightSurface;
  final elevated = dark ? SdColors.darkElevated : SdColors.lightElevated;
  final textPrimary = dark
      ? SdColors.darkTextPrimary
      : SdColors.lightTextPrimary;
  final textSecondary = dark
      ? SdColors.darkTextSecondary
      : SdColors.lightTextSecondary;
  // Tonal roles (pastel pills and containers) come from the accent; surfaces stay our near-neutral palette
  // so the dashboard is dark enough for night driving.
  final seeded = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
  );

  final scheme = seeded.copyWith(
    // Tonal buttons use the secondary container: keep them neutral, like secondary actions in a car UI.
    secondaryContainer: elevated,
    onSecondaryContainer: textPrimary,
    error: SdColors.danger,
    onError: SdColors.darkBackground,
    surface: surface,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    surfaceContainerHighest: elevated,
    surfaceContainerHigh: elevated,
    surfaceContainer: surface,
    surfaceContainerLow: surface,
    surfaceContainerLowest: background,
    outline: textSecondary.withValues(alpha: 0.4),
    outlineVariant: textSecondary.withValues(alpha: 0.2),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
  );
  final text = base.textTheme.apply(
    bodyColor: textPrimary,
    displayColor: textPrimary,
  );

  return base.copyWith(
    scaffoldBackgroundColor: background,
    canvasColor: background,
    textTheme: text.copyWith(
      // Automotive hierarchy: big clock/speed, readable titles, no tiny actionable text.
      displayLarge: text.displayLarge?.copyWith(
        fontWeight: FontWeight.w300,
        letterSpacing: -1,
      ),
      displayMedium: text.displayMedium?.copyWith(fontWeight: FontWeight.w400),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 18),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 16, color: textSecondary),
      bodySmall: text.bodySmall?.copyWith(fontSize: 14, color: textSecondary),
      labelLarge: text.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SdRadius.card),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: surface),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 12,
      minTileHeight: SdSize.driveTarget,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SdRadius.button),
      ),
    ),
    // Pill buttons everywhere (Material 3's default stadium shape), at least one touch target tall.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(SdSize.minTarget, SdSize.minTarget),
        padding: const EdgeInsets.symmetric(horizontal: SdSpace.xl),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(SdSize.minTarget, SdSize.minTarget),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: StadiumBorder(),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SdRadius.card),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(SdSize.minTarget, SdSize.minTarget),
      ),
    ),
    pageTransitionsTheme: reduceMotion
        ? const PageTransitionsTheme(
            builders: {TargetPlatform.android: _NoTransitionBuilder()},
          )
        : const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            },
          ),
  );
}

class _NoTransitionBuilder extends PageTransitionsBuilder {
  const _NoTransitionBuilder();

  @override
  Widget buildTransitions<T>(_, _, _, _, Widget child) => child;
}

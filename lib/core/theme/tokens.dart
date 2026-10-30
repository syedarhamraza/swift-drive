import 'package:flutter/material.dart';

/// Central design tokens. Every colour, radius and spacing value in the UI comes from here.
abstract final class SdColors {
  // Dark palette (default).
  static const darkBackground = Color(0xFF101114);
  static const darkSurface = Color(0xFF1B1D21);
  static const darkElevated = Color(0xFF25282E);
  static const darkTextPrimary = Color(0xFFF4F5F7);
  static const darkTextSecondary = Color(0xFFADB2BA);

  // Light palette.
  static const lightBackground = Color(0xFFEEF0F3);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightElevated = Color(0xFFE3E6EB);
  static const lightTextPrimary = Color(0xFF15171A);
  static const lightTextSecondary = Color(0xFF555B64);

  static const success = Color(0xFF6DD6A1);
  static const warning = Color(0xFFF2BF69);
  static const danger = Color(0xFFFF8A80);

  /// Maneuver card: a fixed, high-contrast green so turn guidance reads the same in every theme.
  static const navGreen = Color(0xFF1F6E4A);

  /// Remaining-time text in the ETA pill.
  static const etaGreen = Color(0xFF7BE0A4);

  /// User-selectable accents. The first one is the default.
  static const accents = <Color>[
    Color(0xFF82B4FF), // Sky
    Color(0xFF6DD6A1), // Mint
    Color(0xFFF2BF69), // Amber
    Color(0xFFFF9E80), // Coral
    Color(0xFFC3A6FF), // Lavender
  ];
}

abstract final class SdSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

abstract final class SdRadius {
  static const card = 28.0;
  static const rail = 32.0;
  static const button = 20.0;
}

abstract final class SdSize {
  /// Minimum touch target. Frequent driving actions use [driveTarget].
  static const minTarget = 48.0;
  static const driveTarget = 64.0;
}

/// Motion is event-driven only: short transitions when something changes, nothing that loops.
abstract final class SdMotion {
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const long = Duration(milliseconds: 350);
  static const curve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;

  /// [d], or zero when animations are off (performance mode or the system "remove animations" setting).
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

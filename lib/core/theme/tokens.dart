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
  static const card = 20.0;
  static const button = 16.0;
}

abstract final class SdSize {
  /// Minimum touch target. Frequent driving actions use [driveTarget].
  static const minTarget = 48.0;
  static const driveTarget = 64.0;
}

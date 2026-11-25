import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Centralised Memoria design tokens. Every colour, spacing, radius, opacity,
/// shadow, duration and easing curve used by the interface lives here.
abstract final class MemoriaColors {
  static const deepSpace = Color(0xFF09191D);
  static const midnightTeal = Color(0xFF10282B);
  static const atmosphere = Color(0xFF254448);
  static const mutedTeal = Color(0xFF547779);
  static const celestialMist = Color(0xFF8FA8A6);
  static const softSage = Color(0xFFC4D0C9);
  static const warmIvory = Color(0xFFEEEDE5);
  static const memoryGlow = Color(0xFFE5C5AE);
  static const blush = Color(0xFFD6A39F);

  /// Text on dark atmospheric surfaces.
  static const textPrimary = warmIvory;
  static const textSecondary = Color(0xCCC4D0C9);
  static const textTertiary = Color(0x998FA8A6);

  /// Ink used on the ivory primary button.
  static const inkOnIvory = Color(0xFF1B3336);
}

abstract final class MemoriaSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double screenH = 24;
}

abstract final class MemoriaRadii {
  static const double sm = 14;
  static const double md = 22;
  static const double lg = 28;
  static const double xl = 36;
  static const double pill = 999;
}

abstract final class MemoriaOpacity {
  static const double glassFill = 0.10;
  static const double glassFillStrong = 0.16;
  static const double glassBorder = 0.18;
  static const double scrim = 0.55;
  static const double disabled = 0.38;
}

abstract final class MemoriaShadows {
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x66050F12), blurRadius: 30, offset: Offset(0, 14)),
  ];
  static const List<BoxShadow> glow = [
    BoxShadow(color: Color(0x40E5C5AE), blurRadius: 36, spreadRadius: -6),
  ];
}

abstract final class MemoriaBlur {
  static const double glass = 22;
  static const double sheet = 28;
}

abstract final class MemoriaDurations {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 420);
  static const slow = Duration(milliseconds: 800);
  static const cinematic = Duration(milliseconds: 1600);
  static const reveal = Duration(milliseconds: 5200);
  static const cameraFocus = Duration(milliseconds: 1400);
}

abstract final class MemoriaCurves {
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve gentle = Cubic(0.33, 0.0, 0.12, 1.0);
  static const Curve cinematic = Cubic(0.65, 0.0, 0.18, 1.0);
  static const Curve exit = Cubic(0.4, 0.0, 1.0, 1.0);
}

/// Minimum interactive target (Material/Android accessibility guidance).
const double kMinTouchTarget = 48;

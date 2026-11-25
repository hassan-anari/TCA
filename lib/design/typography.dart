import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Editorial typography. Cormorant Garamond for display / titles / years,
/// DM Sans for interface and reading text. Fonts are bundled locally.
abstract final class MemoriaType {
  static const display = 'Cormorant Garamond';
  static const ui = 'DM Sans';

  static TextStyle displayL(BuildContext c) => _scaled(
    c,
    const TextStyle(
      fontFamily: display,
      fontSize: 46,
      fontWeight: FontWeight.w500,
      height: 1.05,
      letterSpacing: -0.4,
      color: MemoriaColors.textPrimary,
    ),
  );

  static TextStyle headingL(BuildContext c) => _scaled(
    c,
    const TextStyle(
      fontFamily: display,
      fontSize: 34,
      fontWeight: FontWeight.w500,
      height: 1.1,
      color: MemoriaColors.textPrimary,
    ),
  );

  static TextStyle headingM(BuildContext c) => _scaled(
    c,
    const TextStyle(
      fontFamily: display,
      fontSize: 26,
      fontWeight: FontWeight.w500,
      height: 1.15,
      color: MemoriaColors.textPrimary,
    ),
  );

  static TextStyle year(BuildContext c) => _scaled(
    c,
    const TextStyle(
      fontFamily: display,
      fontSize: 30,
      fontWeight: FontWeight.w400,
      letterSpacing: 1.2,
      color: MemoriaColors.textPrimary,
    ),
  );

  static TextStyle body(BuildContext c) => const TextStyle(
    fontFamily: ui,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: MemoriaColors.textPrimary,
  );

  static TextStyle reading(BuildContext c) => const TextStyle(
    fontFamily: ui,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.75,
    letterSpacing: 0.1,
    color: Color(0xF2EEEDE5),
  );

  static TextStyle button(BuildContext c) => const TextStyle(
    fontFamily: ui,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: MemoriaColors.inkOnIvory,
  );

  static TextStyle label(BuildContext c) => const TextStyle(
    fontFamily: ui,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: MemoriaColors.textPrimary,
  );

  static TextStyle meta(BuildContext c) => const TextStyle(
    fontFamily: ui,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: MemoriaColors.textSecondary,
  );

  /// Wide-tracked uppercase eyebrow ("A SHARED MEMORY PLANET").
  static TextStyle eyebrow(BuildContext c) => const TextStyle(
    fontFamily: ui,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 4.2,
    color: MemoriaColors.textSecondary,
  );

  /// Display sizes shrink slightly on narrow viewports so titles keep one line.
  static TextStyle _scaled(BuildContext c, TextStyle s) {
    final w = MediaQuery.maybeSizeOf(c)?.width ?? 400;
    final f = w < 360 ? 0.86 : (w > 600 ? 1.1 : 1.0);
    return s.copyWith(fontSize: s.fontSize! * f);
  }
}

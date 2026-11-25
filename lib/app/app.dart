import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../scene/scene_viewport.dart';
import 'router.dart';

/// Root widget: the persistent 3D [SceneViewport] sits beneath a transparent
/// navigator whose pages are the floating interface of each spatial level.
class MemoriaApp extends StatefulWidget {
  const MemoriaApp({super.key, this.router});
  final GoRouter? router;

  @override
  State<MemoriaApp> createState() => _MemoriaAppState();
}

class _MemoriaAppState extends State<MemoriaApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Memoria',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: memoriaTheme(),
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [const SceneViewport(), ?child],
      ),
    );
  }
}

/// Only interaction primitives come from Material; every visible surface is
/// drawn by the Memoria design system.
ThemeData memoriaTheme() {
  const scheme = ColorScheme.dark(
    primary: MemoriaColors.memoryGlow,
    onPrimary: MemoriaColors.inkOnIvory,
    secondary: MemoriaColors.blush,
    surface: MemoriaColors.midnightTeal,
    onSurface: MemoriaColors.warmIvory,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: MemoriaType.ui,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: MemoriaColors.memoryGlow,
      selectionColor: Color(0x55E5C5AE),
      selectionHandleColor: MemoriaColors.memoryGlow,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Caches compiled fragment programs; falls back gracefully when shaders are
/// unavailable (e.g. some test environments).
class ShaderLibrary {
  ShaderLibrary._();
  static final Map<String, Future<ui.FragmentProgram?>> _cache = {};

  static Future<ui.FragmentProgram?> load(String asset) {
    return _cache.putIfAbsent(asset, () async {
      try {
        return await ui.FragmentProgram.fromAsset(asset);
      } catch (_) {
        return null;
      }
    });
  }
}

/// Slowly drifting painterly nebula (fragment shader) used behind 2D-heavy
/// screens. [animate] can be disabled for reduced motion or to save power.
class AtmosphericBackground extends StatefulWidget {
  const AtmosphericBackground({
    super.key,
    this.warmth = 0.6,
    this.animate = true,
    this.opacity = 1,
  });

  final double warmth;
  final bool animate;
  final double opacity;

  @override
  State<AtmosphericBackground> createState() => _AtmosphericBackgroundState();
}

class _AtmosphericBackgroundState extends State<AtmosphericBackground>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => setState(() => _t = d.inMicroseconds / 1e6));
    ShaderLibrary.load('shaders/nebula.frag').then((p) {
      if (!mounted) return;
      setState(() => _program = p);
      if (widget.animate && p != null) _ticker.start();
    });
  }

  @override
  void didUpdateWidget(covariant AtmosphericBackground old) {
    super.didUpdateWidget(old);
    if (widget.animate && _program != null && !_ticker.isActive) {
      _ticker.start();
    }
    if (!widget.animate && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _program;
    final Widget child = p == null
        ? const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.3, 0.6),
                radius: 1.3,
                colors: [
                  MemoriaColors.atmosphere,
                  MemoriaColors.midnightTeal,
                  MemoriaColors.deepSpace,
                ],
              ),
            ),
          )
        : CustomPaint(painter: _NebulaPainter(p, _t, widget.warmth));
    return Opacity(
      opacity: widget.opacity,
      child: SizedBox.expand(child: child),
    );
  }
}

class _NebulaPainter extends CustomPainter {
  _NebulaPainter(this.program, this.t, this.warmth);
  final ui.FragmentProgram program;
  final double t;
  final double warmth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = program.fragmentShader();
    var i = 0;
    void color(Color c) {
      s.setFloat(i++, c.r);
      s.setFloat(i++, c.g);
      s.setFloat(i++, c.b);
      s.setFloat(i++, 1);
    }

    s.setFloat(i++, size.width);
    s.setFloat(i++, size.height);
    s.setFloat(i++, t);
    color(MemoriaColors.deepSpace);
    color(MemoriaColors.mutedTeal);
    color(MemoriaColors.memoryGlow);
    s.setFloat(i++, warmth);
    canvas.drawRect(Offset.zero & size, Paint()..shader = s);
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter old) =>
      old.t != t || old.warmth != warmth;
}

/// Fine cinematic grain + vignette overlay. Never intercepts touches.
class GrainOverlay extends StatefulWidget {
  const GrainOverlay({
    super.key,
    this.grain = 0.07,
    this.vignette = 0.55,
    this.animate = true,
  });

  final double grain;
  final double vignette;
  final bool animate;

  @override
  State<GrainOverlay> createState() => _GrainOverlayState();
}

class _GrainOverlayState extends State<GrainOverlay>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  late final Ticker _ticker;
  double _t = 0;
  int _lastFrame = -1;

  @override
  void initState() {
    super.initState();
    // Grain only needs ~12 distinct frames per second.
    _ticker = createTicker((d) {
      final f = (d.inMilliseconds / 83).floor();
      if (f != _lastFrame) {
        _lastFrame = f;
        setState(() => _t = d.inMicroseconds / 1e6);
      }
    });
    ShaderLibrary.load('shaders/grain.frag').then((p) {
      if (!mounted) return;
      setState(() => _program = p);
      if (widget.animate && p != null) _ticker.start();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _program;
    if (p == null) {
      return const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.1,
              colors: [Color(0x00000000), Color(0x00000000), Color(0x8C050F12)],
              stops: [0, 0.6, 1],
            ),
          ),
          child: SizedBox.expand(),
        ),
      );
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _GrainPainter(p, _t, widget.grain, widget.vignette),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.program, this.t, this.grain, this.vignette);
  final ui.FragmentProgram program;
  final double t;
  final double grain;
  final double vignette;

  @override
  void paint(Canvas canvas, Size size) {
    final s = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, t)
      ..setFloat(3, grain)
      ..setFloat(4, vignette);
    canvas.drawRect(Offset.zero & size, Paint()..shader = s);
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.t != t;
}

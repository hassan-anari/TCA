import 'dart:async';

import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/components/circular_icon_button.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Common transparent overlay frame for spatial screens. Android back always
/// moves one spatial level up instead of leaving the app.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key, required this.child, this.parent, this.onBack});

  final Widget child;
  final String? parent;

  /// Replaces the default "go to parent" behaviour for system back.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: parent == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || parent == null) return;
        if (onBack != null) {
          onBack!();
        } else {
          context.go(parent!);
        }
      },
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(child: child),
      ),
    );
  }
}

/// Back button + centred editorial title block used across screens.
class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    required this.onBack,
    this.title,
    this.eyebrow,
    this.trailing,
    this.backLabel = 'Back',
  });

  final VoidCallback onBack;
  final String? title;
  final String? eyebrow;
  final Widget? trailing;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MemoriaSpacing.md,
        MemoriaSpacing.sm,
        MemoriaSpacing.md,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircularIconButton(
                icon: LucideIcons.arrowLeft,
                onPressed: onBack,
                semanticLabel: backLabel,
              ),
              const Spacer(),
              trailing ?? const SizedBox(width: 52),
            ],
          ),
          if (title != null) ...[
            const SizedBox(height: MemoriaSpacing.sm),
            Text(
              title!,
              textAlign: TextAlign.center,
              style: MemoriaType.headingL(context),
            ),
          ],
          if (eyebrow != null) ...[
            const SizedBox(height: MemoriaSpacing.xs),
            Text(
              eyebrow!.toUpperCase(),
              textAlign: TextAlign.center,
              style: MemoriaType.eyebrow(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small transient instruction that fades out after a few seconds.
class GestureHint extends StatefulWidget {
  const GestureHint({super.key, required this.text});
  final String text;

  @override
  State<GestureHint> createState() => _GestureHintState();
}

class _GestureHintState extends State<GestureHint> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: MemoriaDurations.slow,
        child: Text(
          widget.text,
          textAlign: TextAlign.center,
          style: MemoriaType.meta(context),
        ),
      ),
    );
  }
}

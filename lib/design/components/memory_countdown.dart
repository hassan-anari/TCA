import 'package:flutter/widgets.dart';

import '../tokens.dart';
import '../typography.dart';

/// Remaining time until a capsule opens, shown as days / hours / minutes.
class MemoryCountdown extends StatelessWidget {
  const MemoryCountdown({super.key, required this.remaining});

  final Duration remaining;

  static List<(String, String)> parts(Duration d) {
    final r = d.isNegative ? Duration.zero : d;
    return [
      ('${r.inDays}', r.inDays == 1 ? 'day' : 'days'),
      ((r.inHours % 24).toString().padLeft(2, '0'), 'hours'),
      ((r.inMinutes % 60).toString().padLeft(2, '0'), 'min'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = parts(remaining);
    return Semantics(
      label:
          'Opens in ${p[0].$1} ${p[0].$2}, ${p[1].$1} hours, ${p[2].$1} minutes',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < p.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(
                  horizontal: MemoriaSpacing.lg,
                ),
                color: MemoriaColors.warmIvory.withValues(alpha: 0.16),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p[i].$1,
                  style: MemoriaType.headingL(
                    context,
                  ).copyWith(fontSize: 34, height: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  p[i].$2.toUpperCase(),
                  style: MemoriaType.eyebrow(
                    context,
                  ).copyWith(letterSpacing: 2.4, fontSize: 10),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

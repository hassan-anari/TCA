import 'package:flutter/widgets.dart';

import '../tokens.dart';
import '../typography.dart';

class AvatarData {
  const AvatarData({
    required this.name,
    required this.colorA,
    required this.colorB,
  });
  final String name;
  final Color colorA;
  final Color colorB;
  String get initials => name
      .split(' ')
      .where((s) => s.isNotEmpty)
      .take(2)
      .map((s) => s[0])
      .join();
}

/// Overlapping circular avatars ringed in warm light. Prototype avatars are
/// generated monograms (no real people's photos are bundled).
class AvatarGroup extends StatelessWidget {
  const AvatarGroup({
    super.key,
    required this.people,
    this.size = 48,
    this.selected,
  });

  final List<AvatarData> people;
  final double size;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final overlap = size * 0.28;
    return Semantics(
      label: people.map((p) => p.name).join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: size,
        width: size + (people.length - 1) * (size - overlap),
        child: Stack(
          children: [
            for (var i = 0; i < people.length; i++)
              Positioned(
                left: i * (size - overlap),
                child: AvatarBubble(
                  person: people[i],
                  size: size,
                  highlighted: selected == null || selected == i,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AvatarBubble extends StatelessWidget {
  const AvatarBubble({
    super.key,
    required this.person,
    this.size = 48,
    this.highlighted = true,
  });
  final AvatarData person;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: MemoriaDurations.medium,
      opacity: highlighted ? 1 : 0.55,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [person.colorA, person.colorB],
          ),
          border: Border.all(
            color: MemoriaColors.memoryGlow.withValues(
              alpha: highlighted ? 0.85 : 0.3,
            ),
            width: 1.4,
          ),
          boxShadow: highlighted ? MemoriaShadows.glow : null,
        ),
        alignment: Alignment.center,
        child: Text(
          person.initials,
          style: MemoriaType.headingM(
            context,
          ).copyWith(fontSize: size * 0.4, color: MemoriaColors.warmIvory),
        ),
      ),
    );
  }
}

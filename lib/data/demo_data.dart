import 'dart:ui' show Color;

import 'models.dart';

/// Deterministic local demonstration data. No network, no real people.
abstract final class DemoData {
  static const galaxies = [
    GalaxyInfo(
      year: 2024,
      name: 'Tidal Bloom',
      mood: 'Cool tides, slow beginnings',
    ),
    GalaxyInfo(
      year: 2025,
      name: 'Amber Hearth',
      mood: 'Warm light, people close by',
    ),
    GalaxyInfo(year: 2026, name: 'Rose Veil', mood: 'Letters to the future'),
  ];

  static const people = <String, Person>{
    'me': Person(
      id: 'me',
      name: 'You',
      colorA: Color(0xFF547779),
      colorB: Color(0xFF254448),
    ),
    'maya': Person(
      id: 'maya',
      name: 'Maya Lind',
      colorA: Color(0xFFD6A39F),
      colorB: Color(0xFF8E6A72),
    ),
    'sam': Person(
      id: 'sam',
      name: 'Sam Okoro',
      colorA: Color(0xFFE5C5AE),
      colorB: Color(0xFF9C7B62),
    ),
    'leila': Person(
      id: 'leila',
      name: 'Leila Haddad',
      colorA: Color(0xFF8FA8A6),
      colorB: Color(0xFF3E5E60),
    ),
  };

  /// The hero memory: shared, unlocked, uses the high-fidelity "bloom" world.
  static const heroId = 'm-2025-old-tree';

  static final List<Memory> memories = [
    // 2024 - Tidal Bloom
    Memory(
      id: 'm-2024-first-swim',
      title: 'First Swim at Dawn',
      memoryDate: DateTime(2024, 7, 3),
      createdAt: DateTime(2024, 7, 3, 21, 10),
      kind: MemoryKind.personal,
      world: WorldStyle.tide,
      images: const ['assets/images/sample_sunset.jpg'],
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'The water was colder than I expected and the sky had not decided on a colour yet. '
              'I swam out until the shore was a soft line, then floated and listened to nothing at all.',
        ),
      ],
    ),
    Memory(
      id: 'm-2024-garden',
      title: "Grandmother's Garden",
      memoryDate: DateTime(2024, 5, 12),
      createdAt: DateTime(2024, 5, 13, 8, 0),
      kind: MemoryKind.personal,
      world: WorldStyle.grove,
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'She named every plant as if introducing old friends. The fig tree she planted the year I was born '
              'is taller than the house now.',
        ),
      ],
    ),
    Memory(
      id: 'm-2024-long-winter',
      title: 'The Long Winter',
      memoryDate: DateTime(2024, 1, 20),
      createdAt: DateTime(2024, 1, 21, 22, 30),
      kind: MemoryKind.personal,
      world: WorldStyle.frost,
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'Snow for eleven days. We learned the names of the neighbours by their boots.',
        ),
      ],
    ),
    Memory(
      id: 'm-2024-desert-road',
      title: 'Desert Road',
      memoryDate: DateTime(2024, 9, 14),
      createdAt: DateTime(2024, 9, 20, 18, 45),
      kind: MemoryKind.shared,
      world: WorldStyle.dune,
      participantIds: const ['me', 'leila'],
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'Four hundred kilometres of nothing and a playlist we wore out by noon.',
        ),
        Perspective(
          authorId: 'leila',
          text:
              'You drove with the window down the whole way. My hair has not recovered.',
        ),
      ],
    ),
    Memory(
      id: 'm-2024-lanterns',
      title: 'Lantern Night',
      memoryDate: DateTime(2024, 2, 24),
      createdAt: DateTime(2024, 2, 25, 1, 15),
      kind: MemoryKind.shared,
      world: WorldStyle.ember,
      participantIds: const ['me', 'sam'],
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'A thousand small lights leaving at once, and the whole crowd went quiet.',
        ),
        Perspective(
          authorId: 'sam',
          text:
              'Ours drifted left and got stuck in a tree. Still the best one.',
        ),
      ],
    ),
    // 2025 - Amber Hearth
    Memory(
      id: heroId,
      title: 'Spring Under the Old Tree',
      subtitle: 'A shared memory planet',
      memoryDate: DateTime(2025, 4, 6),
      createdAt: DateTime(2025, 4, 6, 19, 40),
      kind: MemoryKind.shared,
      world: WorldStyle.bloom,
      participantIds: const ['me', 'maya'],
      images: const [
        'assets/images/sample_blossom.jpg',
        'assets/images/sample_mountains.jpg',
        'assets/images/sample_sunset.jpg',
      ],
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'We walked up past the waterfall because Maya swore the old cherry tree was blooming early. '
              'It was. Petals kept landing in the tea. We stayed until the light went gold and then blue, '
              'talking about the people we wanted to become, and for once neither of us checked the time.',
        ),
        Perspective(
          authorId: 'maya',
          text:
              'I remember the sound more than anything: water somewhere below us, and wind moving through '
              'all those blossoms at once like a slow exhale. You fell asleep against the trunk for ten minutes '
              'and I did not wake you. I wanted to keep that afternoon exactly as it was.',
        ),
      ],
    ),
    Memory(
      id: 'm-2025-lake-house',
      title: 'Lake House Weekend',
      memoryDate: DateTime(2025, 8, 16),
      createdAt: DateTime(2025, 8, 18, 9, 5),
      kind: MemoryKind.personal,
      world: WorldStyle.grove,
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'Mist on the lake every morning. Coffee on the dock, bare feet, no plans.',
        ),
      ],
    ),
    Memory(
      id: 'm-2025-night-market',
      title: 'Night Market',
      memoryDate: DateTime(2025, 11, 2),
      createdAt: DateTime(2025, 11, 3, 0, 40),
      kind: MemoryKind.shared,
      world: WorldStyle.ember,
      participantIds: const ['me', 'sam', 'leila'],
      perspectives: const [
        Perspective(
          authorId: 'me',
          text: 'Steam, paper lanterns and too many dumplings.',
        ),
        Perspective(
          authorId: 'sam',
          text: 'We tried every stall. I regret nothing.',
        ),
        Perspective(
          authorId: 'leila',
          text:
              'The old man selling tea told us our fortunes. Mine was suspiciously accurate.',
        ),
      ],
    ),
    Memory(
      id: 'm-2025-snowfall',
      title: 'Snowfall in March',
      memoryDate: DateTime(2025, 3, 9),
      createdAt: DateTime(2025, 3, 9, 23, 0),
      kind: MemoryKind.personal,
      world: WorldStyle.frost,
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'Late snow on early blossoms. The city looked like it had forgotten the season.',
        ),
      ],
    ),
    Memory(
      id: 'm-2025-salt-sun',
      title: 'Salt and Sun',
      memoryDate: DateTime(2025, 6, 28),
      createdAt: DateTime(2025, 7, 1, 12, 0),
      kind: MemoryKind.personal,
      world: WorldStyle.tide,
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'A small island, a borrowed bicycle and an afternoon that lasted all week.',
        ),
      ],
    ),
    // 2026 - Rose Veil
    Memory(
      id: 'm-2026-letter',
      title: 'Letter to Next Spring',
      memoryDate: DateTime(2026, 3, 14),
      createdAt: DateTime(2026, 3, 14, 22, 15),
      unlockAt: DateTime(2027, 3, 14, 9, 0),
      kind: MemoryKind.personal,
      world: WorldStyle.bloom,
      images: const ['assets/images/sample_blossom.jpg'],
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'If you are reading this, a whole year has turned. I hope you kept walking in the mornings. '
              'I hope you called your grandmother more. I hope the tree on the hill is blooming again.',
        ),
      ],
    ),
    Memory(
      id: 'm-2026-our-capsule',
      title: 'Our Time Capsule',
      memoryDate: DateTime(2026, 6, 21),
      createdAt: DateTime(2026, 6, 21, 20, 30),
      unlockAt: DateTime(2026, 12, 31, 23, 0),
      kind: MemoryKind.shared,
      world: WorldStyle.bloom,
      participantIds: const ['me', 'maya'],
      perspectives: const [
        Perspective(
          authorId: 'me',
          text: 'Midsummer. We each wrote one wish and did not show the other.',
        ),
        Perspective(
          authorId: 'maya',
          text: 'Mine is about you. That is all I will say until December.',
        ),
      ],
    ),
    Memory(
      id: 'm-2026-quiet-dunes',
      title: 'Quiet Dunes',
      memoryDate: DateTime(2026, 2, 7),
      createdAt: DateTime(2026, 2, 8, 10, 0),
      kind: MemoryKind.personal,
      world: WorldStyle.dune,
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'Wind drew new lines in the sand every hour. Nothing stayed, and that was the point.',
        ),
      ],
    ),
    Memory(
      id: 'm-2026-moving-day',
      title: 'Moving Day',
      memoryDate: DateTime(2026, 9, 5),
      createdAt: DateTime(2026, 9, 6, 21, 0),
      kind: MemoryKind.shared,
      world: WorldStyle.grove,
      participantIds: const ['me', 'sam'],
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'Every box labelled "misc". The first night we ate on the floor and it felt like home.',
        ),
        Perspective(
          authorId: 'sam',
          text:
              'Carried the plant up four floors. It is thriving. My back is not.',
        ),
      ],
    ),
    Memory(
      id: 'm-2026-harbor',
      title: 'Harbor Lights',
      memoryDate: DateTime(2026, 10, 18),
      createdAt: DateTime(2026, 10, 18, 23, 50),
      kind: MemoryKind.personal,
      world: WorldStyle.tide,
      perspectives: const [
        Perspective(
          authorId: 'me',
          text:
              'Boats coming home one by one, each light doubled in the water.',
        ),
      ],
    ),
  ];
}

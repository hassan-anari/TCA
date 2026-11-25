import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/data/demo_data.dart';
import 'package:memoria/data/memory_repository.dart';
import 'package:memoria/data/models.dart';
import 'package:memoria/scene/scene_backend.dart';
import 'package:memoria/scene/scene_layout.dart';
import 'package:memoria/state/memoria_state.dart';

void main() {
  test(
    'demo data: three galaxies, at least five planets each, distinct worlds',
    () {
      for (final g in DemoData.galaxies) {
        final ms = DemoData.memories.where((m) => m.year == g.year).toList();
        expect(ms.length, greaterThanOrEqualTo(5), reason: '${g.year}');
        expect(ms.map((m) => m.world).toSet().length, greaterThanOrEqualTo(4));
      }
      final hero = DemoData.memories.firstWhere((m) => m.id == DemoData.heroId);
      expect(hero.isShared, isTrue);
      expect(hero.perspectives.length, greaterThanOrEqualTo(2));
      expect(hero.world, WorldStyle.bloom);
    },
  );

  test('demo data covers locked, unlocked, personal and shared states', () {
    final now = DateTime(2026, 11, 25);
    final ms = DemoData.memories;
    expect(ms.any((m) => m.isLockedAt(now)), isTrue);
    expect(ms.any((m) => !m.isLockedAt(now)), isTrue);
    expect(ms.any((m) => m.isShared), isTrue);
    expect(ms.any((m) => !m.isShared), isTrue);
  });

  test('memory JSON round trip', () {
    final m = DemoData.memories.firstWhere((m) => m.unlockAt != null);
    final back = Memory.decodeList(Memory.encodeList([m])).single;
    expect(back.id, m.id);
    expect(back.unlockAt, m.unlockAt);
    expect(back.perspectives.length, m.perspectives.length);
    expect(back.kind, m.kind);
  });

  test('locked capsules render as the sealed capsule asset', () {
    final m = DemoData.memories.firstWhere((m) => m.id == 'm-2026-letter');
    expect(SceneLayout.assetFor(m, locked: true), SceneAssets.capsule);
    expect(SceneLayout.assetFor(m, locked: false), SceneAssets.bloom);
    expect(
      SceneLayout.assetFor(m, locked: false, evolved: true),
      SceneAssets.bloomEvolved,
    );
  });

  test('orbits are separated and ordered outward', () {
    for (var i = 1; i < 6; i++) {
      expect(
        SceneLayout.orbitFor(i, 6).radius,
        greaterThan(SceneLayout.orbitFor(i - 1, 6).radius + 1),
      );
    }
  });

  group('state', () {
    late ProviderContainer c;
    late InMemoryStore store;

    setUp(() {
      store = InMemoryStore();
      c = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(MemoryRepository(store)),
        ],
      );
    });
    tearDown(() => c.dispose());

    Future<void> settle() async {
      c.read(memoriaProvider);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test(
      'seal capsule, prototype clock unlock, revisit evolution, persistence',
      () async {
        await settle();
        final n = c.read(memoriaProvider.notifier);
        final unlock = c
            .read(memoriaProvider)
            .now()
            .add(const Duration(days: 40));
        final m = await n.sealCapsule(
          title: 'Test',
          text: 'Hello future',
          memoryDate: DateTime(2026, 5, 1),
          unlockAt: unlock,
          kind: MemoryKind.shared,
        );
        var st = c.read(memoriaProvider);
        expect(st.byId(m.id)!.isLockedAt(st.now()), isTrue);
        await n.advanceClockToUnlock(m);
        st = c.read(memoriaProvider);
        expect(st.byId(m.id)!.isLockedAt(st.now()), isFalse);
        expect(st.isEvolved(m.id), isFalse);
        await n.recordRevisit(m.id);
        expect(c.read(memoriaProvider).isEvolved(m.id), isTrue);

        // A fresh container over the same store sees the persisted state.
        final c2 = ProviderContainer(
          overrides: [
            repositoryProvider.overrideWithValue(MemoryRepository(store)),
          ],
        );
        c2.read(memoriaProvider);
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        final st2 = c2.read(memoriaProvider);
        expect(st2.byId(m.id), isNotNull);
        expect(st2.isEvolved(m.id), isTrue);
        expect(st2.clockOffset.inSeconds, st.clockOffset.inSeconds);
        c2.dispose();
      },
    );

    test(
      'memory dates outside the three galaxies are clamped into them',
      () async {
        await settle();
        final m = await c
            .read(memoriaProvider.notifier)
            .sealCapsule(
              title: '',
              text: 'x',
              memoryDate: DateTime(2030, 2, 3),
              unlockAt: DateTime(2031),
              kind: MemoryKind.personal,
            );
        expect(m.year, 2026);
        expect(m.title, 'Untitled memory');
      },
    );
  });
}

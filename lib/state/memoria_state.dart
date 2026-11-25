import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_data.dart';
import '../data/memory_repository.dart';
import '../data/models.dart';

class MemoriaState {
  const MemoriaState({
    required this.userMemories,
    required this.revisits,
    required this.clockOffset,
    required this.revealed,
    this.loaded = false,
  });

  final List<Memory> userMemories;
  final Map<String, int> revisits;

  /// Prototype-only clock offset used to demonstrate time-based unlocking.
  final Duration clockOffset;
  final Set<String> revealed;
  final bool loaded;

  List<Memory> get allMemories => [...DemoData.memories, ...userMemories];

  DateTime now([DateTime? real]) => (real ?? DateTime.now()).add(clockOffset);

  Memory? byId(String id) {
    for (final m in allMemories) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<Memory> forYear(int year) =>
      allMemories.where((m) => m.year == year).toList();

  int revisitsOf(String id) => revisits[id] ?? 0;

  /// The hero world has an authored evolved variant; it appears once the
  /// unlocked memory has been read and the user returns to the planet.
  bool isEvolved(String id) => revisitsOf(id) >= 1;

  MemoriaState copyWith({
    List<Memory>? userMemories,
    Map<String, int>? revisits,
    Duration? clockOffset,
    Set<String>? revealed,
    bool? loaded,
  }) => MemoriaState(
    userMemories: userMemories ?? this.userMemories,
    revisits: revisits ?? this.revisits,
    clockOffset: clockOffset ?? this.clockOffset,
    revealed: revealed ?? this.revealed,
    loaded: loaded ?? this.loaded,
  );
}

final repositoryProvider = Provider<MemoryRepository>(
  (ref) => MemoryRepository(SharedPrefsStore()),
);

class MemoriaController extends Notifier<MemoriaState> {
  late MemoryRepository _repo;

  @override
  MemoriaState build() {
    _repo = ref.watch(repositoryProvider);
    _load();
    return const MemoriaState(
      userMemories: [],
      revisits: {},
      clockOffset: Duration.zero,
      revealed: {},
    );
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _repo.loadUserMemories(),
      _repo.loadRevisits(),
      _repo.loadClockOffset(),
      _repo.loadRevealed(),
    ]);
    state = MemoriaState(
      userMemories: results[0] as List<Memory>,
      revisits: results[1] as Map<String, int>,
      clockOffset: results[2] as Duration,
      revealed: results[3] as Set<String>,
      loaded: true,
    );
  }

  Future<Memory> sealCapsule({
    required String title,
    required String text,
    required DateTime memoryDate,
    required DateTime unlockAt,
    required MemoryKind kind,
    String? photoPath,
  }) async {
    final created = state.now();
    final year = memoryDate.year.clamp(2024, 2026);
    final date = memoryDate.year == year
        ? memoryDate
        : DateTime(year, memoryDate.month, memoryDate.day);
    final m = Memory(
      id: 'u-${created.microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Untitled memory' : title.trim(),
      memoryDate: date,
      createdAt: created,
      unlockAt: unlockAt,
      kind: kind,
      world: WorldStyle.bloom,
      perspectives: [Perspective(authorId: 'me', text: text.trim())],
      participantIds: kind == MemoryKind.shared
          ? const ['me', 'maya']
          : const ['me'],
      images: photoPath == null ? const [] : [photoPath],
      userCreated: true,
    );
    final list = [...state.userMemories, m];
    state = state.copyWith(userMemories: list);
    await _repo.saveUserMemories(list);
    return m;
  }

  Future<void> recordRevisit(String id) async {
    final map = {...state.revisits, id: state.revisitsOf(id) + 1};
    state = state.copyWith(revisits: map);
    await _repo.saveRevisits(map);
  }

  Future<void> markRevealed(String id) async {
    final s = {...state.revealed, id};
    state = state.copyWith(revealed: s);
    await _repo.saveRevealed(s);
  }

  /// Prototype-only: jump the local clock just past [memory]'s unlock date.
  Future<void> advanceClockToUnlock(Memory memory) async {
    if (memory.unlockAt == null) return;
    final real = DateTime.now();
    final target = memory.unlockAt!.add(const Duration(minutes: 1));
    final needed = target.difference(real);
    final offset = needed > state.clockOffset ? needed : state.clockOffset;
    state = state.copyWith(clockOffset: offset);
    await _repo.saveClockOffset(offset);
  }

  Future<void> resetClock() async {
    state = state.copyWith(clockOffset: Duration.zero);
    await _repo.saveClockOffset(Duration.zero);
  }
}

final memoriaProvider = NotifierProvider<MemoriaController, MemoriaState>(
  MemoriaController.new,
);

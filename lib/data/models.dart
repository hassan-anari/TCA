import 'dart:convert';
import 'dart:ui' show Color;

/// The visual world a memory planet grows into. Each maps to a GLB asset.
enum WorldStyle { bloom, tide, dune, frost, grove, ember }

enum MemoryKind { personal, shared }

class Person {
  const Person({
    required this.id,
    required this.name,
    required this.colorA,
    required this.colorB,
  });
  final String id;
  final String name;
  final Color colorA;
  final Color colorB;
}

/// One participant's written account of a memory. Shared memories hold
/// several independent perspectives.
class Perspective {
  const Perspective({required this.authorId, required this.text});
  final String authorId;
  final String text;

  Map<String, Object?> toJson() => {'authorId': authorId, 'text': text};
  factory Perspective.fromJson(Map<String, Object?> j) => Perspective(
    authorId: j['authorId']! as String,
    text: j['text']! as String,
  );
}

class Memory {
  const Memory({
    required this.id,
    required this.title,
    required this.memoryDate,
    required this.createdAt,
    required this.kind,
    required this.world,
    required this.perspectives,
    this.unlockAt,
    this.images = const [],
    this.participantIds = const ['me'],
    this.userCreated = false,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
  final DateTime memoryDate;
  final DateTime createdAt;
  final DateTime? unlockAt;
  final MemoryKind kind;
  final WorldStyle world;
  final List<Perspective> perspectives;

  /// Flutter asset paths (`assets/...`) or local file paths for user photos.
  final List<String> images;
  final List<String> participantIds;
  final bool userCreated;

  int get year => memoryDate.year;
  bool get isShared => kind == MemoryKind.shared;
  bool get isTimeLocked => unlockAt != null;

  bool isLockedAt(DateTime now) => unlockAt != null && now.isBefore(unlockAt!);

  Duration remainingAt(DateTime now) =>
      unlockAt == null ? Duration.zero : unlockAt!.difference(now);

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'memoryDate': memoryDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'unlockAt': unlockAt?.toIso8601String(),
    'kind': kind.name,
    'world': world.name,
    'perspectives': perspectives.map((p) => p.toJson()).toList(),
    'images': images,
    'participantIds': participantIds,
    'userCreated': userCreated,
  };

  factory Memory.fromJson(Map<String, Object?> j) => Memory(
    id: j['id']! as String,
    title: j['title']! as String,
    subtitle: j['subtitle'] as String?,
    memoryDate: DateTime.parse(j['memoryDate']! as String),
    createdAt: DateTime.parse(j['createdAt']! as String),
    unlockAt: j['unlockAt'] == null
        ? null
        : DateTime.parse(j['unlockAt']! as String),
    kind: MemoryKind.values.byName(j['kind']! as String),
    world: WorldStyle.values.byName(j['world']! as String),
    perspectives: (j['perspectives']! as List)
        .map((e) => Perspective.fromJson((e as Map).cast<String, Object?>()))
        .toList(),
    images: (j['images'] as List?)?.cast<String>() ?? const [],
    participantIds:
        (j['participantIds'] as List?)?.cast<String>() ?? const ['me'],
    userCreated: j['userCreated'] as bool? ?? false,
  );

  static String encodeList(List<Memory> list) =>
      jsonEncode(list.map((m) => m.toJson()).toList());
  static List<Memory> decodeList(String s) => (jsonDecode(s) as List)
      .map((e) => Memory.fromJson((e as Map).cast<String, Object?>()))
      .toList();
}

/// A year of the user's life rendered as a galaxy.
class GalaxyInfo {
  const GalaxyInfo({
    required this.year,
    required this.name,
    required this.mood,
  });
  final int year;
  final String name;
  final String mood;
}

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Minimal key-value surface so tests can run without platform channels.
abstract class PrototypeStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<List<String>?> getStringList(String key);
  Future<void> setStringList(String key, List<String> value);
  Future<int?> getInt(String key);
  Future<void> setInt(String key, int value);
}

class SharedPrefsStore implements PrototypeStore {
  SharedPrefsStore([SharedPreferencesAsync? prefs])
    : _p = prefs ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _p;
  @override
  Future<String?> getString(String key) => _p.getString(key);
  @override
  Future<void> setString(String key, String value) => _p.setString(key, value);
  @override
  Future<List<String>?> getStringList(String key) => _p.getStringList(key);
  @override
  Future<void> setStringList(String key, List<String> value) =>
      _p.setStringList(key, value);
  @override
  Future<int?> getInt(String key) => _p.getInt(key);
  @override
  Future<void> setInt(String key, int value) => _p.setInt(key, value);
}

class InMemoryStore implements PrototypeStore {
  final Map<String, Object> data = {};
  @override
  Future<String?> getString(String key) async => data[key] as String?;
  @override
  Future<void> setString(String key, String value) async => data[key] = value;
  @override
  Future<List<String>?> getStringList(String key) async =>
      (data[key] as List<String>?)?.toList();
  @override
  Future<void> setStringList(String key, List<String> value) async =>
      data[key] = value.toList();
  @override
  Future<int?> getInt(String key) async => data[key] as int?;
  @override
  Future<void> setInt(String key, int value) async => data[key] = value;
}

/// Local-only persistence for prototype state (survives app restarts).
/// Not encrypted and not a security boundary - deliberately prototype-grade.
class MemoryRepository {
  MemoryRepository(this._prefs);

  final PrototypeStore _prefs;

  static const _kUserMemories = 'memoria.userMemories.v1';
  static const _kRevisits = 'memoria.revisits.v1';
  static const _kClockOffset = 'memoria.prototypeClockOffsetSeconds.v1';
  static const _kRevealed = 'memoria.revealed.v1';

  Future<List<Memory>> loadUserMemories() async {
    final s = await _prefs.getString(_kUserMemories);
    if (s == null || s.isEmpty) return [];
    try {
      return Memory.decodeList(s);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveUserMemories(List<Memory> list) =>
      _prefs.setString(_kUserMemories, Memory.encodeList(list));

  Future<Map<String, int>> loadRevisits() async {
    final list = await _prefs.getStringList(_kRevisits) ?? const [];
    final map = <String, int>{};
    for (final e in list) {
      final i = e.lastIndexOf('=');
      if (i > 0) map[e.substring(0, i)] = int.tryParse(e.substring(i + 1)) ?? 0;
    }
    return map;
  }

  Future<void> saveRevisits(Map<String, int> map) => _prefs.setStringList(
    _kRevisits,
    map.entries.map((e) => '${e.key}=${e.value}').toList(),
  );

  Future<Duration> loadClockOffset() async =>
      Duration(seconds: await _prefs.getInt(_kClockOffset) ?? 0);

  Future<void> saveClockOffset(Duration d) =>
      _prefs.setInt(_kClockOffset, d.inSeconds);

  Future<Set<String>> loadRevealed() async =>
      (await _prefs.getStringList(_kRevealed) ?? const []).toSet();

  Future<void> saveRevealed(Set<String> ids) =>
      _prefs.setStringList(_kRevealed, ids.toList());
}

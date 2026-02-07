import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recording.dart';
import 'recording_repository.dart';

class LocalRecordingRepository implements RecordingRepository {
  static const _kKey = 'recordings_v1';

  @override
  Future<List<Recording>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((e) => Recording.fromMap(e.cast<String, Object?>()))
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<void> add(Recording recording) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _readList(prefs);
    items.add(recording.toMap());
    await prefs.setString(_kKey, jsonEncode(items));
  }

  @override
  Future<void> deleteById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _readList(prefs);
    items.removeWhere((e) => e['id'] == id);
    await prefs.setString(_kKey, jsonEncode(items));
  }

  Future<List<Map<String, Object?>>> _readList(SharedPreferences prefs) async {
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((e) => e.cast<String, Object?>())
        .toList();
  }
}

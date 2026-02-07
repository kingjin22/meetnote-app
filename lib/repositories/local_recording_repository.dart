import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recording.dart';
import 'recording_repository.dart';

class LocalRecordingRepository implements RecordingRepository {
  static const _kKey = 'recordings_v1';

  @override
  Future<List<Recording>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final maps = await _readList(prefs);
    if (maps.isEmpty) return [];

    final recordings = <Recording>[];
    var changed = false;

    for (final map in maps) {
      final rec = Recording.fromMap(map);
      final exists = await File(rec.filePath).exists();
      if (!exists) {
        changed = true;
        continue;
      }
      recordings.add(rec);
    }

    if (changed) {
      await prefs.setString(
        _kKey,
        jsonEncode(recordings.map((e) => e.toMap()).toList()),
      );
    }

    return recordings.reversed.toList();
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

    final index = items.indexWhere((e) => e['id'] == id);
    if (index >= 0) {
      final filePath = items[index]['filePath'];
      if (filePath is String && filePath.isNotEmpty) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // best-effort
        }
      }

      items.removeAt(index);
      await prefs.setString(_kKey, jsonEncode(items));
    }
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

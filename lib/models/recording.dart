import 'dart:convert';

class Recording {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final Duration duration;

  const Recording({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.duration,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'durationMs': duration.inMilliseconds,
    };
  }

  factory Recording.fromMap(Map<String, Object?> map) {
    return Recording(
      id: map['id'] as String,
      filePath: map['filePath'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAtMs'] as int),
      duration: Duration(milliseconds: map['durationMs'] as int),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Recording.fromJson(String json) {
    return Recording.fromMap(jsonDecode(json) as Map<String, Object?>);
  }
}

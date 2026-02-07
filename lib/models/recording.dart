import 'dart:convert';

class Recording {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final Duration duration;
  final String? transcriptText;
  final String? summaryText;

  const Recording({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.duration,
    this.transcriptText,
    this.summaryText,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'durationMs': duration.inMilliseconds,
      'transcriptText': transcriptText,
      'summaryText': summaryText,
    };
  }

  factory Recording.fromMap(Map<String, Object?> map) {
    return Recording(
      id: map['id'] as String,
      filePath: map['filePath'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAtMs'] as int),
      duration: Duration(milliseconds: map['durationMs'] as int),
      transcriptText: map['transcriptText'] as String?,
      summaryText: map['summaryText'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Recording.fromJson(String json) {
    return Recording.fromMap(jsonDecode(json) as Map<String, Object?>);
  }

  Recording copyWith({
    String? transcriptText,
    String? summaryText,
  }) {
    return Recording(
      id: id,
      filePath: filePath,
      createdAt: createdAt,
      duration: duration,
      transcriptText: transcriptText ?? this.transcriptText,
      summaryText: summaryText ?? this.summaryText,
    );
  }
}

import 'dart:convert';

enum TranscriptionStatus {
  none,
  pending,
  success,
  failed;

  String toJson() => name;

  static TranscriptionStatus fromJson(String? value) {
    if (value == null) return TranscriptionStatus.none;
    return TranscriptionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TranscriptionStatus.none,
    );
  }
}

class Recording {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final Duration duration;
  final String? title; // Custom title set by user
  final bool isFavorite; // Favorite flag
  final String? transcriptText;
  final String? summaryText;
  final TranscriptionStatus transcriptionStatus;
  final String? transcriptionError;
  final int transcriptionRetryCount;
  final DateTime? transcriptionCompletedAt;

  const Recording({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.duration,
    this.title,
    this.isFavorite = false,
    this.transcriptText,
    this.summaryText,
    this.transcriptionStatus = TranscriptionStatus.none,
    this.transcriptionError,
    this.transcriptionRetryCount = 0,
    this.transcriptionCompletedAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'durationMs': duration.inMilliseconds,
      'title': title,
      'isFavorite': isFavorite ? 1 : 0,
      'transcriptText': transcriptText,
      'summaryText': summaryText,
      'transcriptionStatus': transcriptionStatus.toJson(),
      'transcriptionError': transcriptionError,
      'transcriptionRetryCount': transcriptionRetryCount,
      'transcriptionCompletedAtMs': transcriptionCompletedAt?.millisecondsSinceEpoch,
    };
  }

  factory Recording.fromMap(Map<String, Object?> map) {
    final transcriptionCompletedAtMs = map['transcriptionCompletedAtMs'] as int?;
    return Recording(
      id: map['id'] as String,
      filePath: map['filePath'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAtMs'] as int),
      duration: Duration(milliseconds: map['durationMs'] as int),
      title: map['title'] as String?,
      isFavorite: (map['isFavorite'] as int?) == 1,
      transcriptText: map['transcriptText'] as String?,
      summaryText: map['summaryText'] as String?,
      transcriptionStatus: TranscriptionStatus.fromJson(
        map['transcriptionStatus'] as String?,
      ),
      transcriptionError: map['transcriptionError'] as String?,
      transcriptionRetryCount: (map['transcriptionRetryCount'] as int?) ?? 0,
      transcriptionCompletedAt: transcriptionCompletedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(transcriptionCompletedAtMs)
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Recording.fromJson(String json) {
    return Recording.fromMap(jsonDecode(json) as Map<String, Object?>);
  }

  Recording copyWith({
    String? title,
    bool? isFavorite,
    String? transcriptText,
    String? summaryText,
    TranscriptionStatus? transcriptionStatus,
    String? transcriptionError,
    int? transcriptionRetryCount,
    DateTime? transcriptionCompletedAt,
    bool clearTranscriptionError = false,
    bool clearTitle = false,
  }) {
    return Recording(
      id: id,
      filePath: filePath,
      createdAt: createdAt,
      duration: duration,
      title: clearTitle ? null : (title ?? this.title),
      isFavorite: isFavorite ?? this.isFavorite,
      transcriptText: transcriptText ?? this.transcriptText,
      summaryText: summaryText ?? this.summaryText,
      transcriptionStatus: transcriptionStatus ?? this.transcriptionStatus,
      transcriptionError: clearTranscriptionError
          ? null
          : (transcriptionError ?? this.transcriptionError),
      transcriptionRetryCount: transcriptionRetryCount ?? this.transcriptionRetryCount,
      transcriptionCompletedAt: transcriptionCompletedAt ?? this.transcriptionCompletedAt,
    );
  }
}

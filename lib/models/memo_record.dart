class MemoRecord {
  final String id;
  final String title;
  final DateTime createdAt;
  final String? duration;
  final String status;
  final bool hasTranscript;
  final String? transcript;

  MemoRecord({
    required this.id,
    required this.title,
    required this.createdAt,
    this.duration,
    required this.status,
    required this.hasTranscript,
    this.transcript,
  });
}

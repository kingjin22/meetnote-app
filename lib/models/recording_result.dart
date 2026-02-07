class RecordingResult {
  final String recordingId;
  final String filePath;
  final Duration duration;
  final DateTime createdAt;

  const RecordingResult({
    required this.recordingId,
    required this.filePath,
    required this.duration,
    required this.createdAt,
  });
}

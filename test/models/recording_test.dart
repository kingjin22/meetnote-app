import 'package:flutter_test/flutter_test.dart';
import 'package:meetnote_app/models/recording.dart';

void main() {
  group('TranscriptionStatus', () {
    test('toJson returns correct string', () {
      expect(TranscriptionStatus.none.toJson(), 'none');
      expect(TranscriptionStatus.pending.toJson(), 'pending');
      expect(TranscriptionStatus.success.toJson(), 'success');
      expect(TranscriptionStatus.failed.toJson(), 'failed');
    });

    test('fromJson returns correct enum', () {
      expect(TranscriptionStatus.fromJson('none'), TranscriptionStatus.none);
      expect(TranscriptionStatus.fromJson('pending'), TranscriptionStatus.pending);
      expect(TranscriptionStatus.fromJson('success'), TranscriptionStatus.success);
      expect(TranscriptionStatus.fromJson('failed'), TranscriptionStatus.failed);
    });

    test('fromJson returns none for invalid value', () {
      expect(TranscriptionStatus.fromJson('invalid'), TranscriptionStatus.none);
      expect(TranscriptionStatus.fromJson(null), TranscriptionStatus.none);
    });
  });

  group('Recording', () {
    test('toMap includes all transcription fields', () {
      final recording = Recording(
        id: 'test-id',
        filePath: '/path/to/file.m4a',
        createdAt: DateTime(2024, 1, 1, 12, 0),
        duration: const Duration(minutes: 5),
        transcriptText: 'Test transcript',
        summaryText: 'Test summary',
        transcriptionStatus: TranscriptionStatus.success,
        transcriptionError: null,
        transcriptionRetryCount: 2,
        transcriptionCompletedAt: DateTime(2024, 1, 1, 12, 5),
      );

      final map = recording.toMap();

      expect(map['id'], 'test-id');
      expect(map['filePath'], '/path/to/file.m4a');
      expect(map['transcriptText'], 'Test transcript');
      expect(map['summaryText'], 'Test summary');
      expect(map['transcriptionStatus'], 'success');
      expect(map['transcriptionError'], null);
      expect(map['transcriptionRetryCount'], 2);
      expect(map['transcriptionCompletedAtMs'], DateTime(2024, 1, 1, 12, 5).millisecondsSinceEpoch);
    });

    test('fromMap reconstructs recording with all fields', () {
      final map = {
        'id': 'test-id',
        'filePath': '/path/to/file.m4a',
        'createdAtMs': DateTime(2024, 1, 1, 12, 0).millisecondsSinceEpoch,
        'durationMs': const Duration(minutes: 5).inMilliseconds,
        'transcriptText': 'Test transcript',
        'summaryText': 'Test summary',
        'transcriptionStatus': 'success',
        'transcriptionError': null,
        'transcriptionRetryCount': 2,
        'transcriptionCompletedAtMs': DateTime(2024, 1, 1, 12, 5).millisecondsSinceEpoch,
      };

      final recording = Recording.fromMap(map);

      expect(recording.id, 'test-id');
      expect(recording.filePath, '/path/to/file.m4a');
      expect(recording.transcriptText, 'Test transcript');
      expect(recording.summaryText, 'Test summary');
      expect(recording.transcriptionStatus, TranscriptionStatus.success);
      expect(recording.transcriptionError, null);
      expect(recording.transcriptionRetryCount, 2);
      expect(recording.transcriptionCompletedAt, DateTime(2024, 1, 1, 12, 5));
    });

    test('fromMap handles missing transcription fields with defaults', () {
      final map = {
        'id': 'test-id',
        'filePath': '/path/to/file.m4a',
        'createdAtMs': DateTime(2024, 1, 1, 12, 0).millisecondsSinceEpoch,
        'durationMs': const Duration(minutes: 5).inMilliseconds,
      };

      final recording = Recording.fromMap(map);

      expect(recording.transcriptionStatus, TranscriptionStatus.none);
      expect(recording.transcriptionError, null);
      expect(recording.transcriptionRetryCount, 0);
      expect(recording.transcriptionCompletedAt, null);
    });

    test('copyWith updates transcription fields', () {
      final original = Recording(
        id: 'test-id',
        filePath: '/path/to/file.m4a',
        createdAt: DateTime(2024, 1, 1, 12, 0),
        duration: const Duration(minutes: 5),
        transcriptionStatus: TranscriptionStatus.none,
        transcriptionRetryCount: 0,
      );

      final updated = original.copyWith(
        transcriptionStatus: TranscriptionStatus.pending,
        transcriptionRetryCount: 1,
      );

      expect(updated.transcriptionStatus, TranscriptionStatus.pending);
      expect(updated.transcriptionRetryCount, 1);
      expect(updated.id, original.id);
      expect(updated.filePath, original.filePath);
    });

    test('copyWith with clearTranscriptionError clears error', () {
      final original = Recording(
        id: 'test-id',
        filePath: '/path/to/file.m4a',
        createdAt: DateTime(2024, 1, 1, 12, 0),
        duration: const Duration(minutes: 5),
        transcriptionStatus: TranscriptionStatus.failed,
        transcriptionError: 'Some error',
      );

      final updated = original.copyWith(
        transcriptionStatus: TranscriptionStatus.pending,
        clearTranscriptionError: true,
      );

      expect(updated.transcriptionError, null);
      expect(updated.transcriptionStatus, TranscriptionStatus.pending);
    });

    test('toJson and fromJson are symmetric', () {
      final original = Recording(
        id: 'test-id',
        filePath: '/path/to/file.m4a',
        createdAt: DateTime(2024, 1, 1, 12, 0),
        duration: const Duration(minutes: 5),
        transcriptText: 'Test transcript',
        summaryText: 'Test summary',
        transcriptionStatus: TranscriptionStatus.success,
        transcriptionRetryCount: 2,
        transcriptionCompletedAt: DateTime(2024, 1, 1, 12, 5),
      );

      final json = original.toJson();
      final decoded = Recording.fromJson(json);

      expect(decoded.id, original.id);
      expect(decoded.filePath, original.filePath);
      expect(decoded.transcriptText, original.transcriptText);
      expect(decoded.summaryText, original.summaryText);
      expect(decoded.transcriptionStatus, original.transcriptionStatus);
      expect(decoded.transcriptionRetryCount, original.transcriptionRetryCount);
      expect(decoded.transcriptionCompletedAt, original.transcriptionCompletedAt);
    });

    test('handles failed status with error message', () {
      final recording = Recording(
        id: 'test-id',
        filePath: '/path/to/file.m4a',
        createdAt: DateTime(2024, 1, 1, 12, 0),
        duration: const Duration(minutes: 5),
        transcriptionStatus: TranscriptionStatus.failed,
        transcriptionError: '음성 인식에 실패했습니다.',
        transcriptionRetryCount: 3,
      );

      final map = recording.toMap();
      final reconstructed = Recording.fromMap(map);

      expect(reconstructed.transcriptionStatus, TranscriptionStatus.failed);
      expect(reconstructed.transcriptionError, '음성 인식에 실패했습니다.');
      expect(reconstructed.transcriptionRetryCount, 3);
    });
  });
}

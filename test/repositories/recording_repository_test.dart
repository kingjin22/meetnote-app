import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetnote_app/models/recording.dart';
import 'package:meetnote_app/repositories/local_recording_repository.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocalRecordingRepository - Transcription Status Persistence', () {
    late LocalRecordingRepository repository;
    late Directory tempDir;
    final createdFiles = <File>[];

    setUp(() async {
      repository = LocalRecordingRepository();
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('recording_test_');
    });

    tearDown(() async {
      for (final file in createdFiles) {
        if (await file.exists()) {
          await file.delete();
        }
      }
      createdFiles.clear();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<String> _createTestFile(String name) async {
      final file = File(path.join(tempDir.path, name));
      await file.writeAsString('test audio data');
      createdFiles.add(file);
      return file.path;
    }

    test('persists transcription status when adding recording', () async {
      final filePath = await _createTestFile('test1.m4a');
      final recording = Recording(
        id: 'test-1',
        filePath: filePath,
        createdAt: DateTime.now(),
        duration: const Duration(minutes: 5),
        transcriptionStatus: TranscriptionStatus.pending,
        transcriptionRetryCount: 1,
      );

      await repository.add(recording);

      final retrieved = await repository.getById('test-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.transcriptionStatus, TranscriptionStatus.pending);
      expect(retrieved.transcriptionRetryCount, 1);
    });

    test('persists transcription status when updating recording', () async {
      // 초기 녹음 추가
      final filePath = await _createTestFile('test2.m4a');
      final initial = Recording(
        id: 'test-2',
        filePath: filePath,
        createdAt: DateTime.now(),
        duration: const Duration(minutes: 3),
        transcriptionStatus: TranscriptionStatus.none,
      );

      await repository.add(initial);

      // pending 상태로 업데이트
      final pending = initial.copyWith(
        transcriptionStatus: TranscriptionStatus.pending,
      );
      await repository.update(pending);

      final retrieved1 = await repository.getById('test-2');
      expect(retrieved1!.transcriptionStatus, TranscriptionStatus.pending);

      // success 상태로 업데이트
      final success = pending.copyWith(
        transcriptionStatus: TranscriptionStatus.success,
        transcriptText: 'Test transcript',
        transcriptionCompletedAt: DateTime.now(),
      );
      await repository.update(success);

      final retrieved2 = await repository.getById('test-2');
      expect(retrieved2!.transcriptionStatus, TranscriptionStatus.success);
      expect(retrieved2.transcriptText, 'Test transcript');
      expect(retrieved2.transcriptionCompletedAt, isNotNull);
    });

    test('persists failed status with error message', () async {
      final filePath = await _createTestFile('test3.m4a');
      final recording = Recording(
        id: 'test-3',
        filePath: filePath,
        createdAt: DateTime.now(),
        duration: const Duration(minutes: 2),
        transcriptionStatus: TranscriptionStatus.failed,
        transcriptionError: '음성 인식 실패',
        transcriptionRetryCount: 2,
      );

      await repository.add(recording);

      final retrieved = await repository.getById('test-3');

      expect(retrieved, isNotNull);
      expect(retrieved!.transcriptionStatus, TranscriptionStatus.failed);
      expect(retrieved.transcriptionError, '음성 인식 실패');
      expect(retrieved.transcriptionRetryCount, 2);
    });

    test('handles migration from old data format', () async {
      // 구 버전 데이터 형식 (transcription 필드 없음)
      final filePath = await _createTestFile('old.m4a');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'recordings_v2',
        '[{"id":"old-1","filePath":"$filePath","createdAtMs":1704067200000,"durationMs":180000,"transcriptText":"Old transcript","summaryText":"Old summary"}]',
      );

      final recordings = await repository.list();

      expect(recordings.length, 1);
      expect(recordings[0].id, 'old-1');
      expect(recordings[0].transcriptText, 'Old transcript');
      // 기본값으로 설정되어야 함
      expect(recordings[0].transcriptionStatus, TranscriptionStatus.none);
      expect(recordings[0].transcriptionRetryCount, 0);
      expect(recordings[0].transcriptionError, null);
    });

    test('clears transcription error when updated with clearTranscriptionError', () async {
      final filePath = await _createTestFile('test4.m4a');
      final recording = Recording(
        id: 'test-4',
        filePath: filePath,
        createdAt: DateTime.now(),
        duration: const Duration(minutes: 4),
        transcriptionStatus: TranscriptionStatus.failed,
        transcriptionError: 'Previous error',
        transcriptionRetryCount: 1,
      );

      await repository.add(recording);

      // 에러를 제거하고 재시도
      final retry = recording.copyWith(
        transcriptionStatus: TranscriptionStatus.pending,
        transcriptionRetryCount: 2,
        clearTranscriptionError: true,
      );
      await repository.update(retry);

      final retrieved = await repository.getById('test-4');

      expect(retrieved!.transcriptionStatus, TranscriptionStatus.pending);
      expect(retrieved.transcriptionError, null);
      expect(retrieved.transcriptionRetryCount, 2);
    });

    test('lists recordings with different transcription statuses', () async {
      final recordings = [
        Recording(
          id: 'rec-1',
          filePath: await _createTestFile('rec1.m4a'),
          createdAt: DateTime.now(),
          duration: const Duration(minutes: 1),
          transcriptionStatus: TranscriptionStatus.none,
        ),
        Recording(
          id: 'rec-2',
          filePath: await _createTestFile('rec2.m4a'),
          createdAt: DateTime.now(),
          duration: const Duration(minutes: 2),
          transcriptionStatus: TranscriptionStatus.pending,
        ),
        Recording(
          id: 'rec-3',
          filePath: await _createTestFile('rec3.m4a'),
          createdAt: DateTime.now(),
          duration: const Duration(minutes: 3),
          transcriptionStatus: TranscriptionStatus.success,
          transcriptText: 'Success transcript',
        ),
        Recording(
          id: 'rec-4',
          filePath: await _createTestFile('rec4.m4a'),
          createdAt: DateTime.now(),
          duration: const Duration(minutes: 4),
          transcriptionStatus: TranscriptionStatus.failed,
          transcriptionError: 'Failed',
        ),
      ];

      for (final rec in recordings) {
        await repository.add(rec);
      }

      final retrieved = await repository.list();

      // 역순으로 반환됨
      expect(retrieved.length, 4);
      expect(retrieved[0].id, 'rec-4');
      expect(retrieved[0].transcriptionStatus, TranscriptionStatus.failed);
      expect(retrieved[1].id, 'rec-3');
      expect(retrieved[1].transcriptionStatus, TranscriptionStatus.success);
      expect(retrieved[2].id, 'rec-2');
      expect(retrieved[2].transcriptionStatus, TranscriptionStatus.pending);
      expect(retrieved[3].id, 'rec-1');
      expect(retrieved[3].transcriptionStatus, TranscriptionStatus.none);
    });

    test('can filter pending recordings for retry on app restart', () async {
      // 여러 상태의 녹음 추가
      final recordings = [
        Recording(
          id: 'normal',
          filePath: await _createTestFile('normal.m4a'),
          createdAt: DateTime.now(),
          duration: const Duration(minutes: 1),
          transcriptionStatus: TranscriptionStatus.none,
        ),
        Recording(
          id: 'pending-1',
          filePath: await _createTestFile('pending1.m4a'),
          createdAt: DateTime.now(),
          duration: const Duration(minutes: 2),
          transcriptionStatus: TranscriptionStatus.pending,
        ),
        Recording(
          id: 'pending-2',
          filePath: await _createTestFile('pending2.m4a'),
          createdAt: DateTime.now(),
          duration: const Duration(minutes: 3),
          transcriptionStatus: TranscriptionStatus.pending,
        ),
        Recording(
          id: 'success',
          filePath: await _createTestFile('success.m4a'),
          createdAt: DateTime.now(),
          duration: const Duration(minutes: 4),
          transcriptionStatus: TranscriptionStatus.success,
          transcriptText: 'Done',
        ),
      ];

      for (final rec in recordings) {
        await repository.add(rec);
      }

      // pending 상태 필터링
      final allRecordings = await repository.list();
      final pendingRecordings = allRecordings
          .where((r) => r.transcriptionStatus == TranscriptionStatus.pending)
          .toList();

      expect(pendingRecordings.length, 2);
      expect(pendingRecordings.any((r) => r.id == 'pending-1'), true);
      expect(pendingRecordings.any((r) => r.id == 'pending-2'), true);

      // pending을 failed로 변경 (앱 재시작 시나리오)
      for (final pending in pendingRecordings) {
        final updated = pending.copyWith(
          transcriptionStatus: TranscriptionStatus.failed,
          transcriptionError: '앱이 종료되어 변환이 중단되었습니다.',
          transcriptionRetryCount: pending.transcriptionRetryCount + 1,
        );
        await repository.update(updated);
      }

      // 검증
      final afterUpdate = await repository.list();
      final stillPending = afterUpdate
          .where((r) => r.transcriptionStatus == TranscriptionStatus.pending)
          .toList();
      final nowFailed = afterUpdate
          .where((r) => r.transcriptionStatus == TranscriptionStatus.failed)
          .toList();

      expect(stillPending.length, 0);
      expect(nowFailed.length, 2);

      final failed1 = await repository.getById('pending-1');
      expect(failed1!.transcriptionStatus, TranscriptionStatus.failed);
      expect(failed1.transcriptionError, '앱이 종료되어 변환이 중단되었습니다.');
      expect(failed1.transcriptionRetryCount, 1);
    });
  });
}

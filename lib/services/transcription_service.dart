import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class TranscriptionProgress {
  final int totalChunks;
  final int completedChunks;
  final int currentChunk;
  final double percentage;

  TranscriptionProgress({
    required this.totalChunks,
    required this.completedChunks,
    required this.currentChunk,
    required this.percentage,
  });

  factory TranscriptionProgress.fromMap(Map<dynamic, dynamic> map) {
    return TranscriptionProgress(
      totalChunks: map['totalChunks'] as int,
      completedChunks: map['completedChunks'] as int,
      currentChunk: map['currentChunk'] as int,
      percentage: (map['percentage'] as num).toDouble(),
    );
  }
}

class TranscriptionService {
  static const MethodChannel _channel = MethodChannel('meetnote/transcription');
  static const EventChannel _progressChannel = EventChannel('meetnote/transcription_progress');
  
  Stream<TranscriptionProgress>? _progressStream;

  Stream<TranscriptionProgress> get progressStream {
    _progressStream ??= _progressChannel
        .receiveBroadcastStream()
        .map((event) => TranscriptionProgress.fromMap(event as Map<dynamic, dynamic>));
    return _progressStream!;
  }

  Future<String> transcribeFileWithRetry(
    String filePath, {
    String locale = 'ko-KR',
    bool allowOnlineFallback = true,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 10), // 타임아웃 추가
    void Function(TranscriptionProgress)? onProgress,
  }) async {
    int attemptCount = 0;
    PlatformException? lastError;
    
    // 진행률 스트림 구독
    StreamSubscription<TranscriptionProgress>? progressSubscription;
    if (onProgress != null) {
      progressSubscription = progressStream.listen(onProgress);
    }

    try {
      while (attemptCount < maxRetries) {
        try {
          final result = await transcribeFile(
            filePath,
            locale: locale,
            allowOnlineFallback: allowOnlineFallback,
            timeout: timeout,
          );
          return result;
        } on PlatformException catch (e) {
          lastError = e;
          attemptCount++;

          // 재시도 불가능한 에러는 즉시 throw
          if (_isNonRetriableError(e.code)) {
            rethrow;
          }

          // 마지막 시도가 아니면 대기 후 재시도
          if (attemptCount < maxRetries) {
            final delay = retryDelay * attemptCount; // 지수 백오프
            print('⚠️ Transcription attempt $attemptCount failed, retrying in ${delay.inSeconds}s...');
            await Future<void>.delayed(delay);
          }
        } on TimeoutException catch (e) {
          lastError = PlatformException(
            code: 'timeout',
            message: e.message ?? '텍스트 변환 시간이 초과되었어요.',
          );
          attemptCount++;

          // 타임아웃은 재시도
          if (attemptCount < maxRetries) {
            final delay = retryDelay * attemptCount;
            print('⚠️ Transcription timeout, retrying in ${delay.inSeconds}s...');
            await Future<void>.delayed(delay);
          }
        }
      }

      // 모든 재시도 실패
      throw lastError ?? PlatformException(
        code: 'max_retries_exceeded',
        message: '최대 재시도 횟수를 초과했습니다.',
      );
    } finally {
      // 구독 해제
      await progressSubscription?.cancel();
    }
  }

  bool _isNonRetriableError(String code) {
    // 재시도해도 소용없는 에러들
    return const [
      'unsupported_platform',
      'file_missing',
      'speech_denied',
      'offline_unavailable',
      'empty_transcript',
      // timeout은 재시도 가능하므로 제외
    ].contains(code);
  }

  Future<String> transcribeFile(
    String filePath, {
    String locale = 'ko-KR',
    bool allowOnlineFallback = true,
    Duration timeout = const Duration(minutes: 10), // 타임아웃 추가
  }) async {
    if (!Platform.isIOS) {
      throw PlatformException(
        code: 'unsupported_platform',
        message: 'iOS에서만 텍스트 변환을 지원합니다.',
      );
    }

    final file = File(filePath);
    final exists = await file.exists();
    if (!exists) {
      throw PlatformException(
        code: 'file_missing',
        message: '오디오 파일을 찾을 수 없어요.',
      );
    }

    try {
      // 타임아웃 적용
      final text = await _channel.invokeMethod<String>('transcribeFile', {
        'path': filePath,
        'locale': locale,
        'allowOnlineFallback': allowOnlineFallback,
      }).timeout(
        timeout,
        onTimeout: () {
          throw PlatformException(
            code: 'timeout',
            message: '텍스트 변환 시간이 초과되었어요. 파일이 너무 크거나 네트워크 상태를 확인해주세요.',
          );
        },
      );

      if (text == null || text.trim().isEmpty) {
        throw PlatformException(
          code: 'empty_transcript',
          message: '텍스트 변환 결과가 비어 있어요.',
        );
      }

      return text.trim();
    } on PlatformException catch (error) {
      if (error.code == 'empty_transcript' || error.code == 'timeout') {
        rethrow;
      }
      throw PlatformException(
        code: error.code,
        message: error.message ?? '텍스트 변환 중 오류가 발생했어요.',
      );
    } on TimeoutException {
      throw PlatformException(
        code: 'timeout',
        message: '텍스트 변환 시간이 초과되었어요. 파일이 너무 크거나 네트워크 상태를 확인해주세요.',
      );
    }
  }
}

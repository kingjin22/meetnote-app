import 'dart:io';

import 'package:flutter/services.dart';

class TranscriptionService {
  static const MethodChannel _channel = MethodChannel('meetnote/transcription');

  Future<String> transcribeFileWithRetry(
    String filePath, {
    String locale = 'ko-KR',
    bool allowOnlineFallback = true,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int attemptCount = 0;
    PlatformException? lastError;

    while (attemptCount < maxRetries) {
      try {
        return await transcribeFile(
          filePath,
          locale: locale,
          allowOnlineFallback: allowOnlineFallback,
        );
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
          await Future<void>.delayed(delay);
        }
      }
    }

    // 모든 재시도 실패
    throw lastError ?? PlatformException(
      code: 'max_retries_exceeded',
      message: '최대 재시도 횟수를 초과했습니다.',
    );
  }

  bool _isNonRetriableError(String code) {
    // 재시도해도 소용없는 에러들
    return const [
      'unsupported_platform',
      'file_missing',
      'speech_denied',
      'offline_unavailable',
      'empty_transcript',
    ].contains(code);
  }

  Future<String> transcribeFile(
    String filePath, {
    String locale = 'ko-KR',
    bool allowOnlineFallback = true,
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
      final text = await _channel.invokeMethod<String>('transcribeFile', {
        'path': filePath,
        'locale': locale,
        'allowOnlineFallback': allowOnlineFallback,
      });

      if (text == null || text.trim().isEmpty) {
        throw PlatformException(
          code: 'empty_transcript',
          message: '텍스트 변환 결과가 비어 있어요.',
        );
      }

      return text.trim();
    } on PlatformException catch (error) {
      if (error.code == 'empty_transcript') {
        throw PlatformException(
          code: error.code,
          message: error.message ?? '텍스트 변환 결과가 비어 있어요.',
        );
      }
      rethrow;
    }
  }
}

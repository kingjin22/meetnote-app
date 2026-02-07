import 'dart:io';

import 'package:flutter/services.dart';

class TranscriptionService {
  static const MethodChannel _channel = MethodChannel('meetnote/transcription');

  Future<String> transcribeFile(String filePath) async {
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

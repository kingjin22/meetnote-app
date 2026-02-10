import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder;

  AudioRecorderService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  Future<bool> get isRecording => _recorder.isRecording();
  
  Future<bool> get isPaused => _recorder.isPaused();

  Future<String> start() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final now = DateTime.now();
      final fileName =
          'rec_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}.m4a';
      final path = '${recordingsDir.path}/$fileName';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      return path;
    } catch (e) {
      throw AudioRecorderException('녹음을 시작할 수 없습니다: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _recorder.pause();
    } catch (e) {
      throw AudioRecorderException('녹음을 일시정지할 수 없습니다: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _recorder.resume();
    } catch (e) {
      throw AudioRecorderException('녹음을 재개할 수 없습니다: $e');
    }
  }

  Future<String?> stop() async {
    try {
      return await _recorder.stop();
    } catch (e) {
      throw AudioRecorderException('녹음을 정지할 수 없습니다: $e');
    }
  }

  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } catch (e) {
      throw AudioRecorderException('녹음을 취소할 수 없습니다: $e');
    }
  }

  Future<void> dispose() => _recorder.dispose();

  String _two(int n) => n.toString().padLeft(2, '0');
}

class AudioRecorderException implements Exception {
  final String message;
  
  AudioRecorderException(this.message);
  
  @override
  String toString() => message;
}

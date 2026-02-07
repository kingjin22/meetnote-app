import 'dart:io';

import 'package:path_provider/path_provider.dart';

class RecordingImportException implements Exception {
  final String message;
  const RecordingImportException(this.message);

  @override
  String toString() => 'RecordingImportException: $message';
}

class RecordingImportResult {
  final String filePath;
  final String fileName;

  const RecordingImportResult({required this.filePath, required this.fileName});
}

class RecordingImportService {
  static const Set<String> supportedExtensions = {
    'm4a',
    'mp3',
    'wav',
    'aac',
    'caf',
    'flac',
    'ogg',
  };

  final Future<Directory> Function() _documentsDirProvider;
  final DateTime Function() _now;

  RecordingImportService({
    Future<Directory> Function()? documentsDirProvider,
    DateTime Function()? now,
  }) : _documentsDirProvider =
           documentsDirProvider ?? getApplicationDocumentsDirectory,
       _now = now ?? DateTime.now;

  Future<RecordingImportResult> importFromPath({
    required String sourcePath,
    required String originalName,
  }) async {
    if (sourcePath.isEmpty) {
      throw const RecordingImportException('파일 경로를 찾을 수 없어요.');
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw const RecordingImportException('선택한 파일에 접근할 수 없어요.');
    }

    final ext = _extensionOf(originalName);
    if (ext == null || !supportedExtensions.contains(ext.toLowerCase())) {
      throw RecordingImportException('지원하지 않는 파일 형식이에요: ${ext ?? 'unknown'}');
    }

    final docsDir = await _documentsDirProvider();
    final recordingsDir = Directory('${docsDir.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final safeName = _sanitizeFileName(originalName);
    final timestamp = _now().millisecondsSinceEpoch;
    final destName = 'imported_${timestamp}_$safeName';
    final destPath = '${recordingsDir.path}/$destName';

    try {
      final copied = await sourceFile.copy(destPath);
      return RecordingImportResult(filePath: copied.path, fileName: destName);
    } catch (_) {
      throw const RecordingImportException('파일을 복사하지 못했어요.');
    }
  }

  String? _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1);
  }

  String _sanitizeFileName(String input) {
    // Basic sanitization to avoid path traversal / separators.
    var s = input.replaceAll('/', '_').replaceAll('\\', '_');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return 'audio.m4a';
    return s;
  }
}

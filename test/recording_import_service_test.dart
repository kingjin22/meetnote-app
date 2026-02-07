import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetnote_app/services/recording_import_service.dart';

void main() {
  test('RecordingImportService copies file into recordings dir', () async {
    final temp = await Directory.systemTemp.createTemp('meetnote_import_test_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    final sourceDir = Directory('${temp.path}/source');
    await sourceDir.create(recursive: true);

    final sourceFile = File('${sourceDir.path}/hello.m4a');
    await sourceFile.writeAsBytes([0, 1, 2, 3]);

    final service = RecordingImportService(
      documentsDirProvider: () async => temp,
      now: () => DateTime.fromMillisecondsSinceEpoch(1710000000000),
    );

    final result = await service.importFromPath(
      sourcePath: sourceFile.path,
      originalName: 'hello.m4a',
    );

    expect(result.fileName, startsWith('imported_1710000000000_'));
    expect(result.fileName, endsWith('hello.m4a'));
    expect(result.filePath, contains('/recordings/'));
    expect(await File(result.filePath).exists(), isTrue);
  });

  test('RecordingImportService rejects unsupported extension', () async {
    final temp = await Directory.systemTemp.createTemp('meetnote_import_test_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    final sourceFile = File('${temp.path}/bad.txt');
    await sourceFile.writeAsString('nope');

    final service = RecordingImportService(
      documentsDirProvider: () async => temp,
    );

    expect(
      () => service.importFromPath(
        sourcePath: sourceFile.path,
        originalName: 'bad.txt',
      ),
      throwsA(isA<RecordingImportException>()),
    );
  });
}

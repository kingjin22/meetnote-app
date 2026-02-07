import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meetnote_app/widgets/transcription_progress_banner.dart';

void main() {
  testWidgets('TranscriptionProgressBanner shows label and progress', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TranscriptionProgressBanner(activeCount: 1),
        ),
      ),
    );

    expect(find.text('텍스트 변환 중이에요.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}

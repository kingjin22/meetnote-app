class MeetingSummaryPrompt {
  static const String systemPrompt = '''
당신은 전문 회의록 작성자입니다. 
회의 내용을 분석하여 명확하고 구조화된 회의록을 작성합니다.
항상 JSON 형식으로 응답해주세요.
''';

  static String createUserPrompt(String transcriptText) {
    return '''
아래 회의 내용을 분석하여 구조화된 회의록을 작성해주세요.

[회의 텍스트]
$transcriptText

다음 JSON 형식으로 정리해주세요:
{
  "overview": "회의 주제, 참석자, 일시 등을 포함한 개요 (문단 형식)",
  "discussions": ["주요 논의 사항 1", "주요 논의 사항 2", ...],
  "decisions": ["결정 사항 1", "결정 사항 2", ...],
  "actionItems": [
    {
      "task": "할 일 설명",
      "assignee": "담당자 이름 (없으면 null)",
      "deadline": "YYYY-MM-DD 형식의 기한 (없으면 null)"
    }
  ],
  "nextMeeting": "다음 회의 일정 (없으면 null)"
}

참고 사항:
- 회의록은 한국어로 작성해주세요
- 실제 언급된 내용만 포함하고, 추측하지 마세요
- 명확하지 않은 부분은 생략하거나 "명확하지 않음"으로 표시하세요
- discussions와 decisions는 비어있을 수 있습니다
- 반드시 유효한 JSON 형식으로만 응답해주세요
''';
  }

  static String createSimplifiedPrompt(String transcriptText) {
    return '''
다음 회의 내용을 요약해주세요:

$transcriptText

JSON 형식으로 응답:
{
  "overview": "회의 요약",
  "discussions": [],
  "decisions": [],
  "actionItems": [],
  "nextMeeting": null
}
''';
  }
}

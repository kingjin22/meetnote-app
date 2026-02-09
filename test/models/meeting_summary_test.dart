import 'package:flutter_test/flutter_test.dart';
import 'package:meetnote_app/models/meeting_summary.dart';

void main() {
  group('ActionItem', () {
    test('toMap and fromMap should work correctly', () {
      final actionItem = ActionItem(
        task: 'Complete feature implementation',
        assignee: 'John Doe',
        deadline: DateTime(2024, 12, 31),
      );

      final map = actionItem.toMap();
      final restored = ActionItem.fromMap(map);

      expect(restored.task, actionItem.task);
      expect(restored.assignee, actionItem.assignee);
      expect(restored.deadline, actionItem.deadline);
    });

    test('toJson and fromJson should work correctly', () {
      final actionItem = ActionItem(
        task: 'Review code',
        assignee: null,
        deadline: null,
      );

      final json = actionItem.toJson();
      final restored = ActionItem.fromJson(json);

      expect(restored.task, actionItem.task);
      expect(restored.assignee, isNull);
      expect(restored.deadline, isNull);
    });
  });

  group('MeetingSummary', () {
    test('toMap and fromMap should work correctly', () {
      final now = DateTime.now();
      final summary = MeetingSummary(
        overview: 'Team meeting to discuss Q4 goals',
        discussions: ['Budget planning', 'Timeline review'],
        decisions: ['Hire two new developers', 'Launch in Q1'],
        actionItems: [
          ActionItem(
            task: 'Prepare hiring plan',
            assignee: 'HR Manager',
            deadline: DateTime(2024, 11, 30),
          ),
        ],
        nextMeeting: '2024-12-01 10:00',
        createdAt: now,
      );

      final map = summary.toMap();
      final restored = MeetingSummary.fromMap(map);

      expect(restored.overview, summary.overview);
      expect(restored.discussions.length, 2);
      expect(restored.decisions.length, 2);
      expect(restored.actionItems.length, 1);
      expect(restored.actionItems.first.task, 'Prepare hiring plan');
      expect(restored.nextMeeting, summary.nextMeeting);
    });

    test('toPlainText should generate readable text', () {
      final summary = MeetingSummary(
        overview: 'Sprint planning meeting',
        discussions: ['Feature A discussion', 'Bug fixes priority'],
        decisions: ['Prioritize feature A'],
        actionItems: [
          ActionItem(
            task: 'Design mockups',
            assignee: 'Designer',
            deadline: DateTime(2024, 11, 15),
          ),
        ],
        nextMeeting: null,
        createdAt: DateTime.now(),
      );

      final text = summary.toPlainText();

      expect(text, contains('# 회의록'));
      expect(text, contains('## 회의 개요'));
      expect(text, contains('Sprint planning meeting'));
      expect(text, contains('## 주요 논의 사항'));
      expect(text, contains('Feature A discussion'));
      expect(text, contains('## 결정 사항'));
      expect(text, contains('Prioritize feature A'));
      expect(text, contains('## 액션 아이템'));
      expect(text, contains('Design mockups'));
      expect(text, contains('담당: Designer'));
    });

    test('toPlainText should handle empty sections', () {
      final summary = MeetingSummary(
        overview: 'Simple meeting',
        discussions: [],
        decisions: [],
        actionItems: [],
        nextMeeting: null,
        createdAt: DateTime.now(),
      );

      final text = summary.toPlainText();

      expect(text, contains('# 회의록'));
      expect(text, contains('Simple meeting'));
      expect(text, isNot(contains('## 주요 논의 사항')));
      expect(text, isNot(contains('## 결정 사항')));
      expect(text, isNot(contains('## 액션 아이템')));
      expect(text, isNot(contains('## 다음 회의 일정')));
    });
  });
}

import 'dart:convert';

class ActionItem {
  final String task;
  final String? assignee;
  final DateTime? deadline;

  const ActionItem({
    required this.task,
    this.assignee,
    this.deadline,
  });

  Map<String, dynamic> toMap() {
    return {
      'task': task,
      'assignee': assignee,
      'deadline': deadline?.toIso8601String(),
    };
  }

  factory ActionItem.fromMap(Map<String, dynamic> map) {
    return ActionItem(
      task: map['task'] as String,
      assignee: map['assignee'] as String?,
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ActionItem.fromJson(String json) {
    return ActionItem.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }
}

class MeetingSummary {
  final String overview;
  final List<String> discussions;
  final List<String> decisions;
  final List<ActionItem> actionItems;
  final String? nextMeeting;
  final DateTime createdAt;

  const MeetingSummary({
    required this.overview,
    required this.discussions,
    required this.decisions,
    required this.actionItems,
    this.nextMeeting,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'overview': overview,
      'discussions': discussions,
      'decisions': decisions,
      'actionItems': actionItems.map((x) => x.toMap()).toList(),
      'nextMeeting': nextMeeting,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MeetingSummary.fromMap(Map<String, dynamic> map) {
    return MeetingSummary(
      overview: map['overview'] as String,
      discussions: List<String>.from(map['discussions'] as List),
      decisions: List<String>.from(map['decisions'] as List),
      actionItems: (map['actionItems'] as List)
          .map((x) => ActionItem.fromMap(x as Map<String, dynamic>))
          .toList(),
      nextMeeting: map['nextMeeting'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MeetingSummary.fromJson(String json) {
    return MeetingSummary.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Convert to plain text format
  String toPlainText() {
    final buffer = StringBuffer();
    
    buffer.writeln('# 회의록\n');
    buffer.writeln('## 회의 개요');
    buffer.writeln(overview);
    buffer.writeln();

    if (discussions.isNotEmpty) {
      buffer.writeln('## 주요 논의 사항');
      for (var i = 0; i < discussions.length; i++) {
        buffer.writeln('${i + 1}. ${discussions[i]}');
      }
      buffer.writeln();
    }

    if (decisions.isNotEmpty) {
      buffer.writeln('## 결정 사항');
      for (var i = 0; i < decisions.length; i++) {
        buffer.writeln('${i + 1}. ${decisions[i]}');
      }
      buffer.writeln();
    }

    if (actionItems.isNotEmpty) {
      buffer.writeln('## 액션 아이템');
      for (var i = 0; i < actionItems.length; i++) {
        final item = actionItems[i];
        buffer.write('${i + 1}. ${item.task}');
        if (item.assignee != null) {
          buffer.write(' (담당: ${item.assignee})');
        }
        if (item.deadline != null) {
          buffer.write(' [기한: ${item.deadline!.year}-${item.deadline!.month.toString().padLeft(2, '0')}-${item.deadline!.day.toString().padLeft(2, '0')}]');
        }
        buffer.writeln();
      }
      buffer.writeln();
    }

    if (nextMeeting != null) {
      buffer.writeln('## 다음 회의 일정');
      buffer.writeln(nextMeeting);
    }

    return buffer.toString();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/meeting_summary.dart';
import '../models/recording.dart';
import '../services/llm_service.dart';
import '../repositories/recording_repository.dart';

class MeetingSummaryScreen extends StatefulWidget {
  final Recording recording;
  final RecordingRepository repository;

  const MeetingSummaryScreen({
    super.key,
    required this.recording,
    required this.repository,
  });

  @override
  State<MeetingSummaryScreen> createState() => _MeetingSummaryScreenState();
}

class _MeetingSummaryScreenState extends State<MeetingSummaryScreen> {
  final LLMService _llmService = LLMService();
  MeetingSummary? _summary;
  bool _isGenerating = false;
  bool _isEditing = false;
  String? _error;
  LLMProvider _selectedProvider = LLMProvider.claude;

  final TextEditingController _overviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingSummary();
  }

  @override
  void dispose() {
    _overviewController.dispose();
    super.dispose();
  }

  void _loadExistingSummary() {
    if (widget.recording.summaryText != null) {
      try {
        final summary = MeetingSummary.fromJson(widget.recording.summaryText!);
        setState(() {
          _summary = summary;
          _overviewController.text = summary.overview;
        });
      } catch (e) {
        // Invalid JSON, ignore
      }
    }
  }

  Future<void> _generateSummary() async {
    if (widget.recording.transcriptText == null ||
        widget.recording.transcriptText!.isEmpty) {
      setState(() {
        _error = '텍스트 변환이 완료되지 않았습니다.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final summary = await _llmService.generateSummaryWithRetry(
        widget.recording.transcriptText!,
        provider: _selectedProvider,
      );

      final updatedRecording = widget.recording.copyWith(
        summaryText: summary.toJson(),
      );
      await widget.repository.update(updatedRecording);

      if (mounted) {
        setState(() {
          _summary = summary;
          _overviewController.text = summary.overview;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isGenerating = false;
        });
      }
    }
  }

  void _copyToClipboard() {
    if (_summary != null) {
      Clipboard.setData(ClipboardData(text: _summary!.toPlainText()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회의록이 클립보드에 복사되었습니다')),
      );
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회의록'),
        actions: [
          if (_summary != null) ...[
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: _toggleEdit,
              tooltip: _isEditing ? '완료' : '편집',
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyToClipboard,
              tooltip: '복사',
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isGenerating) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '회의록 생성 중...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedProvider.name} 사용',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                '오류 발생',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _generateSummary,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_summary == null) {
      return _buildGeneratePrompt();
    }

    return _buildSummaryView();
  }

  Widget _buildGeneratePrompt() {
    final cost = _llmService.estimateCost(
      widget.recording.transcriptText ?? '',
      provider: _selectedProvider,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'AI 회의록 생성',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '텍스트 변환이 완료되었습니다.\n회의록을 자동으로 생성하시겠습니까?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _buildProviderSelector(),
            const SizedBox(height: 16),
            Text(
              '예상 비용: \$${cost['totalCost']!.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '토큰 수: ${cost['inputTokens']!.toInt()} (입력)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateSummary,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('회의록 생성'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelector() {
    return SegmentedButton<LLMProvider>(
      segments: const [
        ButtonSegment(
          value: LLMProvider.claude,
          label: Text('Claude'),
          icon: Icon(Icons.psychology),
        ),
        ButtonSegment(
          value: LLMProvider.openai,
          label: Text('GPT'),
          icon: Icon(Icons.smart_toy),
        ),
      ],
      selected: {_selectedProvider},
      onSelectionChanged: (Set<LLMProvider> selected) {
        setState(() {
          _selectedProvider = selected.first;
        });
      },
    );
  }

  Widget _buildSummaryView() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSection(
          '회의 개요',
          Icons.info_outline,
          [
            _isEditing
                ? TextField(
                    controller: _overviewController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  )
                : Text(_summary!.overview),
          ],
        ),
        if (_summary!.discussions.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSection(
            '주요 논의 사항',
            Icons.forum,
            _summary!.discussions
                .asMap()
                .entries
                .map((e) => _buildListItem('${e.key + 1}. ${e.value}'))
                .toList(),
          ),
        ],
        if (_summary!.decisions.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSection(
            '결정 사항',
            Icons.check_circle_outline,
            _summary!.decisions
                .asMap()
                .entries
                .map((e) => _buildListItem('${e.key + 1}. ${e.value}'))
                .toList(),
          ),
        ],
        if (_summary!.actionItems.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSection(
            '액션 아이템',
            Icons.task_alt,
            _summary!.actionItems
                .asMap()
                .entries
                .map((e) => _buildActionItem(e.key + 1, e.value))
                .toList(),
          ),
        ],
        if (_summary!.nextMeeting != null) ...[
          const SizedBox(height: 24),
          _buildSection(
            '다음 회의 일정',
            Icons.calendar_today,
            [Text(_summary!.nextMeeting!)],
          ),
        ],
        const SizedBox(height: 16),
        _buildMetadata(),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text),
    );
  }

  Widget _buildActionItem(int index, ActionItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$index. ${item.task}'),
          const SizedBox(height: 4),
          Row(
            children: [
              if (item.assignee != null) ...[
                Chip(
                  label: Text('담당: ${item.assignee}'),
                  avatar: const Icon(Icons.person, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
              if (item.deadline != null)
                Chip(
                  label: Text(
                    '기한: ${item.deadline!.year}-${item.deadline!.month.toString().padLeft(2, '0')}-${item.deadline!.day.toString().padLeft(2, '0')}',
                  ),
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '생성 시간: ${_formatDateTime(_summary!.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

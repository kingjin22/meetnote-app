import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../models/recording.dart';
import '../models/recording_result.dart';
import '../repositories/local_recording_repository.dart';
import '../services/audio_playback_controller.dart';
import '../services/recording_import_service.dart';
import '../services/transcription_service.dart';
import '../widgets/transcription_progress_banner.dart';
import 'recording_screen.dart';
import 'meeting_summary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = LocalRecordingRepository();
  final _playback = AudioPlaybackController();
  final _importService = RecordingImportService();
  final _transcriptionService = TranscriptionService();

  List<Recording> _recordings = [];
  final Set<String> _transcribingIds = {};
  bool _progressDialogVisible = false;
  
  // 진행률 상태
  double? _transcriptionProgress;
  int? _currentChunk;
  int? _totalChunks;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_retryPendingTranscriptions());
  }

  Future<void> _load() async {
    final items = await _repo.list();
    if (!mounted) return;
    setState(() {
      _recordings = items;
    });
  }

  /// 앱 시작 시 pending 상태인 녹음을 자동으로 재시도
  Future<void> _retryPendingTranscriptions() async {
    // 데이터 로드 대기
    await Future<void>.delayed(const Duration(milliseconds: 500));
    
    final recordings = await _repo.list();
    final pendingRecordings = recordings.where(
      (r) => r.transcriptionStatus == TranscriptionStatus.pending,
    ).toList();

    if (pendingRecordings.isEmpty) return;

    // pending 상태를 failed로 변경하고 재시도 카운트 증가
    for (final recording in pendingRecordings) {
      final updated = recording.copyWith(
        transcriptionStatus: TranscriptionStatus.failed,
        transcriptionError: '앱이 종료되어 변환이 중단되었습니다.',
        transcriptionRetryCount: recording.transcriptionRetryCount + 1,
      );
      await _repo.update(updated);
    }

    await _load();

    if (!mounted) return;

    // 사용자에게 알림
    if (pendingRecordings.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('중단된 텍스트 변환이 ${pendingRecordings.length}개 있어요. 다시 시도해주세요.'),
          action: SnackBarAction(
            label: '확인',
            onPressed: () {},
          ),
        ),
      );
    } else if (pendingRecordings.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('중단된 텍스트 변환이 ${pendingRecordings.length}개 있어요. 다시 시도해주세요.'),
          action: SnackBarAction(
            label: '확인',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MemoNote'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 설정 화면
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_transcribingIds.isNotEmpty)
            TranscriptionProgressBanner(
              activeCount: _transcribingIds.length,
              progress: _transcriptionProgress,
              currentChunk: _currentChunk,
              totalChunks: _totalChunks,
            ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: MdiIcons.microphone,
                  label: '총 녹음',
                  value: '${_recordings.length}',
                ),
                _buildStatItem(
                  icon: MdiIcons.clock,
                  label: '이번 주',
                  value: '${_getWeeklyCount()}',
                ),
                _buildStatItem(
                  icon: MdiIcons.fileDocument,
                  label: '회의록',
                  value: '${_getSummaryCount()}',
                ),
              ],
            ),
          ),
          Expanded(
            child: _recordings.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _recordings.length,
                    itemBuilder: (context, index) {
                      final recording = _recordings[index];
                      return _buildRecordingCard(recording);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _onNewRecordingPressed,
                  icon: const Icon(Icons.mic),
                  label: const Text(
                    '새 녹음',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _onImportPressed,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text(
                    '가져오기',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onNewRecordingPressed() async {
    final result = await Navigator.push<RecordingResult>(
      context,
      MaterialPageRoute(builder: (context) => const RecordingScreen()),
    );

    if (!mounted || result == null) return;

    final recording = Recording(
      id: result.recordingId,
      filePath: result.filePath,
      createdAt: result.createdAt,
      duration: result.duration,
    );

    await _repo.add(recording);
    await _load();
  }

  Future<void> _onImportPressed() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: RecordingImportService.supportedExtensions.toList()
          ..sort(),
        allowMultiple: false,
        withData: false,
      );

      if (!mounted || result == null) return; // canceled
      if (result.files.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('파일을 선택하지 못했어요.')));
        return;
      }

      final file = result.files.single;
      final path = file.path;
      if (path == null || path.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('파일 경로를 찾을 수 없어요.')));
        return;
      }

      final imported = await _importService.importFromPath(
        sourcePath: path,
        originalName: file.name,
      );

      final now = DateTime.now();
      final recording = Recording(
        id: 'imported_${now.millisecondsSinceEpoch}',
        filePath: imported.filePath,
        createdAt: now,
        duration: Duration.zero,
      );

      await _repo.add(recording);
      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('가져오기 완료: ${imported.fileName}')));
    } on RecordingImportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('가져오기 중 오류가 발생했어요.')));
    }
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(MdiIcons.microphoneOutline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '아직 녹음이 없어요',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '하단의 버튼을 눌러 첫 번째 녹음을 시작하세요',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard(Recording recording) {
    final title = _titleFor(recording.createdAt);

    return AnimatedBuilder(
      animation: _playback,
      builder: (context, _) {
        final isCurrent = _playback.currentRecordingId == recording.id;
        final isPlaying = isCurrent && _playback.isPlaying;
        final isTranscribing = recording.transcriptionStatus == TranscriptionStatus.pending;
        final hasTranscript = recording.transcriptionStatus == TranscriptionStatus.success;
        final hasFailed = recording.transcriptionStatus == TranscriptionStatus.failed;

        final total = isCurrent && _playback.duration != Duration.zero
            ? _playback.duration
            : recording.duration;

        final pos = isCurrent ? _playback.position : Duration.zero;
        final safePos = pos > total ? total : pos;

        final maxMs = total.inMilliseconds.toDouble();
        final valueMs = safePos.inMilliseconds.toDouble().clamp(
          0.0,
          maxMs == 0 ? 0.0 : maxMs,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
                title: Text(title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(recording.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        Text(
                          '${_formatDuration(recording.duration)} • ',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.green),
                        ),
                        _buildTranscriptionStatusChip(recording),
                      ],
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'transcribe':
                        await _startTranscription(recording);
                        break;
                      case 'view_transcript':
                        await _showTranscriptSheet(recording);
                        break;
                      case 'generate_summary':
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MeetingSummaryScreen(
                              recording: recording,
                              repository: _repo,
                            ),
                          ),
                        );
                        await _load(); // Reload to reflect any summary updates
                        break;
                      case 'path':
                        await showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (context) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '파일 경로',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SelectableText(recording.filePath),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            );
                          },
                        );
                        break;
                      case 'delete':
                        final ok = await _confirmDelete(recording);
                        if (ok != true) return;
                        if (_playback.currentRecordingId == recording.id) {
                          await _playback.stop();
                        }
                        await _repo.deleteById(recording.id);
                        await _load();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (!hasTranscript && !isTranscribing)
                      PopupMenuItem(
                        value: 'transcribe',
                        enabled: _transcribingIds.isEmpty,
                        child: Row(
                          children: [
                            Icon(MdiIcons.textBox),
                            const SizedBox(width: 8),
                            Text('텍스트 변환'),
                          ],
                        ),
                      ),
                    if (hasFailed)
                      PopupMenuItem(
                        value: 'transcribe',
                        enabled: _transcribingIds.isEmpty,
                        child: Row(
                          children: [
                            Icon(Icons.refresh, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              '재시도 (${recording.transcriptionRetryCount}회)',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    if (hasTranscript)
                      const PopupMenuItem(
                        value: 'view_transcript',
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined),
                            SizedBox(width: 8),
                            Text('텍스트 보기'),
                          ],
                        ),
                      ),
                    if (hasTranscript)
                      const PopupMenuItem(
                        value: 'generate_summary',
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('회의록 생성', style: TextStyle(color: Colors.blue)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'path',
                      child: Row(
                        children: [
                          Icon(Icons.folder_open),
                          SizedBox(width: 8),
                          Text('파일 경로'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('삭제', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () async {
                  final error = await _playback.toggle(
                    recordingId: recording.id,
                    filePath: recording.filePath,
                  );

                  if (!context.mounted || error == null) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error)));
                },
              ),
              if (isCurrent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      Slider(
                        value: valueMs,
                        max: maxMs == 0 ? 1 : maxMs,
                        onChanged: maxMs == 0
                            ? null
                            : (v) {
                                unawaited(
                                  _playback.seek(
                                    Duration(milliseconds: v.round()),
                                  ),
                                );
                              },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(safePos),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _formatDuration(total),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (isTranscribing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '텍스트 변환 중...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  int _getWeeklyCount() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _recordings.where((r) => r.createdAt.isAfter(weekStart)).length;
  }

  int _getSummaryCount() {
    return _recordings.where((r) => r.summaryText != null && r.summaryText!.isNotEmpty).length;
  }

  String _titleFor(DateTime createdAt) {
    final mm = createdAt.minute.toString().padLeft(2, '0');
    return '녹음 ${createdAt.month}/${createdAt.day} ${createdAt.hour}:$mm';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<bool?> _confirmDelete(Recording recording) {
    final title = _titleFor(recording.createdAt);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('녹음을 삭제할까요?'),
        content: Text('$title\n\n삭제하면 녹음 파일도 함께 제거됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '어제';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  Future<void> _startTranscription(Recording recording) async {
    // 이미 진행 중인지 확인
    if (recording.transcriptionStatus == TranscriptionStatus.pending) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 텍스트 변환이 진행 중이에요.')),
      );
      return;
    }

    // 다른 작업이 진행 중인지 확인
    if (_transcribingIds.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다른 텍스트 변환이 진행 중이에요.')),
      );
      return;
    }

    // pending 상태로 업데이트
    final pending = recording.copyWith(
      transcriptionStatus: TranscriptionStatus.pending,
      clearTranscriptionError: true,
    );
    await _repo.update(pending);

    setState(() {
      _transcribingIds.add(recording.id);
    });

    await _load();
    _showTranscriptionProgress();

    try {
      final text = await _transcriptionService.transcribeFileWithRetry(
        recording.filePath,
        maxRetries: 3,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _transcriptionProgress = progress.percentage;
            _currentChunk = progress.currentChunk;
            _totalChunks = progress.totalChunks;
          });
        },
      );
      final summary = _buildSummary(text);
      final updated = recording.copyWith(
        transcriptText: text,
        summaryText: summary,
        transcriptionStatus: TranscriptionStatus.success,
        transcriptionCompletedAt: DateTime.now(),
        clearTranscriptionError: true,
      );
      await _repo.update(updated);
      await _load();

      if (!mounted) return;
      _dismissTranscriptionProgress();
      setState(() {
        _transcribingIds.remove(recording.id);
        _transcriptionProgress = null;
        _currentChunk = null;
        _totalChunks = null;
      });

      final persisted = await _repo.getById(recording.id);
      if (!mounted) return;
      
      // 텍스트 변환 완료 후 회의록 자동 생성 제안
      final shouldGenerateSummary = await _showSummaryGenerationPrompt();
      if (shouldGenerateSummary == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingSummaryScreen(
              recording: persisted ?? updated,
              repository: _repo,
            ),
          ),
        );
        await _load(); // Reload to reflect any summary updates
      } else {
        await _showTranscriptSheet(persisted ?? updated);
      }
    } catch (e) {
      // 실패 상태로 업데이트
      final errorMessage = _messageForTranscriptionError(e);
      final failed = recording.copyWith(
        transcriptionStatus: TranscriptionStatus.failed,
        transcriptionError: errorMessage,
        transcriptionRetryCount: recording.transcriptionRetryCount + 1,
      );
      await _repo.update(failed);
      await _load();

      if (!mounted) return;
      _dismissTranscriptionProgress();
      if (mounted) {
        setState(() {
          _transcribingIds.remove(recording.id);
          _transcriptionProgress = null;
          _currentChunk = null;
          _totalChunks = null;
        });
      }
      await _showTranscriptionErrorDialog(recording, e);
    }
  }

  void _showTranscriptionProgress() {
    if (_progressDialogVisible || !mounted) return;
    _progressDialogVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('텍스트 변환 중'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(),
              SizedBox(height: 16),
              Text('오디오를 분석하고 있어요...'),
            ],
          ),
        ),
      ).whenComplete(() {
        _progressDialogVisible = false;
      }),
    );
  }

  void _dismissTranscriptionProgress() {
    if (!_progressDialogVisible || !mounted) return;
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  String _buildSummary(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    final parts = trimmed
        .split(RegExp(r'(?<=[.!?\\n])\\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    String summary;
    if (parts.isEmpty) {
      summary = trimmed;
    } else {
      final count = parts.length >= 3 ? 3 : (parts.length >= 2 ? 2 : 1);
      summary = parts.take(count).join(' ');
    }

    if (summary.length > 300) {
      summary = summary.substring(0, 300);
    }

    return summary;
  }

  String _messageForTranscriptionError(Object error) {
    if (error is PlatformException) {
      switch (error.code) {
        case 'speech_denied':
          return '음성 인식 권한이 필요해요. 설정에서 권한을 허용해주세요.';
        case 'file_missing':
          return '오디오 파일을 찾을 수 없어요. 파일이 삭제되었을 수 있어요.';
        case 'recognizer_unavailable':
          return '지금은 음성 인식을 사용할 수 없어요.';
        case 'recognizer_busy':
          return '음성 인식이 바쁜 상태예요. 잠시 후 다시 시도해주세요.';
        case 'offline_unavailable':
          return '이 기기에서는 오프라인 음성 인식을 지원하지 않아요.';
        case 'transcription_failed':
          return '텍스트 변환 중 오류가 발생했어요. 다시 시도해주세요.';
        case 'unsupported_platform':
          return '현재 기기에서는 텍스트 변환을 지원하지 않아요.';
        default:
          if (error.message != null && error.message!.isNotEmpty) {
            return error.message!;
          }
          return '텍스트 변환에 실패했어요.';
      }
    }
    return '텍스트 변환에 실패했어요.';
  }

  Future<void> _showTranscriptionErrorDialog(
    Recording recording,
    Object error,
  ) async {
    final message = _messageForTranscriptionError(error);
    if (!mounted) return;

    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('텍스트 변환 실패'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );

    if (retry == true && mounted) {
      await _startTranscription(recording);
    }
  }

  Future<bool?> _showSummaryGenerationPrompt() async {
    if (!mounted) return null;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회의록 생성'),
        content: const Text('AI로 회의록을 자동 생성하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('생성하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTranscriptSheet(Recording recording) {
    final transcript = (recording.transcriptText ?? '').trim();
    final summary = (recording.summaryText ?? '').trim();

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    '요약',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    summary.isEmpty ? '요약이 없어요.' : summary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '전체 텍스트',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    transcript.isEmpty ? '변환된 텍스트가 없어요.' : transcript,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTranscriptionStatusChip(Recording recording) {
    switch (recording.transcriptionStatus) {
      case TranscriptionStatus.none:
        return Text(
          '로컬 저장',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        );
      case TranscriptionStatus.pending:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '변환 중',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.blue,
              ),
            ),
          ],
        );
      case TranscriptionStatus.success:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Colors.green),
            const SizedBox(width: 4),
            Text(
              '변환 완료',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.green,
              ),
            ),
          ],
        );
      case TranscriptionStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, size: 14, color: Colors.red),
            const SizedBox(width: 4),
            Text(
              '변환 실패',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.red,
              ),
            ),
          ],
        );
    }
  }
}

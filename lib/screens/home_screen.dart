import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../models/recording.dart';
import '../models/recording_result.dart';
import '../repositories/local_recording_repository.dart';
import 'recording_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = LocalRecordingRepository();
  List<Recording> _recordings = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final items = await _repo.list();
    if (!mounted) return;
    setState(() {
      _recordings = items;
    });
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
                  value: '0',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<RecordingResult>(
            context,
            MaterialPageRoute(
              builder: (context) => const RecordingScreen(),
            ),
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
        },
        icon: const Icon(Icons.mic),
        label: const Text('새 녹음'),
      ),
    );
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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            MdiIcons.microphoneOutline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '아직 녹음이 없어요',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '하단의 버튼을 눌러 첫 번째 녹음을 시작하세요',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard(Recording recording) {
    final title = _titleFor(recording.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(
            Icons.mic,
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
            Text(
              '${_formatDuration(recording.duration)} • 로컬 저장',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                  ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
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
                            style: TextStyle(fontWeight: FontWeight.bold),
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
                await _repo.deleteById(recording.id);
                await _load();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'path',
              child: Row(
                children: [
                  Icon(Icons.folder_open),
                  SizedBox(width: 8),
                  Text('파일 경로'),
                ],
              ),
            ),
            PopupMenuItem(
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
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('길이: ${_formatDuration(recording.duration)}'),
                    const SizedBox(height: 8),
                    const Text(
                      '※ MVP: 재생/전사/요약은 아직 연결되지 않았습니다.',
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  int _getWeeklyCount() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _recordings.where((r) => r.createdAt.isAfter(weekStart)).length;
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
        content: Text(
          '$title\n\n삭제하면 녹음 파일도 함께 제거됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
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
}


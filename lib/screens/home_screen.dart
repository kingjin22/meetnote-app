import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../models/memo_record.dart';
import '../models/recording_result.dart';
import 'recording_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<MemoRecord> _records = [];

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
              // TODO: 설정 화면 이동
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단 요약 카드
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
                  value: '${_records.length}',
                ),
                _buildStatItem(
                  icon: MdiIcons.clock,
                  label: '이번 주',
                  value: '${_getWeeklyCount()}',
                ),
                _buildStatItem(
                  icon: MdiIcons.fileDocument,
                  label: '회의록',
                  value: '${_getMemoCount()}',
                ),
              ],
            ),
          ),
          
          // 기록 목록
          Expanded(
            child: _records.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return _buildRecordCard(record);
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

          final now = DateTime.now();
          final mm = now.minute.toString().padLeft(2, '0');

          setState(() {
            _records.insert(
              0,
              MemoRecord(
                id: now.millisecondsSinceEpoch.toString(),
                title: '녹음 ${now.month}/${now.day} ${now.hour}:$mm',
                createdAt: now,
                duration: _formatDuration(result.duration),
                status: '완료',
                hasTranscript: false,
                transcript: null,
              ),
            );
          });
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
            '하단의 + 버튼을 눌러 첫 번째 녹음을 시작하세요',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(MemoRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(
            record.hasTranscript ? MdiIcons.fileDocument : MdiIcons.microphone,
            color: Colors.white,
          ),
        ),
        title: Text(record.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(record.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (record.duration != null)
              Text(
                '${record.duration} • ${record.status}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getStatusColor(record.status),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility),
                  SizedBox(width: 8),
                  Text('보기'),
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
        onTap: () {
          // TODO: 상세 화면으로 이동
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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

  Color _getStatusColor(String status) {
    switch (status) {
      case '완료':
        return Colors.green;
      case '처리중':
        return Colors.orange;
      case '실패':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  int _getWeeklyCount() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _records.where((record) => 
      record.createdAt.isAfter(weekStart)).length;
  }

  int _getMemoCount() {
    return _records.where((record) => record.hasTranscript).length;
  }
}

// (moved to lib/models/memo_record.dart)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/recording_result.dart';
import '../services/audio_recorder_service.dart';
import '../services/microphone_permission_service.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  final _permissionService = MicrophonePermissionService();
  final _recorderService = AudioRecorderService();

  bool _isRecording = false;
  bool _isPaused = false;
  String? _filePath;

  Timer? _timer;
  Duration _duration = Duration.zero;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _recorderService.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording && !_isPaused) {
      await _pauseRecording();
    } else if (_isPaused) {
      await _resumeRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _recorderService.pause();

      setState(() {
        _isPaused = true;
      });

      _stopTimer();
      _pulseController.stop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일시정지 실패: $e')),
        );
      }
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _recorderService.resume();

      setState(() {
        _isPaused = false;
      });

      _startTimer();
      _pulseController.repeat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('재개 실패: $e')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    final status = await _permissionService.request();
    if (!status.isGranted) {
      await _showPermissionDialog(status);
      return;
    }

    final filePath = await _recorderService.start();

    setState(() {
      _isRecording = true;
      _filePath = filePath;
      _duration = Duration.zero;
    });

    _startTimer();
    _pulseController.repeat();
  }

  Future<void> _stopRecording() async {
    try {
      await _recorderService.stop();

      setState(() {
        _isRecording = false;
        _isPaused = false;
      });

      _stopTimer();
      _pulseController.stop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('정지 실패: $e')),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('녹음 취소'),
        content: const Text('녹음을 취소하시겠습니까? 저장되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('예', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _recorderService.cancel();

      setState(() {
        _isRecording = false;
        _isPaused = false;
        _filePath = null;
        _duration = Duration.zero;
      });

      _stopTimer();
      _pulseController.stop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('녹음이 취소되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('취소 실패: $e')),
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration = Duration(seconds: timer.tick);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _showPermissionDialog(PermissionStatus status) async {
    final shouldOpenSettings =
        status.isPermanentlyDenied || status.isRestricted;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('마이크 권한이 필요합니다'),
        content: const Text('녹음을 위해 마이크 권한을 허용해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          if (shouldOpenSettings)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _permissionService.openSettings();
              },
              child: const Text('설정으로 이동'),
            ),
        ],
      ),
    );
  }

  void _finish() {
    final filePath = _filePath;
    if (filePath == null || filePath.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장된 녹음 파일이 없습니다.')));
      return;
    }

    Navigator.of(context).pop(
      RecordingResult(
        recordingId: const Uuid().v4(),
        filePath: filePath,
        duration: _duration,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canFinish = !_isRecording && !_isPaused && (_filePath?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('녹음'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (canFinish)
            TextButton(onPressed: _finish, child: const Text('완료')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _TimerChip(duration: _duration, isPaused: _isPaused),
            const SizedBox(height: 32),
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final extra = (_isRecording && !_isPaused)
                              ? _pulseController.value * 20.0
                              : 0.0;
                          return Container(
                            width: 200.0 + extra,
                            height: 200.0 + extra,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isPaused
                                  ? Colors.orange.withValues(alpha: 0.85)
                                  : _isRecording
                                      ? Colors.red.withValues(alpha: 0.85)
                                      : Theme.of(context).colorScheme.primary,
                              boxShadow: (_isRecording && !_isPaused)
                                  ? [
                                      BoxShadow(
                                        color: Colors.red.withValues(alpha: 0.25),
                                        spreadRadius: _pulseController.value * 28,
                                        blurRadius: 18,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Icon(
                              _isPaused
                                  ? MdiIcons.play
                                  : _isRecording
                                      ? MdiIcons.pause
                                      : MdiIcons.microphone,
                              size: 80,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                    if (_isRecording || _isPaused) ...[
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _cancelRecording,
                            icon: Icon(MdiIcons.close),
                            label: const Text('취소'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _stopRecording,
                            icon: Icon(MdiIcons.stop),
                            label: const Text('정지'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          MdiIcons.file,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '저장 경로',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _filePath ??
                          (_isRecording
                              ? '녹음 파일을 준비 중...' // start() 직후
                              : '녹음을 시작하면 파일이 생성됩니다.'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                    const Spacer(),
                    Text(
                      _isPaused
                          ? '일시정지됨. 버튼을 눌러 재개하세요.'
                          : _isRecording
                              ? '녹음 중입니다. 버튼을 눌러 일시정지하세요.'
                              : '버튼을 눌러 녹음을 시작하세요.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  final Duration duration;
  final bool isPaused;

  const _TimerChip({required this.duration, this.isPaused = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isPaused
            ? Colors.orange.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: isPaused
            ? Border.all(color: Colors.orange, width: 2)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaused ? MdiIcons.pauseCircle : MdiIcons.clock,
            size: 16,
            color: isPaused
                ? Colors.orange
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            _format(duration),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isPaused
                  ? Colors.orange
                  : Theme.of(context).colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isPaused) ...[
            const SizedBox(width: 8),
            Text(
              '일시정지',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _format(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

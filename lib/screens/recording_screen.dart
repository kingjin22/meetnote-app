import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/recording_result.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';
  String _fullTranscript = '';
  
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  
  late AnimationController _pulseController;
  late AnimationController _waveController;
  
  @override
  void initState() {
    super.initState();
    _initSpeech();
    _setupAnimations();
  }
  
  @override
  void dispose() {
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }
  
  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }
  
  /// Initialize speech recognition
  Future<void> _initSpeech() async {
    // Check microphone permission
    final permission = await Permission.microphone.request();
    if (permission != PermissionStatus.granted) {
      _showPermissionDialog();
      return;
    }
    
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }
  
  /// Start listening for speech
  Future<void> _startListening() async {
    if (!_speechEnabled) return;
    
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(minutes: 10), // 최대 10분
      pauseFor: const Duration(seconds: 3),
      localeId: 'ko-KR', // 한국어 설정
    );
    
    setState(() {
      _isListening = true;
      _recordingDuration = Duration.zero;
    });
    
    // 녹음 시간 타이머 시작
    _startTimer();
    
    // 애니메이션 시작
    _pulseController.repeat();
    _waveController.repeat();
  }
  
  /// Stop listening
  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
    
    _stopTimer();
    _pulseController.stop();
    _waveController.stop();
  }
  
  /// Handle speech recognition result
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      if (result.finalResult) {
        _fullTranscript += '${result.recognizedWords} ';
      }
    });
  }
  
  void _startTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration = Duration(seconds: timer.tick);
      });
    });
  }
  
  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }
  
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('마이크 권한이 필요합니다'),
        content: const Text('음성 녹음을 위해 마이크 권한을 허용해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _saveAndProcess() async {
    final transcript = (_fullTranscript + _lastWords).trim();
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음된 내용이 없습니다.')),
      );
      return;
    }

    // TODO: 실제 저장(오디오 파일) + 요약/회의록 생성(GPT) 연결
    // 지금은 홈 화면에 전사 텍스트와 녹음 시간을 넘겨주는 MVP 흐름만 유지.

    Navigator.of(context).pop(
      RecordingResult(
        transcript: transcript,
        duration: _recordingDuration,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('음성 녹음'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isListening || _fullTranscript.isNotEmpty)
            TextButton(
              onPressed: _saveAndProcess,
              child: const Text('완료'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 녹음 시간 표시
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    MdiIcons.clock,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_recordingDuration),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 녹음 버튼
            Expanded(
              flex: 2,
              child: Center(
                child: GestureDetector(
                  onTap: _speechEnabled
                      ? (_isListening ? _stopListening : _startListening)
                      : null,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 200 + (_isListening ? _pulseController.value * 20 : 0),
                        height: 200 + (_isListening ? _pulseController.value * 20 : 0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? Colors.red.withValues(alpha: 0.8)
                              : Theme.of(context).colorScheme.primary,
                          boxShadow: _isListening
                              ? [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    spreadRadius: _pulseController.value * 30,
                                    blurRadius: 20,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          _isListening ? MdiIcons.stop : MdiIcons.microphone,
                          size: 80,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            
            // 실시간 전사 결과
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            MdiIcons.text,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '실시간 전사',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _fullTranscript.isEmpty && _lastWords.isEmpty
                            ? (_isListening
                                ? '음성을 인식하고 있습니다...'
                                : '녹음을 시작하면 실시간으로 텍스트가 표시됩니다.')
                            : _fullTranscript + _lastWords,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 하단 안내
            Text(
              _isListening
                  ? '녹음 중입니다. 빨간 버튼을 눌러 중지하세요.'
                  : '마이크 버튼을 눌러 녹음을 시작하세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
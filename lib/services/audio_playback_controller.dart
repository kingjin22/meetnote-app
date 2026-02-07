import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Minimal audio playback controller for MVP.
///
/// - Lazy-creates [AudioPlayer] to keep widget tests (MissingPluginException) safe.
/// - Manages single active recording: switching files stops previous playback.
class AudioPlaybackController extends ChangeNotifier {
  AudioPlayer? _player;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  String? _currentRecordingId;
  String? get currentRecordingId => _currentRecordingId;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  String? _lastError;
  String? get lastError => _lastError;

  Future<AudioPlayer> _ensurePlayer() async {
    if (_player != null) return _player!;

    final player = AudioPlayer();
    _player = player;

    _positionSub = player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });

    _durationSub = player.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });

    _playerStateSub = player.playerStateStream.listen((s) {
      _isPlaying = s.playing;
      // Reset position when completed.
      if (s.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _position = _duration;
      }
      notifyListeners();
    });

    return player;
  }

  Future<String?> toggle({
    required String recordingId,
    required String filePath,
  }) async {
    _lastError = null;

    try {
      final player = await _ensurePlayer();

      final isSame = _currentRecordingId == recordingId;
      if (!isSame) {
        await stop();
        _currentRecordingId = recordingId;
        _position = Duration.zero;
        _duration = Duration.zero;
        notifyListeners();

        final file = File(filePath);
        if (!file.existsSync()) {
          _lastError = '파일을 찾을 수 없어요.';
          await stop();
          return _lastError;
        }

        await player.setAudioSource(AudioSource.file(filePath));
        await player.play();
        return null;
      }

      if (player.playing) {
        await player.pause();
      } else {
        await player.play();
      }
      return null;
    } catch (e) {
      _lastError = '재생에 실패했어요.';
      // Best-effort cleanup.
      try {
        await stop();
      } catch (_) {}
      return _lastError;
    }
  }

  Future<void> seek(Duration position) async {
    final player = _player;
    if (player == null) return;

    var safe = position;
    if (safe < Duration.zero) safe = Duration.zero;
    if (_duration != Duration.zero && safe > _duration) safe = _duration;

    await player.seek(safe);
  }

  Future<void> stop() async {
    final player = _player;
    if (player == null) {
      _currentRecordingId = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _isPlaying = false;
      notifyListeners();
      return;
    }

    await player.stop();
    _currentRecordingId = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    // Dispose must be sync; do async cleanup best-effort.
    unawaited(_disposeAsync());
    super.dispose();
  }

  Future<void> _disposeAsync() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _playerStateSub?.cancel();

    await _player?.dispose();
    _player = null;
  }
}

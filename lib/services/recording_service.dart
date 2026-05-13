import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  String? _currentPath;
  DateTime? _startTime;
  bool _isDisposed = false;

  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationController.stream;

  /// Real-time amplitude stream (normalized 0.0 – 1.0).
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  Timer? _timer;
  Timer? _amplitudeTimer;

  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording with configurable quality.
  ///
  /// [quality] controls the bitrate/sample rate tradeoff:
  /// - `RecordQuality.low` — smaller files, lower fidelity
  /// - `RecordQuality.medium` — balanced (default)
  /// - `RecordQuality.high` — larger files, higher fidelity
  Future<void> startRecording(String userId, {RecordQuality quality = RecordQuality.medium}) async {
    if (await _recorder.isRecording()) {
      developer.log('Already recording — ignoring duplicate start.', name: 'RecordingService');
      return;
    }

    if (await _recorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/sumquiz_recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final String fileName =
          'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentPath = '${recordingsDir.path}/$fileName';

      final config = RecordConfig(
        bitRate: _bitRateForQuality(quality),
        sampleRate: _sampleRateForQuality(quality),
      );

      await _recorder.start(config, path: _currentPath!);
      _startTime = DateTime.now();
      _startTimer();
      _startAmplitudePolling();
    } else {
      throw Exception('Microphone permission not granted');
    }
  }

  int _bitRateForQuality(RecordQuality quality) {
    switch (quality) {
      case RecordQuality.low: return 64000;
      case RecordQuality.medium: return 128000;
      case RecordQuality.high: return 256000;
    }
  }

  int _sampleRateForQuality(RecordQuality quality) {
    switch (quality) {
      case RecordQuality.low: return 22050;
      case RecordQuality.medium: return 44100;
      case RecordQuality.high: return 44100;
    }
  }

  Future<String?> stopRecording() async {
    _stopAmplitudePolling();
    final path = await _recorder.stop();
    _stopTimer();
    return path;
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  Future<Amplitude> getAmplitude() async {
    return await _recorder.getAmplitude();
  }

  /// Get the file size of the current recording in bytes, or null if
  /// no recording is in progress.
  Future<int?> getCurrentRecordingSize() async {
    if (_currentPath == null) return null;
    final file = File(_currentPath!);
    if (await file.exists()) {
      return await file.length();
    }
    return null;
  }

  /// Delete a recording file from disk.
  Future<void> deleteRecordingFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        developer.log('Deleted recording: $filePath', name: 'RecordingService');
      }
    } catch (e) {
      developer.log('Failed to delete recording: $e', name: 'RecordingService');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null && !_isDisposed) {
        _durationController.add(DateTime.now().difference(_startTime!));
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;
    if (!_isDisposed) {
      _durationController.add(Duration.zero);
    }
  }

  /// Poll amplitude every 100ms and emit normalized values (0.0 – 1.0).
  void _startAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      try {
        final amp = await _recorder.getAmplitude();
        // amp.current is in dBFS: 0 = max, -160 = silence.
        // Normalize to 0.0 – 1.0 range.
        final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        if (!_isDisposed) {
          _amplitudeController.add(normalized);
        }
      } catch (_) {
        // Recorder may have stopped between polls
      }
    });
  }

  void _stopAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
  }

  // --- PLAYBACK ---

  Future<void> play(String path) async {
    await _player.play(DeviceFileSource(path));
  }

  Future<void> playUrl(String url) async {
    await _player.play(UrlSource(url));
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.resume();
  }

  Future<void> stopPlayer() async {
    await _player.stop();
  }

  /// Seek to a specific position in the current playback.
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Stream<Duration> get playerPositionStream => _player.onPositionChanged;
  Stream<Duration> get playerDurationStream => _player.onDurationChanged;
  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;

  void dispose() {
    _isDisposed = true;
    _recorder.dispose();
    _player.dispose();
    _durationController.close();
    _amplitudeController.close();
    _timer?.cancel();
    _amplitudeTimer?.cancel();
  }
}

/// Quality preset for recordings.
enum RecordQuality { low, medium, high }

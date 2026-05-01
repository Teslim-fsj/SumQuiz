import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  
  String? _currentPath;
  DateTime? _startTime;
  
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationController.stream;
  Timer? _timer;

  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording(String userId) async {
    if (await _recorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      final String fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentPath = '${directory.path}/$fileName';

      const config = RecordConfig();

      await _recorder.start(config, path: _currentPath!);
      _startTime = DateTime.now();
      _startTimer();
    } else {
      throw Exception('Microphone permission not granted');
    }
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    _stopTimer();
    return path;
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        _durationController.add(DateTime.now().difference(_startTime!));
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;
    _durationController.add(Duration.zero);
  }

  // --- PLAYBACK ---

  Future<void> play(String path) async {
    await _player.play(DeviceFileSource(path));
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

  Stream<Duration> get playerPositionStream => _player.onPositionChanged;
  Stream<Duration> get playerDurationStream => _player.onDurationChanged;
  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;

  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _durationController.close();
    _timer?.cancel();
  }
}

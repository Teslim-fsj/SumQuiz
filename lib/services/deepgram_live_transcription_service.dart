import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

class DeepgramLiveTranscriptionService {
  static const String _apiKey = String.fromEnvironment('DEEPGRAM_API_KEY');

  final AudioRecorder _recorder = AudioRecorder();

  WebSocket? _socket;
  StreamSubscription<Uint8List>? _audioSub;
  Timer? _keepAliveTimer;
  bool _isActive = false;

  final _transcriptController = StreamController<String>.broadcast();
  final _partialController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get partialStream => _partialController.stream;
  Stream<String> get errorStream => _errorController.stream;
  bool get isActive => _isActive;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start({String language = 'en-US'}) async {
    if (_isActive) return;

    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission not granted');
    }

    if (_apiKey.isEmpty) {
      throw Exception('DEEPGRAM_API_KEY is missing from the build');
    }

    final uri = Uri.https('api.deepgram.com', '/v1/listen', {
      'model': 'nova-3',
      'language': language,
      'encoding': 'linear16',
      'sample_rate': '16000',
      'channels': '1',
      'interim_results': 'true',
      'endpointing': '500',
      'punctuate': 'true',
      'smart_format': 'true',
      'tag': 'sumquiz_live_notes',
    });

    _socket = await WebSocket.connect(
      uri.toString().replaceFirst('https://', 'wss://'),
      headers: {'Authorization': 'Token $_apiKey'},
    );
    _socket!.listen(
      _handleSocketMessage,
      onError: (error) {
        developer.log('Deepgram socket error: $error',
            name: 'DeepgramLiveTranscriptionService');
        _errorController.add('Live transcription connection failed.');
      },
      onDone: () {
        _isActive = false;
      },
      cancelOnError: false,
    );

    final audioStream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        noiseSuppress: true,
        streamBufferSize: 4096,
      ),
    );

    _audioSub = audioStream.listen((chunk) {
      if (_socket?.readyState == WebSocket.open && chunk.isNotEmpty) {
        _socket!.add(chunk);
      }
    }, onError: (error) {
      developer.log('Deepgram audio stream error: $error',
          name: 'DeepgramLiveTranscriptionService');
      _errorController.add('Microphone stream failed.');
    });

    _keepAliveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_socket?.readyState == WebSocket.open) {
        _socket!.add(jsonEncode({'type': 'KeepAlive'}));
      }
    });

    _isActive = true;
  }

  void _handleSocketMessage(dynamic message) {
    if (message is! String) return;

    try {
      final data = jsonDecode(message);
      if (data is! Map || data['type'] != 'Results') return;

      final channel = data['channel'];
      if (channel is! Map) return;

      final alternatives = channel['alternatives'];
      if (alternatives is! List || alternatives.isEmpty) return;

      final first = alternatives.first;
      if (first is! Map) return;

      final transcript = first['transcript']?.toString().trim() ?? '';
      if (transcript.isEmpty) return;

      if (data['is_final'] == true) {
        _transcriptController.add(transcript);
        _partialController.add('');
      } else {
        _partialController.add(transcript);
      }
    } catch (e) {
      developer.log('Failed to parse Deepgram result: $e',
          name: 'DeepgramLiveTranscriptionService');
    }
  }

  Future<void> stop() async {
    _isActive = false;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;

    await _audioSub?.cancel();
    _audioSub = null;

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      developer.log('Failed to stop Deepgram recorder: $e',
          name: 'DeepgramLiveTranscriptionService');
    }

    try {
      if (_socket?.readyState == WebSocket.open) {
        _socket!.add(Uint8List(0));
        await _socket!.close();
      }
    } catch (e) {
      developer.log('Failed to close Deepgram socket: $e',
          name: 'DeepgramLiveTranscriptionService');
    } finally {
      _socket = null;
    }
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
    await _transcriptController.close();
    await _partialController.close();
    await _errorController.close();
  }
}

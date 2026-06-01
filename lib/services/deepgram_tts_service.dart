import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Deepgram Aura TTS service.
///
/// Streams MP3 audio from Deepgram's Aura API sentence-by-sentence.
/// Falls back gracefully when [isAvailable] is false (no API key or web).
class DeepgramTTSService {
  static const String _apiKey = String.fromEnvironment('DEEPGRAM_API_KEY');

  /// Voice model. Aura-2 voices: aura-2-thalia-en, aura-2-andromeda-en, etc.
  /// Aura-1 (stable): aura-asteria-en, aura-luna-en, aura-stella-en
  static const String _voice = 'aura-asteria-en';

  /// Whether this service can function (key present + non-web).
  static bool get isAvailable => _apiKey.isNotEmpty && !kIsWeb;

  final AudioPlayer _player = AudioPlayer();

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;
  bool get isBusy => _isSpeaking || _isProcessingQueue || _queue.isNotEmpty;

  final _speakingController = StreamController<bool>.broadcast();
  Stream<bool> get speakingStream => _speakingController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  // Queue of pending sentences
  final List<String> _queue = [];
  bool _isProcessingQueue = false;
  bool _disposed = false;

  DeepgramTTSService() {
    _player.onPlayerComplete.listen((_) => _onPlaybackComplete());
    _player.onPlayerStateChanged.listen((state) {
      final speaking = state == PlayerState.playing;
      if (_isSpeaking != speaking) {
        _isSpeaking = speaking;
        _speakingController.add(speaking);
      }
    });
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Enqueue a sentence for sequential playback.
  void enqueueSentence(String text) {
    final clean = _cleanText(text);
    if (clean.isEmpty) return;
    _queue.add(clean);
    if (!_isProcessingQueue) _processQueue();
  }

  /// Speak immediately, discarding the current queue.
  Future<void> speakNow(String text) async {
    await stop();
    enqueueSentence(text);
  }

  /// Stop all playback and clear the queue.
  Future<void> stop() async {
    _queue.clear();
    _isProcessingQueue = false;
    try {
      await _player.stop();
    } catch (_) {}
    _setSpeaking(false);
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _player.dispose();
    await _speakingController.close();
    await _errorController.close();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _processQueue() async {
    if (_isProcessingQueue || _queue.isEmpty || _disposed) return;
    _isProcessingQueue = true;

    while (_queue.isNotEmpty && !_disposed) {
      final sentence = _queue.removeAt(0);
      await _synthesiseAndPlay(sentence);
      // Wait for playback to finish before next sentence
      while (_isSpeaking && !_disposed) {
        await Future.delayed(const Duration(milliseconds: 80));
      }
    }

    _isProcessingQueue = false;
    _setSpeaking(false);
  }

  Future<void> _synthesiseAndPlay(String text) async {
    if (_disposed) return;

    try {
      final bytes = await _fetchAudio(text);
      if (bytes == null || bytes.isEmpty || _disposed) return;

      final file = await _writeTempFile(bytes);
      if (_disposed) return;

      _setSpeaking(true);
      await _player.play(DeviceFileSource(file.path));
    } catch (e) {
      developer.log('DeepgramTTS synthesise error: $e',
          name: 'DeepgramTTSService');
      _errorController.add('TTS error: $e');
      _setSpeaking(false);
    }
  }

  /// Calls Deepgram Aura REST endpoint, returns raw MP3 bytes.
  Future<Uint8List?> _fetchAudio(String text) async {
    final uri = Uri.https('api.deepgram.com', '/v1/speak', {
      'model': _voice,
      'encoding': 'mp3',
    });

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Token $_apiKey');
      request.headers.set('Content-Type', 'application/json');

      final body = '{"text":${_jsonString(text)}}';
      request.write(body);

      final response = await request.close().timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Deepgram TTS timed out'),
          );

      if (response.statusCode != 200) {
        final err = await response.transform(utf8.decoder).join();
        developer.log('Deepgram TTS HTTP ${response.statusCode}: $err',
            name: 'DeepgramTTSService');
        _errorController.add('TTS unavailable (${response.statusCode})');
        return null;
      }

      final chunks = <int>[];
      await response.forEach((chunk) => chunks.addAll(chunk));
      return Uint8List.fromList(chunks);
    } finally {
      client.close();
    }
  }

  Future<File> _writeTempFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/sumi_tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _onPlaybackComplete() {
    _setSpeaking(false);
  }

  void _setSpeaking(bool value) {
    if (_isSpeaking == value) return;
    _isSpeaking = value;
    if (!_speakingController.isClosed) {
      _speakingController.add(value);
    }
  }

  String _cleanText(String raw) => raw.replaceAll(RegExp(r'[*_#`]'), '').trim();

  /// Minimal JSON string escaping — avoids a full JSON encode dependency.
  String _jsonString(String s) {
    final escaped = s
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return '"$escaped"';
  }
}

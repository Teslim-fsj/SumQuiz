import 'dart:async';
import 'dart:developer' as developer;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isActive = false;

  /// Whether the service is currently in an active listening session.
  bool get isActive => _isActive;

  final _transcriptController = StreamController<String>.broadcast();
  final _partialController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get partialStream => _partialController.stream;

  /// Stream of error messages for UI display.
  Stream<String> get errorStream => _errorController.stream;

  /// How many times auto-restart has been attempted in a row without
  /// receiving any speech. Resets when speech is detected.
  int _restartCount = 0;
  static const int _maxConsecutiveRestarts = 50; // ~50 min safety cap

  Future<bool> init() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) {
        developer.log('Speech Error: ${error.errorMsg}', name: 'SpeechService');
        if (error.permanent) {
          _errorController.add('Microphone error: ${error.errorMsg}');
          _isActive = false;
        }
      },
      onStatus: (status) {
        developer.log('Speech Status: $status', name: 'SpeechService');
        _handleStatusChange(status);
      },
    );
    return _isInitialized;
  }

  /// Handles STT status transitions. When the recognizer stops
  /// (`'done'` / `'notListening'`) during an active session, it
  /// automatically restarts to keep the transcript flowing.
  void _handleStatusChange(String status) {
    if (!_isActive) return;

    if (status == 'done' || status == 'notListening') {
      // The platform recognizer has timed out — restart it.
      if (_restartCount < _maxConsecutiveRestarts) {
        _restartCount++;
        developer.log(
          'Auto-restarting speech recognition (attempt $_restartCount)',
          name: 'SpeechService',
        );
        // Small delay to let the platform release resources.
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_isActive) _beginListening();
        });
      } else {
        developer.log(
          'Max restart attempts reached — stopping.',
          name: 'SpeechService',
        );
        _errorController.add('Speech recognition timed out after extended use.');
        _isActive = false;
      }
    }
  }

  String _lastCommittedText = '';

  Future<void> startListening() async {
    if (!_isInitialized) await init();
    _lastCommittedText = '';
    _restartCount = 0;
    _isActive = true;
    await _beginListening();
  }

  /// Internal listen call — shared between initial start and auto-restarts.
  Future<void> _beginListening() async {
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          String current = result.recognizedWords.trim();

          if (result.finalResult) {
            if (current.isNotEmpty) {
              String delta = current;
              if (current.startsWith(_lastCommittedText)) {
                delta = current.substring(_lastCommittedText.length).trim();
              }

              if (delta.isNotEmpty) {
                _transcriptController.add(delta);
                _lastCommittedText = current;
                _partialController.add(''); // Clear partial on commit
                _restartCount = 0; // Reset — we got real speech
              }
            }
          } else {
            // Handle partial results
            String partial = current;
            if (current.startsWith(_lastCommittedText)) {
              partial = current.substring(_lastCommittedText.length).trim();
            }
            _partialController.add(partial);
            _restartCount = 0; // Reset — we got real speech
          }
        },
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(seconds: 10),
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      developer.log('Failed to begin listening: $e', name: 'SpeechService');
      _errorController.add('Failed to start microphone: $e');
    }
  }

  Future<void> stopListening() async {
    _isActive = false;
    await _speech.stop();
    _lastCommittedText = '';
  }

  void dispose() {
    _isActive = false;
    _transcriptController.close();
    _partialController.close();
    _errorController.close();
  }
}

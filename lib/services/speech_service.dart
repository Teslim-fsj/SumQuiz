import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  final _transcriptController = StreamController<String>.broadcast();
  final _partialController = StreamController<String>.broadcast();
  
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get partialStream => _partialController.stream;

  Future<bool> init() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) => print('Speech Error: $error'),
      onStatus: (status) => print('Speech Status: $status'),
    );
    return _isInitialized;
  }

  String _lastCommittedText = '';

  Future<void> startListening() async {
    if (!_isInitialized) await init();
    _lastCommittedText = '';
    
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
            }
          }
        } else {
          // Handle partial results
          String partial = current;
          if (current.startsWith(_lastCommittedText)) {
            partial = current.substring(_lastCommittedText.length).trim();
          }
          _partialController.add(partial);
        }
      },
      listenFor: const Duration(hours: 1),
      pauseFor: const Duration(seconds: 10),
      cancelOnError: false,
      partialResults: true,
      listenMode: ListenMode.dictation,
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _lastCommittedText = '';
  }

  void dispose() {
    _transcriptController.close();
    _partialController.close();
  }
}

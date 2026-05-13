import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../models/sumi_emotion.dart';
import '../services/ai/ai_config.dart';
import '../models/sumi_message.dart';
import '../services/ai/generator_ai_service.dart';
import '../services/local_database_service.dart';
import '../services/recording_service.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/usage_service.dart';
import '../services/auth_service.dart';

class SumiProvider extends ChangeNotifier {
  final GeneratorAIService _aiService;
  final LocalDatabaseService _localDb;
  final SumiEmotionEngine _engine = SumiEmotionEngine();

  final RecordingService _recordingService = RecordingService();

  final UsageService? _usageService;
  final AuthService _authService;
  final FlutterTts _tts = FlutterTts();

  SumiProvider({
    required GeneratorAIService aiService,
    required LocalDatabaseService localDb,
    UsageService? usageService,
    required AuthService authService,
  })  : _aiService = aiService,
        _localDb = localDb,
        _usageService = usageService,
        _authService = authService {
    _initChatHistory();
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    _tts.setCompletionHandler(() {
      _isSumiSpeaking = false;
      notifyListeners();
    });
    
    _tts.setErrorHandler((msg) {
      developer.log("TTS Error: $msg");
      _isSumiSpeaking = false;
      notifyListeners();
    });
  }

  bool _isVoiceRecording = false;
  bool get isVoiceRecording => _isVoiceRecording;

  bool _isProcessingVoice = false;
  bool get isProcessingVoice => _isProcessingVoice;

  Duration _recordingDuration = Duration.zero;
  Duration get recordingDuration => _recordingDuration;

  StreamSubscription? _recordingSub;

  bool _isLiveSession = false;
  bool get isLiveSession => _isLiveSession;

  bool _isSumiSpeaking = false;
  bool get isSumiSpeaking => _isSumiSpeaking;

  Timer? _vadTimer;
  int _silenceCount = 0;
  bool _hasSpeaked = false;
  static const int silenceThreshold = 15; // ~1.5s (100ms * 15)
  static const double amplitudeThreshold = -30.0; // dB

  SumiState _currentState = SumiState.idle;
  SumiState get currentState => _currentState;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<SumiMessage> _messages = [];
  List<SumiMessage> get messages => List.unmodifiable(_messages);

  EmotionContext _context = EmotionContext(
    streak: 0,
    sessionLength: 0,
    wrongStreak: 0,
    isFocusedMode: false,
    lastInteraction: DateTime.now(),
  );

  String? _dialogue = "I am Sumi. How can I help you today?";
  String? get dialogue => _dialogue;

  EmotionContext get currentContext => _context;

  StreamSubscription? _chatSub;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  String? _streamingMessage;
  String? get streamingMessage => _streamingMessage;

  void _initChatHistory() {
    _chatSub = _localDb.watchChatHistory().listen((msgs) {
      _messages = msgs;
      notifyListeners();
    });
  }

  Future<void> addMessage(String text, MessageRole role) async {
    final message = SumiMessage(
      text: text,
      role: role,
      timestamp: DateTime.now(),
    );
    await _localDb.saveChatMessage(message);
    
    if (role == MessageRole.sumi) {
      _dialogue = text;
      _streamingMessage = null;
    }
  }

  Future<void> askSumi(String prompt, {String? context, String? userName}) async {
    final uid = _authService.currentUser?.uid;
    if (uid != null && _usageService != null) {
      final canProceed = await _usageService.canPerformAction(uid, 'tutor');
      if (!canProceed) {
        _errorMessage = "Neural capacity depleted. Try again later!";
        notifyListeners();
        return;
      }
    }

    // 1. Add user message
    await addMessage(prompt, MessageRole.user);

    // 2. Set thinking state
    _currentState = SumiState.thinking;
    _isStreaming = true;
    _streamingMessage = "";
    notifyListeners();

    try {
      String fullResponse = '';
      
      // Build context from last 5 messages for continuity
      final history = _messages.reversed.take(5).toList().reversed
          .map((m) => "${m.role == MessageRole.user ? 'Student' : 'Sumi'}: ${m.text}")
          .join("\n");

      final stream = _aiService.getTutorResponseStream(
        prompt: prompt,
        context: history + (context != null ? "\nFILE CONTEXT: $context" : ""),
        userName: userName,
      );

      await for (final chunk in stream) {
        fullResponse += chunk;
        _streamingMessage = fullResponse;
        _dialogue = fullResponse;
        notifyListeners();
      }

      // 4. Save full response to DB
      await addMessage(fullResponse, MessageRole.sumi);
      
      // Record usage after successful completion
      if (uid != null && _usageService != null) {
        await _usageService.recordAction(uid, 'tutor');
      }
      
      // 5. Update emotion based on response length/tone
      if (fullResponse.length > 200) {
        _currentState = SumiState.analytical;
      } else {
        _currentState = SumiState.idle;
      }
      notifyListeners();
      
    } catch (e) {
      _currentState = SumiState.tired;
      _dialogue = "Oops, my neural circuits got a bit tangled! Let's try that again?";
      notifyListeners();
    } finally {
      _isStreaming = false;
      notifyListeners();
    }
  }

  Future<void> startVoiceRecording() async {
    if (_isVoiceRecording) return;
    
    try {
      final hasPermission = await _recordingService.hasPermission();
      if (!hasPermission) {
        _dialogue = "I need microphone access to hear you!";
        notifyListeners();
        return;
      }

      _isVoiceRecording = true;
      _recordingDuration = Duration.zero;
      _currentState = SumiState.idle;
      notifyListeners();

      await _recordingService.startRecording("sumi_voice");
      
      _recordingSub = _recordingService.durationStream.listen((duration) {
        _recordingDuration = duration;
        notifyListeners();
      });
    } catch (e) {
      _isVoiceRecording = false;
      _dialogue = "Microphone error. Is it plugged in?";
      notifyListeners();
    }
  }

  Future<void> stopVoiceRecording({String? context}) async {
    if (!_isVoiceRecording) return;

    _isVoiceRecording = false;
    _isProcessingVoice = true;
    _currentState = SumiState.thinking;
    notifyListeners();

    _recordingSub?.cancel();

    try {
      final path = await _recordingService.stopRecording();
      if (path != null) {
        final file = File(path);
        final bytes = await file.readAsBytes();
        
        // Process with AI
        await _processVoiceInput(bytes, context: context);
      }
    } catch (e) {
      _dialogue = "I couldn't hear that clearly.";
    } finally {
      _isProcessingVoice = false;
      if (!_isLiveSession) _currentState = SumiState.idle;
      notifyListeners();
    }
  }

  Future<void> _processVoiceInput(Uint8List audioBytes, {String? context}) async {
    // Phase 5: Build context from last 5 messages
    final history = _messages.reversed.take(5).toList().reversed
        .map((m) => "${m.role == MessageRole.user ? 'Student' : 'Sumi'}: ${m.text}")
        .join("\n");

    try {
      _isStreaming = true;
      _streamingMessage = "...";
      notifyListeners();
      
      final prompt = """
      Analyze the student's audio input. 
      1. Provide a verbatim transcription.
      2. Provide your concise tutor response (1-2 sentences).
      
      FORMAT:
      TRANSCRIPTION: [text]
      RESPONSE: [text]
      """;

      final rawResponse = await _aiService.getConversationalResponseWithAudio(
        prompt: prompt, 
        audioBytes: audioBytes, 
        context: history + (context != null ? "\nFILE CONTEXT: $context" : ""),
        userName: _authService.currentUser?.displayName,
      );

      String transcription = "[Voice Input]";
      String response = rawResponse;

      if (rawResponse.contains("TRANSCRIPTION:") && rawResponse.contains("RESPONSE:")) {
        final parts = rawResponse.split("RESPONSE:");
        transcription = parts[0].replaceAll("TRANSCRIPTION:", "").trim();
        response = parts[1].trim();
      }
      
      _isStreaming = false;
      await addMessage(transcription, MessageRole.user);
      await addMessage(response, MessageRole.sumi);
      
      _dialogue = response;
      _currentState = SumiState.analytical;
      notifyListeners();

      if (_isLiveSession) {
        await _speakResponse(response);
      }
    } catch (e) {
      _isStreaming = false;
      _dialogue = "Neural gap detected. Say that again?";
      notifyListeners();
    }
  }

  Future<void> _speakResponse(String text) async {
    _isSumiSpeaking = true;
    _currentState = SumiState.speaking; // OrbState.speaking
    notifyListeners();

    try {
      final cleanText = text.replaceAll(RegExp(r'[*_#]'), '');
      await _tts.speak(cleanText);
      
      // Wait for completion via handler, or timeout
      int waitCount = 0;
      while (_isSumiSpeaking && waitCount < 100) { // 10s max
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
    } catch (e) {
      developer.log("TTS Error: $e");
    } finally {
      _isSumiSpeaking = false;
      _currentState = SumiState.idle;
      notifyListeners();
    }
  }

  Future<void> startLiveSession({String? context}) async {
    if (_isLiveSession) return;
    
    final uid = _authService.currentUser?.uid;
    if (uid != null && _usageService != null) {
      final canProceed = await _usageService.canPerformAction(uid, 'tutor_session');
      if (!canProceed) {
        _dialogue = "Neural capacity too low for live sync. Use chat instead!";
        notifyListeners();
        return;
      }
      await _usageService.recordAction(uid, 'tutor_session');
    }

    _isLiveSession = true;
    _currentState = SumiState.idle;
    notifyListeners();
    
    await _runLiveLoop(context: context);
  }

  Future<void> stopLiveSession() async {
    _isLiveSession = false;
    _vadTimer?.cancel();
    _recordingSub?.cancel();
    await _recordingService.stopRecording();
    await _recordingService.stopPlayer();
    _isVoiceRecording = false;
    _isSumiSpeaking = false;
    _currentState = SumiState.idle;
    notifyListeners();
  }

  Future<void> _runLiveLoop({String? context}) async {
    while (_isLiveSession) {
      if (_isSumiSpeaking || _isProcessingVoice) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      try {
        await startVoiceRecording();
        _silenceCount = 0;
        _hasSpeaked = false;

        int peakCount = 0;
        while (_isVoiceRecording && _isLiveSession) {
          await Future.delayed(const Duration(milliseconds: 100));
          
          final amp = await _recordingService.getAmplitude();
          // Normalize amplitude threshold check
          if (amp.current > amplitudeThreshold) {
            peakCount++;
            if (peakCount > 1) { // Faster trigger
              _silenceCount = 0;
              _hasSpeaked = true;
            }
          } else {
            peakCount = 0;
            if (_hasSpeaked) _silenceCount++;
          }

          if ((_hasSpeaked && _silenceCount >= silenceThreshold) || _recordingDuration.inSeconds > 20) {
            break;
          }
        }

        if (_isLiveSession && _hasSpeaked) {
          await stopVoiceRecording(context: context);
          // Wait for Sumi to finish speaking before next loop
          while (_isSumiSpeaking && _isLiveSession) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
          // Turn-taking grace period
          await Future.delayed(const Duration(milliseconds: 800));
        } else if (_isLiveSession) {
          await _recordingService.stopRecording();
          _isVoiceRecording = false;
        }
      } catch (e) {
        developer.log("Live Loop Error: $e");
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> clearChat() async {
    await _localDb.clearChatHistory();
    _dialogue = null;
    notifyListeners();
  }

  void showTutorMessage(String message, {SumiState state = SumiState.thinking}) {
    _dialogue = message;
    _currentState = state;
    notifyListeners();
  }

  void setFocusedMode(bool isFocused) {
    _context = _context.copyWith(isFocusedMode: isFocused);
    if (isFocused) {
      _currentState = SumiState.focused;
      emitEvent(SumiEvent.studySessionStarted);
      _focusTimer?.cancel();
      _focusTimer = Timer(const Duration(seconds: 10), () {
        _currentState = SumiState.idle;
        notifyListeners();
      });
    } else {
      _currentState = SumiState.idle;
    }
    notifyListeners();
  }

  Timer? _focusTimer;

  void clearDialogue() {
    _dialogue = null;
    notifyListeners();
  }

  void emitEvent(SumiEvent event) {
    _updateContextForEvent(event);
    final nextState = _engine.compute(
      currentState: _currentState,
      event: event,
      context: _context,
    );
    if (nextState != _currentState) {
      _currentState = nextState;
      notifyListeners();
    }
  }

  void _updateContextForEvent(SumiEvent event) {
    int streak = _context.streak;
    int wrongStreak = _context.wrongStreak;

    if (event == SumiEvent.answerCorrect || event == SumiEvent.streakIncreased) {
      streak += 1;
      wrongStreak = 0;
    } else if (event == SumiEvent.answerWrong || event == SumiEvent.streakBroken) {
      streak = 0;
      wrongStreak += 1;
    }

    _context = _context.copyWith(
      streak: streak,
      wrongStreak: wrongStreak,
      lastInteraction: DateTime.now(),
    );
  }

  void incrementSessionLength() {
    _context = _context.copyWith(sessionLength: _context.sessionLength + 1);
  }

  void updateEnergyState(NeuralState state) {
    switch (state) {
      case NeuralState.highEnergy:
        _currentState = SumiState.idle;
        _dialogue = "Your neural momentum is incredible! Ready for a deep dive?";
        break;
      case NeuralState.fatigued:
        _currentState = SumiState.focused;
        _dialogue = "Steady flow detected. I'll focus on the essentials to keep us moving.";
        break;
      case NeuralState.exhausted:
        _currentState = SumiState.thinking;
        _dialogue = "Cognitive load is high. Let's simplify and summarize our progress.";
        break;
      case NeuralState.depleted:
        _currentState = SumiState.tired;
        _dialogue = "Neural pathways need rest. Let's pause and integrate what you've learned. Sumi will be ready for more tomorrow!";
        break;
    }
    notifyListeners();
  }

  void triggerBrainAlert() {
    emitEvent(SumiEvent.brainAlert);
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _focusTimer?.cancel();
    super.dispose();
  }
}

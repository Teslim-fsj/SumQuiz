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
import 'package:flutter_tts/flutter_tts.dart';
import '../services/usage_service.dart';
import '../services/auth_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';

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

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
      androidWillPauseWhenDucked: true,
    ));
  }

  void _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      developer.log("TTS completed a sentence", name: "SumiProvider");
      _cancelTtsWatchdog();
      _speakNextInQueue();
    });

    _tts.setErrorHandler((msg) {
      developer.log("TTS Error: $msg", name: "SumiProvider");
      _cancelTtsWatchdog();
      _speakNextInQueue();
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

  final List<String> _ttsQueue = [];
  bool _isTtsActive = false;
  bool get isTtsActive => _isTtsActive;
  Timer? _ttsWatchdogTimer;

  Timer? _vadTimer;
  int _silenceCount = 0;
  bool _hasSpeaked = false;
  static const int silenceThreshold = 12; // ~1.2s (100ms * 12)
  static const double amplitudeThreshold = -45.0; // dB — sensitive for quiet mics

  SumiState _currentState = SumiState.idle;
  SumiState get currentState => _currentState;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _limitReached = false;
  bool get limitReached => _limitReached;

  void clearLimitReached() {
    _limitReached = false;
    _errorMessage = null;
    notifyListeners();
  }

  List<SumiMessage> _messages = [];
  List<SumiMessage> get messages => List.unmodifiable(_messages);

  EmotionContext _context = EmotionContext(
    streak: 0,
    sessionLength: 0,
    wrongStreak: 0,
    isFocusedMode: false,
    lastInteraction: DateTime.now(),
  );

  String? _dialogue;
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

  Future<void> askSumi(String prompt,
      {String? context, String? userName}) async {
    final uid = _authService.currentUser?.uid;
    if (uid != null && _usageService != null) {
      final canProceed = await _usageService.canPerformAction(uid, 'tutor');
      if (!canProceed) {
        _limitReached = true;
        _currentState = SumiState.tired;
        _dialogue = "I've reached my limit — let's power up your plan!";
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
      final history = _messages.reversed
          .take(5)
          .toList()
          .reversed
          .map((m) =>
              "${m.role == MessageRole.user ? 'Student' : 'Sumi'}: ${m.text}")
          .join("\n");

      final stream = _aiService.getTutorResponseStream(
        prompt: prompt,
        context: history + (context != null ? "\nFILE CONTEXT: $context" : ""),
        userName: userName,
      );

      String lastSpokenSentence = "";
      await for (final chunk in stream) {
        fullResponse += chunk;
        _streamingMessage = fullResponse;
        _dialogue = fullResponse;
        notifyListeners();

        // Trigger TTS for completed sentences if in Live Session
        if (_isLiveSession) {
          final sentences = fullResponse.split(RegExp(r'(?<=[.!?])\s+'));
          if (sentences.length > 1) {
            for (int i = 0; i < sentences.length - 1; i++) {
              final sentence = sentences[i].trim();
              if (sentence.isNotEmpty &&
                  !lastSpokenSentence.contains(sentence)) {
                _speakSentence(sentence);
                lastSpokenSentence += " $sentence";
              }
            }
          }
        }
      }

      // Final speak for any remaining text
      if (_isLiveSession) {
        final sentences = fullResponse.split(RegExp(r'(?<=[.!?])\s+'));
        final last = sentences.last.trim();
        if (last.isNotEmpty && !lastSpokenSentence.contains(last)) {
          await _speakResponse(last);
        }
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
      _dialogue =
          "Oops, my neural circuits got a bit tangled! Let's try that again?";
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

      await _configureAudioSession();
      final session = await AudioSession.instance;
      await session.setActive(true);

      _isVoiceRecording = true;
      _recordingDuration = Duration.zero;
      _currentState = SumiState.idle;
      notifyListeners();

      await _recordingService.startRecording("sumi_voice");
      HapticFeedback.lightImpact();

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
      final session = await AudioSession.instance;
      await session.setActive(false);

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

  Future<void> _processVoiceInput(Uint8List audioBytes,
      {String? context}) async {
    final uid = _authService.currentUser?.uid;
    if (uid != null && _usageService != null) {
      final canProceed = await _usageService.canPerformAction(uid, 'tutor');
      if (!canProceed) {
        _limitReached = true;
        _currentState = SumiState.tired;
        _dialogue = "I've reached my limit — let's power up your plan!";
        notifyListeners();
        return;
      }
    }

    // Phase 5: Build context from last 5 messages
    final history = _messages.reversed
        .take(5)
        .toList()
        .reversed
        .map((m) =>
            "${m.role == MessageRole.user ? 'Student' : 'Sumi'}: ${m.text}")
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

      // Robust regex-based parsing
      final transcriptionRegex = RegExp(
          r'(?:\*\*?)?TRANSCRIPTION(?:\*\*?)?\s*:\s*(.*?)(?=(?:\*\*?)?RESPONSE(?:\*\*?)?\s*:|$)',
          caseSensitive: false,
          dotAll: true);
      final responseRegex = RegExp(r'(?:\*\*?)?RESPONSE(?:\*\*?)?\s*:\s*(.*)',
          caseSensitive: false, dotAll: true);

      final transMatch = transcriptionRegex.firstMatch(rawResponse);
      final respMatch = responseRegex.firstMatch(rawResponse);

      if (transMatch != null) {
        transcription = transMatch.group(1)!.trim();
      }
      if (respMatch != null) {
        response = respMatch.group(1)!.trim();
      } else if (transMatch == null) {
        response = rawResponse.trim();
      }

      if (response.isEmpty) {
        response = rawResponse.trim();
      }

      _isStreaming = false;
      await addMessage(transcription, MessageRole.user);
      await addMessage(response, MessageRole.sumi);

      // Record usage after successful completion
      if (uid != null && _usageService != null) {
        await _usageService.recordAction(uid, 'tutor');
      }

      _dialogue = response;
      _currentState = SumiState.analytical;
      notifyListeners();

      if (_isLiveSession && response.isNotEmpty) {
        await _speakResponse(response);
      }
    } catch (e) {
      _isStreaming = false;
      _dialogue = "Neural gap detected. Say that again?";
      notifyListeners();
    }
  }

  void _startTtsWatchdog(String text) {
    _ttsWatchdogTimer?.cancel();
    final estimatedMs = (text.length * 75).clamp(3000, 15000);
    _ttsWatchdogTimer = Timer(Duration(milliseconds: estimatedMs), () {
      developer.log(
          "TTS Watchdog triggered (completion handler missed). Moving next.",
          name: "SumiProvider");
      _speakNextInQueue();
    });
  }

  void _cancelTtsWatchdog() {
    _ttsWatchdogTimer?.cancel();
    _ttsWatchdogTimer = null;
  }

  Future<void> _speakNextInQueue() async {
    _cancelTtsWatchdog();

    if (_ttsQueue.isEmpty) {
      _isTtsActive = false;
      _isSumiSpeaking = false;
      _currentState = SumiState.idle;
      notifyListeners();
      return;
    }

    _isTtsActive = true;
    _isSumiSpeaking = true;
    _currentState = SumiState.speaking;
    notifyListeners();

    final text = _ttsQueue.removeAt(0);
    try {
      final cleanText = text.replaceAll(RegExp(r'[*_#]'), '').trim();
      if (cleanText.isNotEmpty) {
        developer.log("Speaking from queue: $cleanText", name: "SumiProvider");
        _startTtsWatchdog(cleanText);
        await _tts.speak(cleanText);
      } else {
        _speakNextInQueue();
      }
    } catch (e) {
      developer.log("TTS Queue speak error: $e", name: "SumiProvider");
      _speakNextInQueue();
    }
  }

  void _enqueueSentence(String text) {
    if (text.trim().isEmpty) return;
    _ttsQueue.add(text);
    if (!_isTtsActive) {
      _speakNextInQueue();
    }
  }

  Future<void> _speakSentence(String text) async {
    _enqueueSentence(text);
  }

  Future<void> _speakResponse(String text) async {
    _ttsQueue.clear();
    _isTtsActive = false;
    _enqueueSentence(text);

    while (_isTtsActive) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> startLiveSession({String? context}) async {
    if (_isLiveSession) return;

    final uid = _authService.currentUser?.uid;
    if (uid != null && _usageService != null) {
      final canProceed =
          await _usageService.canPerformAction(uid, 'tutor_session');
      if (!canProceed) {
        _limitReached = true;
        _dialogue = "I've reached my limit — let's power up your plan!";
        _currentState = SumiState.tired;
        notifyListeners();
        return;
      }
      await _usageService.recordAction(uid, 'tutor_session');
    }

    try {
      await _configureAudioSession();
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (e) {
      developer.log("AudioSession activation error: $e", name: "SumiProvider");
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
    _cancelTtsWatchdog();
    _ttsQueue.clear();
    _isTtsActive = false;
    try {
      await _recordingService.stopRecording();
      await _recordingService.stopPlayer();
      await _tts.stop();
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      developer.log("Error tearing down voice session: $e",
          name: "SumiProvider");
    }
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
        int gracePeriod = 0;
        while (_isVoiceRecording && _isLiveSession) {
          await Future.delayed(const Duration(milliseconds: 100));
          gracePeriod++;

          final amp = await _recordingService.getAmplitude();
          if (amp.current > amplitudeThreshold) {
            peakCount++;
            if (peakCount > 1) {
              _silenceCount = 0;
              _hasSpeaked = true;
            }
          } else {
            peakCount = 0;
            if (_hasSpeaked) _silenceCount++;
          }

          // Force stop if too long or silence threshold reached after speaking
          if ((_hasSpeaked && _silenceCount >= silenceThreshold) ||
              _recordingDuration.inSeconds > 30 ||
              (gracePeriod > 100 && !_hasSpeaked)) {
            // Stop after 10s of silence if no speech
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

  void showTutorMessage(String message,
      {SumiState state = SumiState.thinking}) {
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

  void clearError() {
    _errorMessage = null;
    _currentState = SumiState.idle;
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

    if (event == SumiEvent.answerCorrect ||
        event == SumiEvent.streakIncreased) {
      streak += 1;
      wrongStreak = 0;
    } else if (event == SumiEvent.answerWrong ||
        event == SumiEvent.streakBroken) {
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
        _dialogue =
            "Your neural momentum is incredible! Ready for a deep dive?";
        break;
      case NeuralState.fatigued:
        _currentState = SumiState.focused;
        _dialogue =
            "Steady flow detected. I'll focus on the essentials to keep us moving.";
        break;
      case NeuralState.exhausted:
        _currentState = SumiState.thinking;
        _dialogue =
            "Cognitive load is high. Let's simplify and summarize our progress.";
        break;
      case NeuralState.depleted:
        _currentState = SumiState.tired;
        _dialogue =
            "Neural pathways need rest. Let's pause and integrate what you've learned. Sumi will be ready for more tomorrow!";
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
    _cancelTtsWatchdog();
    _ttsQueue.clear();
    super.dispose();
  }
}

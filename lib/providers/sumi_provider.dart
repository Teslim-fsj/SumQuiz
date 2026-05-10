import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sumi_emotion.dart';
import '../services/ai/ai_config.dart';
import '../models/sumi_message.dart';
import '../services/ai/generator_ai_service.dart';
import '../services/local_database_service.dart';

class SumiProvider extends ChangeNotifier {
  final GeneratorAIService _aiService;
  final LocalDatabaseService _localDb;
  final SumiEmotionEngine _engine = SumiEmotionEngine();

  SumiProvider({
    required GeneratorAIService aiService,
    required LocalDatabaseService localDb,
  })  : _aiService = aiService,
        _localDb = localDb {
    _initChatHistory();
  }

  SumiState _currentState = SumiState.idle;
  SumiState get currentState => _currentState;

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

  Future<void> askSumi(String prompt, {String? context, String? userName}) async {
    // 1. Add user message
    await addMessage(prompt, MessageRole.user);

    // 2. Set thinking state
    _currentState = SumiState.thinking;
    _isStreaming = true;
    _streamingMessage = "";
    notifyListeners();

    try {
      String fullResponse = '';
      
      final stream = _aiService.getTutorResponseStream(
        prompt: prompt,
        context: context,
        userName: userName,
      );

      await for (final chunk in stream) {
        fullResponse += chunk;
        _streamingMessage = fullResponse;
        _dialogue = fullResponse;
        notifyListeners();
      }

      // 4. Save full response to DB
      _isStreaming = false;
      await addMessage(fullResponse, MessageRole.sumi);
      
      // 5. Update emotion based on response length/tone
      if (fullResponse.length > 200) {
        _currentState = SumiState.analytical;
      } else {
        _currentState = SumiState.idle;
      }
      notifyListeners();
      
    } catch (e) {
      _isStreaming = false;
      _currentState = SumiState.tired;
      _dialogue = "I'm having a bit of trouble connecting to my neural network. Let's try again in a moment!";
      notifyListeners();
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

import 'package:flutter/material.dart';
import '../models/sumi_emotion.dart';

class SumiProvider extends ChangeNotifier {
  final SumiEmotionEngine _engine = SumiEmotionEngine();

  SumiState _currentState = SumiState.idle;
  SumiState get currentState => _currentState;

  EmotionContext _context = EmotionContext(
    streak: 0,
    sessionLength: 0,
    wrongStreak: 0,
    isFocusedMode: false,
    lastInteraction: DateTime.now(),
  );

  EmotionContext get currentContext => _context;

  void emitEvent(SumiEvent event) {
    // 1. Update context before processing event
    _updateContextForEvent(event);

    // 2. Compute next state
    final nextState = _engine.compute(
      currentState: _currentState,
      event: event,
      context: _context,
    );

    // 3. Update state if changed
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

  void setFocusedMode(bool isFocused) {
    _context = _context.copyWith(isFocusedMode: isFocused);
    emitEvent(SumiEvent.studySessionStarted); 
  }
}

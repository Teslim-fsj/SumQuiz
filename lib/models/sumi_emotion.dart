enum SumiState {
  idle,
  focused,
  thinking,
  correct,
  incorrect,
  celebrating,
  reviewing,
  confused,
  streakBoost,
  tired,
  analytical,
}

enum SumiEvent {
  appOpened,
  studySessionStarted,
  quizStarted,
  answerCorrect,
  answerWrong,
  flashcardReviewed,
  streakIncreased,
  streakBroken,
  idleTimeout,
  longSession,
  userPaused,
  brainAlert,
}

class EmotionContext {
  final int streak;
  final int sessionLength;
  final int wrongStreak;
  final bool isFocusedMode;
  final DateTime lastInteraction;

  EmotionContext({
    required this.streak,
    required this.sessionLength,
    required this.wrongStreak,
    required this.isFocusedMode,
    required this.lastInteraction,
  });

  EmotionContext copyWith({
    int? streak,
    int? sessionLength,
    int? wrongStreak,
    bool? isFocusedMode,
    DateTime? lastInteraction,
  }) {
    return EmotionContext(
      streak: streak ?? this.streak,
      sessionLength: sessionLength ?? this.sessionLength,
      wrongStreak: wrongStreak ?? this.wrongStreak,
      isFocusedMode: isFocusedMode ?? this.isFocusedMode,
      lastInteraction: lastInteraction ?? this.lastInteraction,
    );
  }
}

class SumiEmotionEngine {
  SumiState compute({
    required SumiState currentState,
    required SumiEvent event,
    required EmotionContext context,
  }) {
    SumiState nextState = currentState;

    if (event == SumiEvent.answerCorrect) {
      if (context.streak >= 3) {
        nextState = SumiState.celebrating;
      } else {
        nextState = SumiState.correct;
      }
    } else if (event == SumiEvent.answerWrong) {
      if (context.wrongStreak >= 2) {
        nextState = SumiState.confused;
      } else {
        nextState = SumiState.incorrect;
      }
    } else if (event == SumiEvent.quizStarted ||
        event == SumiEvent.studySessionStarted) {
      nextState = SumiState.focused;
    } else if (event == SumiEvent.flashcardReviewed) {
      nextState = SumiState.reviewing;
    } else if (event == SumiEvent.idleTimeout) {
      if (context.sessionLength > 20) {
        nextState = SumiState.tired;
      } else {
        nextState = SumiState.idle;
      }
    } else if (event == SumiEvent.streakIncreased) {
      if (context.streak % 5 == 0) {
        nextState = SumiState.streakBoost;
      } else {
        nextState = SumiState.correct;
      }
    } else if (event == SumiEvent.appOpened || event == SumiEvent.userPaused) {
      nextState = SumiState.idle;
    } else if (event == SumiEvent.brainAlert) {
      nextState = SumiState.analytical;
    }

    return _enhance(nextState, context);
  }

  SumiState _enhance(SumiState state, EmotionContext context) {
    if (context.isFocusedMode && state == SumiState.idle) {
      return SumiState.focused;
    }
    if (context.sessionLength > 30 && state == SumiState.focused) {
      return SumiState.tired;
    }
    return state;
  }
}

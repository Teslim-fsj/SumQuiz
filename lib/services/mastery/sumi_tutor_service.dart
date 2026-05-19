import '../ai/generator_ai_service.dart';
import '../mastery/recommendation_service.dart';
import '../mastery_service.dart';
import '../notification_service.dart';

class SumiTutorService {
  final MasteryService _masteryService;
  final RecommendationService _recommendationService;
  final NotificationService? _notificationService;
  final GeneratorAIService _generatorService;

  SumiTutorService(
      this._masteryService, this._recommendationService, this._generatorService,
      [this._notificationService]);

  /// Analyzes the current brain state and schedules a retention alert if needed.
  Future<void> checkAndScheduleRetentionAlert(String userId) async {
    if (_notificationService == null) return;

    final recs = _recommendationService.getDailyRecommendations(userId);
    if (recs.isNotEmpty) {
      final critical = recs.where((r) => r.priorityScore > 0.8).toList();
      if (critical.isNotEmpty) {
        await _notificationService.scheduleALPSNotification(
          topicName: critical.first.topic.name,
        );
      }
    }
  }

  /// Generates a proactive coaching greeting based on the user's brain state.
  String getProactiveGreeting(String userId, String userName) {
    final recs = _recommendationService.getDailyRecommendations(userId);

    if (recs.isEmpty) {
      return "Hi $userName! You haven't started any topics yet. Want to generate some study material?";
    }

    final topRec = recs.first;

    if (topRec.type == RecommendationType.quickRefresh) {
      return "Hey $userName! I noticed your memory of '${topRec.topic.name}' is starting to fade. Want to lock it back in with a quick 2-minute refresh?";
    } else if (topRec.type == RecommendationType.weaknessDrill) {
      return "Hi $userName. '${topRec.topic.name}' seems to be a bit of a struggle point lately. Let's do a short drill to clear things up?";
    } else {
      return "Welcome back, $userName! Ready to dive back into '${topRec.topic.name}'? It's the best next step for your progress.";
    }
  }

  /// Provides a Socratic hint when a user gets an answer wrong.
  /// If [sourceName] is provided, Sumi will ground the hint in that specific material.
  Future<String> getSocraticHint({
    required String topicName,
    required String question,
    required String wrongAnswer,
    String? sourceName,
    int? sourcePage,
  }) async {
    final aiService = _generatorService;

    final prompt = '''You are Sumi, a Socratic tutor. 
Topic: $topicName
Question: $question
User's Incorrect Answer: $wrongAnswer
${sourceName != null ? "Context: This question is from '$sourceName'." : ""}

Task: Provide a short (max 40 words), encouraging Socratic hint. 
Do NOT give the answer. Guide them with a question or a "think about..." prompt.
Stay friendly, neural-themed, and concise.''';

    try {
      final hint = await aiService.refineContent(prompt);

      if (sourceName != null) {
        final pageInfo = sourcePage != null ? " on page $sourcePage" : "";
        return "Sumi Tip: Your material from '$sourceName'$pageInfo has a clue. $hint";
      }
      return hint;
    } catch (e) {
      // Fallback
      return "Think about how this relates to $topicName. Are you considering the impact of the core principle?";
    }
  }

  /// Detects potential burnout based on accuracy and session behavior.
  bool detectBurnout(int wrongStreak, int sessionMinutes) {
    if (wrongStreak >= 3) return true;
    if (sessionMinutes > 45) return true;
    return false;
  }

  String getBurnoutAdvice() {
    return "You've been working hard, but your accuracy is dipping. How about a 5-minute break? Your brain will retain the info much better if we reset now.";
  }
}

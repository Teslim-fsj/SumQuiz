import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/mastery/topic_node.dart';
import '../models/spaced_repetition.dart';
import '../models/mastery/mastery_history.dart';
import 'local_database_service.dart';

enum SignalType {
  quizCorrect,
  quizWrong,
  noteRead,
  summaryRead,
  flashcardSuccess,
  flashcardFailure,
  manualConfidenceUpdate,
  noteReread
}

class LearningSignal {
  final String topicId;
  final SignalType type;
  final double magnitude; // 0.0 to 1.0
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  LearningSignal({
    required this.topicId,
    required this.type,
    this.magnitude = 1.0,
    this.metadata = const {},
    required this.timestamp,
  });
}

class MasteryService extends ChangeNotifier {
  final Box<TopicNode> _topicBox;
  final Box<SpacedRepetitionItem> _srsBox;

  MasteryService(this._topicBox, this._srsBox);

  /// Process a new learning signal and update the topic mastery
  Future<void> processSignal(LearningSignal signal) async {
    final topic = _topicBox.get(signal.topicId);
    if (topic == null) return;

    double newMastery = topic.masteryScore;
    double newStability = topic.stabilityScore;
    double newConfidence = topic.confidenceScore;

    switch (signal.type) {
      case SignalType.quizCorrect:
        // Quiz Correct -> +Recall Strength (Stability)
        final isFast = signal.metadata['isFast'] == true;
        if (isFast) {
          // Quiz Fast Correct -> +Confidence
          newConfidence += 0.08;
          newStability += 0.05;
          newMastery += 0.03;
        } else {
          // Quiz Slow Correct -> weak stability
          newStability += 0.02;
          newMastery += 0.01;
        }
        break;
      case SignalType.quizWrong:
        // Quiz Wrong -> forgetting spike
        newStability *= 0.6; // Sharp drop
        newMastery -= 0.05;
        newConfidence -= 0.10;
        break;
      case SignalType.summaryRead:
        // Summary Read -> +Comprehension (Mastery)
        newMastery += 0.04;
        newStability += 0.01;
        break;
      case SignalType.flashcardSuccess:
        // Flashcard Success -> retention boost (Stability)
        newStability += 0.06;
        newMastery += 0.02;
        break;
      case SignalType.flashcardFailure:
        // Flashcard Failure -> decay acceleration
        newStability *= 0.75;
        newMastery -= 0.02;
        break;
      case SignalType.noteRead:
        newStability += 0.01;
        newMastery += 0.01;
        break;
      case SignalType.noteReread:
        // Re-reading Notes -> partial reinforcement
        newStability += 0.015;
        break;
      case SignalType.manualConfidenceUpdate:
        newConfidence = signal.magnitude;
        break;
    }

    // Constraints
    topic.masteryScore = newMastery.clamp(0.0, 1.0);
    topic.stabilityScore = newStability.clamp(0.0, 1.0);
    topic.confidenceScore = newConfidence.clamp(0.0, 1.0);
    topic.lastInteraction = signal.timestamp;

    // Update velocity (simplified: change in mastery)
    topic.learningVelocity = (newMastery - topic.masteryScore).abs();

    await topic.save();
    
    // Save history snapshot (Throttled by day or session)
    final userId = topic.userId;
    _saveMasterySnapshot(userId);

    notifyListeners();
  }

  Future<void> _saveMasterySnapshot(String userId) async {
    final avg = getAverageMastery(userId);
    final history = MasteryHistory(
      userId: userId,
      averageMastery: avg,
      timestamp: DateTime.now(),
    );
    
    // We'll use a singleton or injected DB service here
    await LocalDatabaseService().saveMasteryHistory(history);
  }

  /// Get or create a topic by name
  Future<TopicNode> getOrCreateTopic(String userId, String name,
      {String? parentId}) async {
    final existing = _topicBox.values
        .where((t) =>
            t.userId == userId && t.name.toLowerCase() == name.toLowerCase())
        .toList();

    if (existing.isNotEmpty) return existing.first;

    final newTopic = TopicNode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      userId: userId,
      parentId: parentId,
      lastInteraction: DateTime.now(),
      createdAt: DateTime.now(),
      contentIds: [],
    );

    await _topicBox.put(newTopic.id, newTopic);
    return newTopic;
  }

  /// Get user topics
  List<TopicNode> getUserTopics(String userId) {
    return _topicBox.values.where((t) => t.userId == userId).toList();
  }

  /// Calculates the Adaptive Learning Priority Score (ALPS) for a topic.
  /// Result is between 0.0 and 1.0, where 1.0 is highest priority.
  double calculateALPS(TopicNode topic) {
    // 1. Forgetting Risk (40%)
    double riskPart = topic.forgettingRisk * 0.4;

    // 2. Weakness (30%) - Inverse of mastery
    double weaknessPart = (1.0 - topic.masteryScore) * 0.3;

    // 3. Low Stability Penalty (20%) - New or volatile knowledge needs more attention
    double stabilityPart = (1.0 - topic.stabilityScore) * 0.2;

    // 4. Overdue Factor (10%) - Based on last interaction time
    final daysSinceLastInteraction =
        DateTime.now().difference(topic.lastInteraction).inDays;
    double overduePart = (daysSinceLastInteraction / 7.0).clamp(0.0, 1.0) * 0.1;

    return (riskPart + weaknessPart + stabilityPart + overduePart).clamp(0.0, 1.0);
  }

  /// Get top priority topics for the user based on ALPS
  List<TopicNode> getPriorityTopics(String userId, {int limit = 3}) {
    final topics = getUserTopics(userId);
    topics.sort((a, b) => calculateALPS(b).compareTo(calculateALPS(a)));
    return topics.take(limit).toList();
  }

  /// Get weak zones for a user
  List<TopicNode> getWeakZones(String userId, {double threshold = 0.4}) {
    return _topicBox.values
        .where((t) => t.userId == userId && t.masteryScore < threshold)
        .toList()
      ..sort((a, b) => b.forgettingRisk.compareTo(a.forgettingRisk));
  }

  /// Get Overall Mastery Score for Dashboard
  double getAverageMastery(String userId) {
    final topics = _topicBox.values.where((t) => t.userId == userId).toList();
    if (topics.isEmpty) return 0.0;
    return topics.map((t) => t.masteryScore).reduce((a, b) => a + b) /
        topics.length;
  }
}

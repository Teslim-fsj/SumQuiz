import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
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
  final LocalDatabaseService _localDb;

  // Throttle snapshots: TopicID -> LastSnapshotTime
  final Map<String, DateTime> _lastSnapshots = {};

  MasteryService(this._topicBox, this._srsBox, this._localDb);

  /// Process a new learning signal and update the topic mastery
  Future<void> processSignal(LearningSignal signal) async {
    final topic = _topicBox.get(signal.topicId);
    if (topic == null) return;

    final double oldMastery = topic.masteryScore;
    double newMastery = topic.masteryScore;
    double newStability = topic.stabilityScore;
    double newConfidence = topic.confidenceScore;

    switch (signal.type) {
      case SignalType.quizCorrect:
        final isFast = signal.metadata['isFast'] == true;
        if (isFast) {
          newConfidence += 0.08;
          newStability += 0.05;
          newMastery += 0.03;
        } else {
          newStability += 0.02;
          newMastery += 0.01;
        }
        break;
      case SignalType.quizWrong:
        newStability *= 0.6;
        newMastery -= 0.05;
        newConfidence -= 0.10;
        break;
      case SignalType.summaryRead:
        newMastery += 0.04;
        newStability += 0.01;
        break;
      case SignalType.flashcardSuccess:
        newStability += 0.06;
        newMastery += 0.02;
        break;
      case SignalType.flashcardFailure:
        newStability *= 0.75;
        newMastery -= 0.02;
        break;
      case SignalType.noteRead:
        newStability += 0.01;
        newMastery += 0.01;
        break;
      case SignalType.noteReread:
        newStability += 0.015;
        break;
      case SignalType.manualConfidenceUpdate:
        newConfidence = signal.magnitude;
        break;
    }

    // Velocity = |New - Old|
    topic.learningVelocity = (newMastery - oldMastery).abs();
    
    // Constraints
    topic.masteryScore = newMastery.clamp(0.0, 1.0);
    topic.stabilityScore = newStability.clamp(0.0, 1.0);
    topic.confidenceScore = newConfidence.clamp(0.0, 1.0);
    topic.lastInteraction = signal.timestamp;

    await topic.save();
    
    // Save history snapshot (Throttled: max 1 per 5 minutes per topic/user)
    _saveMasterySnapshot(topic);

    notifyListeners();
  }

  Future<void> _saveMasterySnapshot(TopicNode topic) async {
    final now = DateTime.now();
    final key = topic.id;
    
    if (_lastSnapshots.containsKey(key)) {
      if (now.difference(_lastSnapshots[key]!).inMinutes < 5) {
        return; // Throttled
      }
    }
    
    _lastSnapshots[key] = now;

    // Per-Topic Snapshot
    final topicHistory = MasteryHistory(
      userId: topic.userId,
      averageMastery: topic.masteryScore,
      timestamp: now,
      topicId: topic.id,
      topicName: topic.name,
    );
    await _localDb.saveMasteryHistory(topicHistory);

    // Global Snapshot (Throttled separately or just every topic update)
    if (_lastSnapshots.containsKey('global_${topic.userId}')) {
      if (now.difference(_lastSnapshots['global_${topic.userId}']!).inMinutes < 15) {
        return;
      }
    }
    _lastSnapshots['global_${topic.userId}'] = now;

    final avg = getAverageMastery(topic.userId);
    final globalHistory = MasteryHistory(
      userId: topic.userId,
      averageMastery: avg,
      timestamp: now,
    );
    await _localDb.saveMasteryHistory(globalHistory);
  }

  /// Get or create a topic by name, using fuzzy matching to prevent duplicates
  Future<TopicNode> getOrCreateTopic(String userId, String name,
      {String? parentId}) async {
    final String normalizedName = name.trim().toLowerCase();
    
    // 1. Exact/Normalized match
    final existing = _topicBox.values
        .where((t) =>
            t.userId == userId && t.name.toLowerCase() == normalizedName)
        .toList();

    if (existing.isNotEmpty) return existing.first;

    // 2. Fuzzy match (Levenshtein distance)
    for (var topic in _topicBox.values.where((t) => t.userId == userId)) {
      if (_calculateLevenshtein(topic.name.toLowerCase(), normalizedName) <= 2) {
        developer.log('Fuzzy match found: "${topic.name}" for "$name"', name: 'MasteryService');
        return topic;
      }
    }

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

  int _calculateLevenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> previousRow = List<int>.generate(s2.length + 1, (i) => i);
    for (int i = 0; i < s1.length; i++) {
      List<int> currentRow = [i + 1];
      for (int j = 0; j < s2.length; j++) {
        int insertions = previousRow[j + 1] + 1;
        int deletions = currentRow[j] + 1;
        int substitutions = previousRow[j] + (s1[i] == s2[j] ? 0 : 1);
        currentRow.add([insertions, deletions, substitutions].reduce((a, b) => a < b ? a : b));
      }
      previousRow = currentRow;
    }
    return previousRow.last;
  }

  /// Get user topics
  List<TopicNode> getUserTopics(String userId) {
    return _topicBox.values.where((t) => t.userId == userId).toList();
  }

  /// Get mastery for a specific topic
  double getTopicMastery(String topicId) {
    final topic = _topicBox.get(topicId);
    return topic?.masteryScore ?? 0.0;
  }

  /// Calculates the Adaptive Learning Priority Score (ALPS) for a topic.
  /// Result is between 0.0 and 1.0, where 1.0 is highest priority.
  double calculateALPS(TopicNode topic) {
    // 1. Forgetting Risk (40%) - Uses the new exponential model
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
    // Exclude very recently studied topics (within 30 mins) unless extremely high risk
    final filtered = topics.where((t) {
      final minsSince = DateTime.now().difference(t.lastInteraction).inMinutes;
      return minsSince > 30 || t.forgettingRisk > 0.8;
    }).toList();
    
    filtered.sort((a, b) => calculateALPS(b).compareTo(calculateALPS(a)));
    return filtered.take(limit).toList();
  }

  /// Get weak zones for a user
  List<TopicNode> getWeakZones(String userId, {double threshold = 0.4}) {
    return _topicBox.values
        .where((t) => t.userId == userId && t.masteryScore < threshold)
        .toList()
      ..sort((a, b) => b.forgettingRisk.compareTo(a.forgettingRisk));
  }

  /// Cleanup topics that are no longer linked to any content
  Future<void> cleanupOrphanedTopics(String userId, List<String> activeContentIds) async {
    final setValidIds = activeContentIds.toSet();
    final toDelete = _topicBox.values
        .where((t) => t.userId == userId && t.contentIds.every((id) => !setValidIds.contains(id)))
        .map((t) => t.id)
        .toList();
    
    for (final id in toDelete) {
      await _topicBox.delete(id);
    }
    if (toDelete.isNotEmpty) {
      developer.log('Pruned ${toDelete.length} orphaned topics', name: 'MasteryService');
    }
  }

  /// Prune mastery history snapshots older than [keepDays]
  Future<void> pruneSnapshots(String userId, {int keepDays = 90}) async {
    // Note: History is usually in a separate box or Firestore. 
    // Assuming it's in LocalDatabaseService's history box.
    await _localDb.pruneHistory(userId, keepDays);
  }

  /// Get Overall Mastery Score for Dashboard
  double getAverageMastery(String userId) {
    final topics = _topicBox.values.where((t) => t.userId == userId).toList();
    if (topics.isEmpty) return 0.0;
    return topics.map((t) => t.masteryScore).reduce((a, b) => a + b) /
        topics.length;
  }
}

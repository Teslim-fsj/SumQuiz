import '../mastery_service.dart';
import '../../models/mastery/topic_node.dart';

enum RecommendationType {
  quickRefresh, // High risk, medium/high mastery -> Quick recall
  weaknessDrill, // High risk, low mastery -> Quiz
  deepDive, // Low stability, new knowledge -> Summary/Note review
  stableMaintenance // High stability -> Skip or light review
}

class StudyRecommendation {
  final TopicNode topic;
  final RecommendationType type;
  final String title;
  final String description;
  final String actionLabel;
  final double priorityScore;

  StudyRecommendation({
    required this.topic,
    required this.type,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.priorityScore,
  });
}

class RecommendationService {
  final MasteryService _masteryService;

  RecommendationService(this._masteryService);

  List<StudyRecommendation> getDailyRecommendations(String userId) {
    final priorityTopics = _masteryService.getPriorityTopics(userId, limit: 3);

    return priorityTopics
        .map((topic) {
          final alps = _masteryService.calculateALPS(topic);
          if (alps < 0.2) return null;

          if (topic.forgettingRisk > 0.7 && topic.masteryScore > 0.6) {
            return StudyRecommendation(
              topic: topic,
              type: RecommendationType.quickRefresh,
              title: 'Quick Refresh: ${topic.name}',
              description:
                  'Your memory is fading, but you know this well. A 2-minute review will lock it back in.',
              actionLabel: 'Recall Now',
              priorityScore: alps,
            );
          } else if (topic.masteryScore < 0.4) {
            return StudyRecommendation(
              topic: topic,
              type: RecommendationType.weaknessDrill,
              title: 'Drill: ${topic.name}',
              description:
                  'This is a weak spot. Let\'s try a quick quiz to strengthen the connections.',
              actionLabel: 'Start Quiz',
              priorityScore: alps,
            );
          } else if (topic.stabilityScore < 0.3) {
            return StudyRecommendation(
              topic: topic,
              type: RecommendationType.deepDive,
              title: 'Review: ${topic.name}',
              description:
                  'This concept is new and hasn\'t stabilized yet. Reading your notes again will help.',
              actionLabel: 'Read Notes',
              priorityScore: alps,
            );
          } else if (topic.forgettingRisk > 0.4) {
            return StudyRecommendation(
              topic: topic,
              type: RecommendationType.stableMaintenance,
              title: 'Maintenance: ${topic.name}',
              description: 'Keep the momentum going with a light review.',
              actionLabel: 'Review',
              priorityScore: alps,
            );
          }
          return null;
        })
        .whereType<StudyRecommendation>()
        .toList();
  }
}

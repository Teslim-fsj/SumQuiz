import 'dart:math' as math;
import 'package:hive/hive.dart';

part 'topic_node.g.dart';

@HiveType(typeId: 30)
class TopicNode extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  String? parentId;

  @HiveField(3)
  late String userId;

  // Cognitive Metrics (0.0 to 1.0)
  @HiveField(4)
  late double masteryScore; // Depth of knowledge

  @HiveField(5)
  late double stabilityScore; // Resistance to forgetting

  @HiveField(6)
  late double confidenceScore; // Self-reported or speed-inferred

  // Temporal Metrics
  @HiveField(7)
  late DateTime lastInteraction;

  @HiveField(8)
  late double learningVelocity; // Rate of change in mastery over time

  @HiveField(9)
  late DateTime createdAt;

  // content mapping
  @HiveField(10)
  late List<String> contentIds; // Links to LocalNote, LocalQuiz, etc.

  @HiveField(11)
  late Map<String, String> contentTypes; // contentId -> type mapping

  TopicNode({
    required this.id,
    required this.name,
    this.parentId,
    required this.userId,
    this.masteryScore = 0.0,
    this.stabilityScore = 0.0,
    this.confidenceScore = 0.0,
    required this.lastInteraction,
    this.learningVelocity = 0.0,
    required this.createdAt,
    this.contentIds = const [],
    this.contentTypes = const {},
  });

  /// Calculate Forgetting Risk (0.0 to 1.0) using Ebbinghaus exponential decay
  /// Higher values mean the user is likely to forget this topic soon.
  double get forgettingRisk {
    if (stabilityScore == 0) return 1.0;
    
    final now = DateTime.now();
    final diff = now.difference(lastInteraction);
    final daysSince = diff.inSeconds / (24 * 3600);

    // Exponential decay model: R = e^(-t / S)
    // S (stability) is scaled so 1.0 stability ~ 30 days of retention
    final adjustedStability = (stabilityScore * 30.0).clamp(0.1, 1000.0);
    
    // Risk = 1.0 - Retrievability
    final retrievability = math.exp(-daysSince / adjustedStability);
    
    return (1.0 - retrievability).clamp(0.0, 1.0);
  }

  /// Complement of forgetting risk
  double get retentionEstimate => 1.0 - forgettingRisk;

  TopicNode copyWith({
    String? id,
    String? name,
    String? parentId,
    String? userId,
    double? masteryScore,
    double? stabilityScore,
    double? confidenceScore,
    DateTime? lastInteraction,
    double? learningVelocity,
    DateTime? createdAt,
    List<String>? contentIds,
    Map<String, String>? contentTypes,
  }) {
    return TopicNode(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      userId: userId ?? this.userId,
      masteryScore: masteryScore ?? this.masteryScore,
      stabilityScore: stabilityScore ?? this.stabilityScore,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      learningVelocity: learningVelocity ?? this.learningVelocity,
      createdAt: createdAt ?? this.createdAt,
      contentIds: contentIds ?? this.contentIds,
      contentTypes: contentTypes ?? this.contentTypes,
    );
  }
}

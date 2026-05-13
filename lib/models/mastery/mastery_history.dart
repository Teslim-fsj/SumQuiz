import 'package:hive/hive.dart';

part 'mastery_history.g.dart';

@HiveType(typeId: 35)
class MasteryHistory extends HiveObject {
  @HiveField(0)
  final String userId;

  @HiveField(1)
  final double averageMastery;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final String? topicId; // Null for global average

  @HiveField(4)
  final String? topicName;

  MasteryHistory({
    required this.userId,
    required this.averageMastery,
    required this.timestamp,
    this.topicId,
    this.topicName,
  });
}

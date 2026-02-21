import 'package:hive/hive.dart';

part 'spaced_repetition.g.dart';

@HiveType(typeId: 8)
class SpacedRepetitionItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  String contentId;

  @HiveField(3)
  String contentType;

  @HiveField(4)
  DateTime nextReviewDate;

  @HiveField(5)
  int interval;

  @HiveField(6)
  double easeFactor;

  @HiveField(7)
  DateTime lastReviewed;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  @HiveField(10)
  int repetitionCount;

  @HiveField(11)
  int correctStreak;

  SpacedRepetitionItem({
    required this.id,
    required this.userId,
    required this.contentId,
    required this.contentType,
    required this.nextReviewDate,
    required this.lastReviewed,
    required this.createdAt,
    required this.updatedAt,
    this.interval = 1,
    this.easeFactor = 2.5,
    this.repetitionCount = 0,
    this.correctStreak = 0,
  });
}

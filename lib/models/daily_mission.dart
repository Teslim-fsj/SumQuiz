import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'daily_mission.g.dart';

@HiveType(typeId: 21)
class DailyMission extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  List<String> flashcardIds;

  @HiveField(3)
  String? miniQuizTopic;

  @HiveField(4)
  bool isCompleted;

  @HiveField(5)
  int estimatedTimeMinutes;

  @HiveField(6)
  int momentumReward;

  @HiveField(7)
  int difficultyLevel; // 1 to 5

  @HiveField(8)
  double completionScore; // 0.0 to 1.0

  @HiveField(9)
  String title;

  DailyMission({
    required this.id,
    required this.date,
    required this.flashcardIds,
    this.miniQuizTopic,
    required this.isCompleted,
    required this.estimatedTimeMinutes,
    required this.momentumReward,
    required this.difficultyLevel,
    required this.completionScore,
    required this.title,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'flashcardIds': flashcardIds,
      'miniQuizTopic': miniQuizTopic,
      'isCompleted': isCompleted,
      'estimatedTimeMinutes': estimatedTimeMinutes,
      'momentumReward': momentumReward,
      'difficultyLevel': difficultyLevel,
      'completionScore': completionScore,
      'title': title,
    };
  }

  factory DailyMission.fromMap(Map<String, dynamic> map) {
    return DailyMission(
      id: map['id'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      flashcardIds: List<String>.from(map['flashcardIds'] ?? []),
      miniQuizTopic: map['miniQuizTopic'],
      isCompleted: map['isCompleted'] ?? false,
      estimatedTimeMinutes: map['estimatedTimeMinutes'] ?? 0,
      momentumReward: map['momentumReward'] ?? 0,
      difficultyLevel: map['difficultyLevel'] ?? 3,
      completionScore: (map['completionScore'] as num?)?.toDouble() ?? 0.0,
      title: map['title'] ?? 'Daily Mission',
    );
  }

  DailyMission copyWith({
    String? id,
    DateTime? date,
    List<String>? flashcardIds,
    String? miniQuizTopic,
    bool? isCompleted,
    int? estimatedTimeMinutes,
    int? momentumReward,
    int? difficultyLevel,
    double? completionScore,
    String? title,
  }) {
    return DailyMission(
      id: id ?? this.id,
      date: date ?? this.date,
      flashcardIds: flashcardIds ?? this.flashcardIds,
      miniQuizTopic: miniQuizTopic ?? this.miniQuizTopic,
      isCompleted: isCompleted ?? this.isCompleted,
      estimatedTimeMinutes: estimatedTimeMinutes ?? this.estimatedTimeMinutes,
      momentumReward: momentumReward ?? this.momentumReward,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      completionScore: completionScore ?? this.completionScore,
      title: title ?? this.title,
    );
  }
}

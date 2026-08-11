import 'package:cloud_firestore/cloud_firestore.dart';

class CreatorAchievement {
  final String id;
  final String creatorId;
  final String achievementId;
  final String title;
  final String description;
  final String emoji;
  final DateTime unlockedAt;

  CreatorAchievement({
    required this.id,
    required this.creatorId,
    required this.achievementId,
    required this.title,
    required this.description,
    required this.emoji,
    required this.unlockedAt,
  });

  factory CreatorAchievement.fromMap(Map<String, dynamic> map, String id) {
    return CreatorAchievement(
      id: id,
      creatorId: map['creatorId'] ?? '',
      achievementId: map['achievementId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      emoji: map['emoji'] ?? '🏆',
      unlockedAt: (map['unlockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'achievementId': achievementId,
      'title': title,
      'description': description,
      'emoji': emoji,
      'unlockedAt': Timestamp.fromDate(unlockedAt),
    };
  }
}

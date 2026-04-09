import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'content_folder.g.dart';

@HiveType(typeId: 6)
class ContentFolder extends HiveObject {
  @HiveField(0)
  late String contentId;

  @HiveField(1)
  late String folderId;

  @HiveField(2)
  late String contentType; // 'summary', 'quiz', or 'flashcards'

  @HiveField(3)
  late String userId;

  @HiveField(4)
  late DateTime assignedAt;

  ContentFolder({
    required this.contentId,
    required this.folderId,
    required this.contentType,
    required this.userId,
    required this.assignedAt,
  });

  ContentFolder.empty() {
    contentId = '';
    folderId = '';
    contentType = '';
    userId = '';
    assignedAt = DateTime.now();
  }

  factory ContentFolder.fromFirestore(Map<String, dynamic> data) {
    return ContentFolder(
      contentId: data['contentId'] ?? '',
      folderId: data['folderId'] ?? '',
      contentType: data['contentType'] ?? '',
      userId: data['userId'] ?? '',
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'contentId': contentId,
      'folderId': folderId,
      'contentType': contentType,
      'userId': userId,
      'assignedAt': Timestamp.fromDate(assignedAt),
    };
  }
}

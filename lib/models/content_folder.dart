import 'package:hive/hive.dart';

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
}

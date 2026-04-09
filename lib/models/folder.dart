import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'folder.g.dart';

@HiveType(typeId: 5)
class Folder extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String userId;

  @HiveField(3)
  late DateTime createdAt;

  @HiveField(4)
  late DateTime updatedAt;

  @HiveField(5)
  bool isSaved;

  Folder({
    required this.id,
    required this.name,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.isSaved = false,
  });

  Folder.empty()
      : id = '',
        name = '',
        userId = '',
        createdAt = DateTime.now(),
        updatedAt = DateTime.now(),
        isSaved = false;

  factory Folder.fromFirestore(Map<String, dynamic> data, String id) {
    return Folder(
      id: id,
      name: data['name'] ?? 'Untitled Folder',
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSaved: true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

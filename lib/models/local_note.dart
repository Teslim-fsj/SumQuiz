import 'package:hive/hive.dart';

part 'local_note.g.dart';

@HiveType(typeId: 22)
class LocalNote extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String userId;

  @HiveField(2)
  late String title;

  @HiveField(3)
  late String content;

  @HiveField(4)
  late DateTime createdAt;

  @HiveField(5)
  late DateTime updatedAt;

  @HiveField(6)
  String? folderId;

  @HiveField(7)
  String? linkedItemId;

  @HiveField(8)
  String? linkedItemType;

  @HiveField(9)
  late List<String> tags;

  @HiveField(10)
  late bool isSynced;

  LocalNote({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.linkedItemId,
    this.linkedItemType,
    this.tags = const [],
    this.isSynced = false,
  });

  LocalNote copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? folderId,
    String? linkedItemId,
    String? linkedItemType,
    List<String>? tags,
    bool? isSynced,
  }) {
    return LocalNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: folderId ?? this.folderId,
      linkedItemId: linkedItemId ?? this.linkedItemId,
      linkedItemType: linkedItemType ?? this.linkedItemType,
      tags: tags ?? this.tags,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'folderId': folderId,
      'linkedItemId': linkedItemId,
      'linkedItemType': linkedItemType,
      'tags': tags,
    };
  }

  factory LocalNote.fromFirestore(String id, Map<String, dynamic> data) {
    return LocalNote(
      id: id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
      folderId: data['folderId'],
      linkedItemId: data['linkedItemId'],
      linkedItemType: data['linkedItemType'],
      tags: List<String>.from(data['tags'] ?? []),
      isSynced: true,
    );
  }
}

import 'package:hive/hive.dart';

part 'local_recording.g.dart';

@HiveType(typeId: 23)
class LocalRecording extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String userId;

  @HiveField(2)
  late String noteId;

  @HiveField(3)
  late String filePath;

  @HiveField(4)
  late int durationSeconds;

  @HiveField(5)
  late DateTime createdAt;

  @HiveField(6)
  String? transcript;

  @HiveField(7)
  late bool isTranscribed;

  LocalRecording({
    required this.id,
    required this.userId,
    required this.noteId,
    required this.filePath,
    required this.durationSeconds,
    required this.createdAt,
    this.transcript,
    this.isTranscribed = false,
  });

  LocalRecording copyWith({
    String? id,
    String? userId,
    String? noteId,
    String? filePath,
    int? durationSeconds,
    DateTime? createdAt,
    String? transcript,
    bool? isTranscribed,
  }) {
    return LocalRecording(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      noteId: noteId ?? this.noteId,
      filePath: filePath ?? this.filePath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      transcript: transcript ?? this.transcript,
      isTranscribed: isTranscribed ?? this.isTranscribed,
    );
  }
}

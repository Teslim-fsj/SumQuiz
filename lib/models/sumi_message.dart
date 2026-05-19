import 'package:hive/hive.dart';
// Trigger analyzer refresh

part 'sumi_message.g.dart';

@HiveType(typeId: 33)
enum MessageRole {
  @HiveField(0)
  user,
  @HiveField(1)
  sumi
}

@HiveType(typeId: 34)
class SumiMessage extends HiveObject {
  @HiveField(0)
  final String text;

  @HiveField(1)
  final MessageRole role;

  @HiveField(2)
  final DateTime timestamp;

  SumiMessage({
    required this.text,
    required this.role,
    required this.timestamp,
  });
}

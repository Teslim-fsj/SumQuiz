import 'package:hive/hive.dart';
import 'dart:ui';

part 'local_drawing_stroke.g.dart';

@HiveType(typeId: 31)
class LocalDrawingStroke extends HiveObject {
  @HiveField(0)
  final List<Offset> points;

  @HiveField(1)
  final double strokeWidth;

  @HiveField(2)
  final int colorValue;

  @HiveField(3)
  final DateTime? timestamp;

  @HiveField(4)
  final Duration? audioTimestamp;

  LocalDrawingStroke({
    required this.points,
    required this.strokeWidth,
    required this.colorValue,
    this.timestamp,
    this.audioTimestamp,
  });

  Color get color => Color(colorValue);
}

@HiveType(typeId: 32)
class OffsetAdapter extends TypeAdapter<Offset> {
  @override
  final int typeId = 32;

  @override
  Offset read(BinaryReader reader) {
    return Offset(reader.readDouble(), reader.readDouble());
  }

  @override
  void write(BinaryWriter writer, Offset obj) {
    writer.writeDouble(obj.dx);
    writer.writeDouble(obj.dy);
  }
}

class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final int typeId = 36;

  @override
  Duration read(BinaryReader reader) {
    return Duration(microseconds: reader.readInt());
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMicroseconds);
  }
}

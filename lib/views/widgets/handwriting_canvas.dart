import 'package:flutter/material.dart';
import '../../models/local_drawing_stroke.dart';

class HandwritingCanvas extends StatefulWidget {
  final List<LocalDrawingStroke> strokes;
  final Function(LocalDrawingStroke) onStrokeComplete;
  final Duration? currentAudioTime;
  final Function(Duration)? onStrokeTap;

  const HandwritingCanvas({
    super.key,
    required this.strokes,
    required this.onStrokeComplete,
    this.currentAudioTime,
    this.onStrokeTap,
  });

  @override
  State<HandwritingCanvas> createState() => _HandwritingCanvasState();
}

class _HandwritingCanvasState extends State<HandwritingCanvas> {
  final List<Offset> _currentPoints = [];

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentPoints.add(details.localPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPoints.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentPoints.isNotEmpty) {
      final stroke = LocalDrawingStroke(
        points: List.from(_currentPoints),
        colorValue: Colors.black.toARGB32(),
        strokeWidth: 3.0,
        timestamp: DateTime.now(),
        audioTimestamp: widget.currentAudioTime,
      );
      widget.onStrokeComplete(stroke);
      setState(() {
        _currentPoints.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapDown: (details) {
        // Detect tap on existing strokes to play audio
        _detectStrokeTap(details.localPosition);
      },
      child: CustomPaint(
        painter: StrokePainter(
          strokes: widget.strokes,
          currentPoints: _currentPoints,
        ),
        size: Size.infinite,
      ),
    );
  }

  void _detectStrokeTap(Offset position) {
    if (widget.onStrokeTap == null) return;

    for (final stroke in widget.strokes) {
      for (final point in stroke.points) {
        if ((point - position).distance < 20) {
          if (stroke.audioTimestamp != null) {
            widget.onStrokeTap!(stroke.audioTimestamp!);
            return;
          }
        }
      }
    }
  }
}

class StrokePainter extends CustomPainter {
  final List<LocalDrawingStroke> strokes;
  final List<Offset> currentPoints;

  StrokePainter({required this.strokes, required this.currentPoints});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    // Draw existing strokes
    for (final stroke in strokes) {
      _drawPoints(canvas, stroke.points, paint);
    }

    // Draw current stroke
    if (currentPoints.isNotEmpty) {
      _drawPoints(canvas, currentPoints, paint);
    }
  }

  void _drawPoints(Canvas canvas, List<Offset> points, Paint paint) {
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

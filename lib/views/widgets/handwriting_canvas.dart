import 'package:flutter/material.dart';
import '../../models/local_drawing_stroke.dart';

class HandwritingCanvas extends StatefulWidget {
  final List<LocalDrawingStroke> strokes;
  final Function(LocalDrawingStroke) onStrokeComplete;
  final Duration? currentAudioTime;
  final Function(Duration)? onStrokeTap;
  final bool isEraserMode;

  const HandwritingCanvas({
    super.key,
    required this.strokes,
    required this.onStrokeComplete,
    this.currentAudioTime,
    this.onStrokeTap,
    this.isEraserMode = false,
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
      final theme = Theme.of(context);
      final drawColor = theme.colorScheme.primary;
      final stroke = LocalDrawingStroke(
        points: List.from(_currentPoints),
        colorValue: widget.isEraserMode ? Colors.transparent.toARGB32() : drawColor.toARGB32(),
        strokeWidth: widget.isEraserMode ? 20.0 : 3.0,
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
    final theme = Theme.of(context);
    final drawColor = theme.colorScheme.primary;
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
          activeColor: drawColor,
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
  final Color activeColor;

  StrokePainter({required this.strokes, required this.currentPoints, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    // Draw existing strokes
    for (final stroke in strokes) {
      if (stroke.colorValue == Colors.transparent.toARGB32()) {
        paint.color = Colors.black; // Background color for clearing
        paint.blendMode = BlendMode.clear;
        paint.strokeWidth = stroke.strokeWidth;
      } else {
        paint.color = Color(stroke.colorValue);
        paint.blendMode = BlendMode.srcOver;
        paint.strokeWidth = stroke.strokeWidth;
      }
      _drawPoints(canvas, stroke.points, paint);
    }

    // Draw current stroke
    if (currentPoints.isNotEmpty) {
      paint.color = activeColor;
      paint.blendMode = BlendMode.srcOver;
      paint.strokeWidth = 3.0;
      _drawPoints(canvas, currentPoints, paint);
    }
  }

  void _drawPoints(Canvas canvas, List<Offset> points, Paint paint) {
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return oldDelegate.strokes.length != strokes.length || 
           oldDelegate.currentPoints.length != currentPoints.length;
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/mastery/topic_node.dart';

class KnowledgeGraphView extends StatefulWidget {
  final List<TopicNode> topics;
  final Function(TopicNode)? onTopicTap;

  const KnowledgeGraphView({
    super.key,
    required this.topics,
    this.onTopicTap,
  });

  @override
  State<KnowledgeGraphView> createState() => _KnowledgeGraphViewState();
}

class _KnowledgeGraphViewState extends State<KnowledgeGraphView> {
  late List<_NodePosition> _nodes;
  
  @override
  void initState() {
    super.initState();
    _initializePositions();
  }

  void _initializePositions() {
    final random = math.Random();
    _nodes = widget.topics.map((topic) {
      return _NodePosition(
        topic: topic,
        position: Offset(
          random.nextDouble() * 300,
          random.nextDouble() * 300,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              for (var node in _nodes) {
                node.position += details.delta;
              }
            });
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _GraphPainter(
              nodes: _nodes,
              theme: Theme.of(context),
            ),
          ),
        );
      },
    );
  }
}

class _NodePosition {
  final TopicNode topic;
  Offset position;

  _NodePosition({required this.topic, required this.position});
}

class _GraphPainter extends CustomPainter {
  final List<_NodePosition> nodes;
  final ThemeData theme;

  _GraphPainter({required this.nodes, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.colorScheme.primary.withOpacity(0.2)
      ..strokeWidth = 1.0;

    // Draw Links
    for (var i = 0; i < nodes.length; i++) {
      final nodeA = nodes[i];
      for (var j = i + 1; j < nodes.length; j++) {
        final nodeB = nodes[j];
        
        // Link logic: Parent-Child or Shared Content
        bool isLinked = nodeA.topic.parentId == nodeB.topic.id || 
                       nodeB.topic.parentId == nodeA.topic.id;
        
        if (isLinked) {
          canvas.drawLine(nodeA.position, nodeB.position, paint);
        }
      }
    }

    // Draw Nodes
    for (var node in nodes) {
      final mastery = node.topic.masteryScore;
      final radius = 10.0 + (mastery * 20.0);
      
      final nodePaint = Paint()
        ..color = Color.lerp(Colors.redAccent, Colors.greenAccent, mastery)!
        ..style = PaintingStyle.fill;

      final glowPaint = Paint()
        ..color = nodePaint.color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      // Draw Glow
      canvas.drawCircle(node.position, radius + 5, glowPaint);
      
      // Draw Node
      canvas.drawCircle(node.position, radius, nodePaint);

      // Draw Text
      final textPainter = TextPainter(
        text: TextSpan(
          text: node.topic.name,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(node.position.dx - textPainter.width / 2, node.position.dy + radius + 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

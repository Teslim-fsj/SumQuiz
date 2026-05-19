import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

class _KnowledgeGraphViewState extends State<KnowledgeGraphView>
    with SingleTickerProviderStateMixin {
  late List<_NodePosition> _nodes;
  late Ticker _ticker;
  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _initializePositions();
    _ticker = createTicker(_onTick)..start();
  }

  void _initializePositions() {
    final random = math.Random();
    _nodes = widget.topics.map((topic) {
      return _NodePosition(
        topic: topic,
        position: Offset(
          random.nextDouble() * 400 - 200,
          random.nextDouble() * 400 - 200,
        ),
      );
    }).toList();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    // Simple Force-Directed Layout Simulation
    setState(() {
      for (var i = 0; i < _nodes.length; i++) {
        final nodeA = _nodes[i];

        // 1. Repulsion (between all nodes)
        for (var j = 0; j < _nodes.length; j++) {
          if (i == j) continue;
          final nodeB = _nodes[j];
          final diff = nodeA.position - nodeB.position;
          final dist = diff.distance;
          if (dist < 200) {
            final force = (200 - dist) / 100;
            nodeA.velocity += (diff / dist) * force;
          }
        }

        // 2. Attraction (links)
        for (var j = 0; j < _nodes.length; j++) {
          if (i == j) continue;
          final nodeB = _nodes[j];
          if (_isLinked(nodeA.topic, nodeB.topic)) {
            final diff = nodeB.position - nodeA.position;
            final dist = diff.distance;
            if (dist > 100) {
              final force = (dist - 100) / 200;
              nodeA.velocity += (diff / dist) * force;
            }
          }
        }

        // 3. Center Gravity
        final centerForce = -nodeA.position / 500;
        nodeA.velocity += centerForce;

        // Apply velocity with damping
        nodeA.position += nodeA.velocity;
        nodeA.velocity *= 0.85;
      }
    });
  }

  bool _isLinked(TopicNode a, TopicNode b) {
    // Parent-child or Shared Content IDs
    if (a.parentId == b.id || b.parentId == a.id) return true;
    final common = a.contentIds.toSet().intersection(b.contentIds.toSet());
    return common.isNotEmpty;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _handleTap(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + _dragOffset;
    for (var node in _nodes) {
      final nodePos = center + node.position;
      final dist = (localPosition - nodePos).distance;
      final radius = 15.0 + (node.topic.masteryScore * 20.0);
      if (dist < radius + 10) {
        widget.onTopicTap?.call(node.topic);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _dragOffset += details.delta;
            });
          },
          onTapUp: (details) => _handleTap(details.localPosition, size),
          child: Container(
            color: Colors.transparent, // Capture taps
            child: CustomPaint(
              size: size,
              painter: _GraphPainter(
                nodes: _nodes,
                dragOffset: _dragOffset,
                theme: Theme.of(context),
              ),
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
  Offset velocity = Offset.zero;

  _NodePosition({required this.topic, required this.position});
}

class _GraphPainter extends CustomPainter {
  final List<_NodePosition> nodes;
  final Offset dragOffset;
  final ThemeData theme;

  _GraphPainter(
      {required this.nodes, required this.dragOffset, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + dragOffset;

    final linkPaint = Paint()
      ..color = theme.colorScheme.primary.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    // Draw Links
    for (var i = 0; i < nodes.length; i++) {
      final nodeA = nodes[i];
      for (var j = i + 1; j < nodes.length; j++) {
        final nodeB = nodes[j];
        if (_isLinked(nodeA.topic, nodeB.topic)) {
          canvas.drawLine(
              center + nodeA.position, center + nodeB.position, linkPaint);
        }
      }
    }

    // Draw Nodes
    for (var node in nodes) {
      final mastery = node.topic.masteryScore;
      final radius = 10.0 + (mastery * 20.0);
      final pos = center + node.position;

      final nodePaint = Paint()
        ..color = Color.lerp(Colors.redAccent, Colors.cyanAccent, mastery)!
        ..style = PaintingStyle.fill;

      final glowPaint = Paint()
        ..color = nodePaint.color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      // Draw Glow
      canvas.drawCircle(pos, radius + 5, glowPaint);

      // Draw Node
      canvas.drawCircle(pos, radius, nodePaint);

      // Draw Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: node.topic.name,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy + radius + 4),
      );
    }
  }

  bool _isLinked(TopicNode a, TopicNode b) {
    if (a.parentId == b.id || b.parentId == a.id) return true;
    final common = a.contentIds.toSet().intersection(b.contentIds.toSet());
    return common.isNotEmpty;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

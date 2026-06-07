import 'package:flutter/material.dart';

class Landing3DCard extends StatefulWidget {
  final Widget child;
  final double depth;
  final Color backgroundColor;
  final EdgeInsets padding;
  final double borderRadius;
  final bool interactive;

  const Landing3DCard({
    super.key,
    required this.child,
    this.depth = 10.0,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 24.0,
    this.interactive = true,
  });

  @override
  State<Landing3DCard> createState() => _Landing3DCardState();
}

class _Landing3DCardState extends State<Landing3DCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: widget.interactive ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.interactive ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translate(
            0.0,
            _isHovered ? -widget.depth : 0.0,
          ),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            // Inner light highlight to simulate glass/soft 3D edge
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.8),
              offset: const Offset(-2, -2),
              blurRadius: 4,
            ),
            // Tactile depth shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: Offset(0, _isHovered ? widget.depth * 1.5 : widget.depth * 0.5),
              blurRadius: _isHovered ? 25 : 15,
            ),
            // Extruded "thick" base shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              offset: Offset(0, _isHovered ? widget.depth : widget.depth * 0.3),
              blurRadius: 0,
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

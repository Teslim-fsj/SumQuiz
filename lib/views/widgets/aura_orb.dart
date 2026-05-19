import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum OrbState { idle, listening, thinking, speaking, burnout, momentum }

class AuraOrb extends StatefulWidget {
  final OrbState state;
  final double size;
  final double amplitude;

  const AuraOrb({
    super.key,
    required this.state,
    this.size = 150,
    this.amplitude = 0.0,
  });

  @override
  State<AuraOrb> createState() => _AuraOrbState();
}

class _AuraOrbState extends State<AuraOrb> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getStateColor(theme);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Soft Glow
          _buildGlowLayer(color, 0.2, 1.3),
          _buildGlowLayer(color, 0.1, 1.6),

          // The Core Aura
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulse = _pulseController.value;
              final sizeMultiplier = widget.state == OrbState.listening
                  ? 0.6 + (widget.amplitude * 0.4)
                  : 0.6;

              return Container(
                width: widget.size * sizeMultiplier,
                height: widget.size * sizeMultiplier,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withOpacity(0.95),
                      color.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.3, 0.7, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 30 + (pulse * 20),
                      spreadRadius: 2 + (pulse * 5),
                    ),
                  ],
                ),
              );
            },
          ),

          // Inner Activity
          _buildInnerActivity(color),
        ],
      ),
    );
  }

  Widget _buildGlowLayer(Color color, double opacity, double scaleMultiplier) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        return Transform.scale(
          scale: 1.0 + (pulse * 0.15 * scaleMultiplier),
          child: Container(
            width: widget.size * 0.8,
            height: widget.size * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(opacity * (1.0 - pulse * 0.4)),
                width: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInnerActivity(Color color) {
    if (widget.state == OrbState.listening) {
      return _buildVoiceWaves(color);
    } else if (widget.state == OrbState.thinking) {
      return _buildThinkingParticles(color);
    } else if (widget.state == OrbState.speaking) {
      return _buildPulseRings(color);
    }
    return const SizedBox.shrink();
  }

  Widget _buildVoiceWaves(Color color) {
    return Stack(
      children: List.generate(
        3,
        (i) => Center(
          child: Container(
            width: widget.size * 0.4,
            height: widget.size * 0.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                  duration: 1200.ms,
                  delay: (i * 400).ms,
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(2.2, 2.2))
              .fadeOut(duration: 1200.ms, delay: (i * 400).ms),
        ),
      ),
    );
  }

  Widget _buildThinkingParticles(Color color) {
    return Center(
      child: SizedBox(
        width: widget.size * 0.5,
        height: widget.size * 0.5,
        child: CustomPaint(
          painter: AuraSynapsePainter(color.withOpacity(0.6)),
        ),
      ).animate(onPlay: (c) => c.repeat()).rotate(duration: 4.seconds),
    );
  }

  Widget _buildPulseRings(Color color) {
    return Stack(
      children: List.generate(
        2,
        (i) => Center(
          child: Container(
            width: widget.size * 0.5,
            height: widget.size * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                  duration: 1000.ms,
                  delay: (i * 500).ms,
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.4, 1.4))
              .fadeOut(duration: 1000.ms, delay: (i * 500).ms),
        ),
      ),
    );
  }

  Color _getStateColor(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    switch (widget.state) {
      case OrbState.listening:
        return const Color(0xFF0D9488); // Teal
      case OrbState.thinking:
        return const Color(0xFF6B5CE7); // Purple
      case OrbState.speaking:
        return theme.brightness == Brightness.dark
            ? Colors.white
            : colorScheme.primary;
      case OrbState.burnout:
        return const Color(0xFFEF4444); // Red
      case OrbState.momentum:
        return const Color(0xFFF59E0B); // Amber
      case OrbState.idle:
        return const Color(0xFF0D9488).withOpacity(0.6);
    }
  }
}

class AuraSynapsePainter extends CustomPainter {
  final Color color;
  AuraSynapsePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), paint);
      canvas.drawCircle(Offset(x, y), 2.5, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

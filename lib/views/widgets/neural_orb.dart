import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/cyber_neural_theme.dart';

enum OrbState { idle, listening, thinking, speaking, burnout, momentum }

class NeuralOrb extends StatefulWidget {
  final OrbState state;
  final double size;
  final double amplitude;

  const NeuralOrb({
    super.key,
    required this.state,
    this.size = 150,
    this.amplitude = 0.0,
  });

  @override
  State<NeuralOrb> createState() => _NeuralOrbState();
}

class _NeuralOrbState extends State<NeuralOrb>
    with SingleTickerProviderStateMixin {
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
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow
          _buildGlowLayer(0.8, 1.2),
          _buildGlowLayer(0.4, 1.5),

          // The Core Orb
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulse = _pulseController.value;
              return Container(
                width: widget.size * 0.6,
                height: widget.size * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _getStateColor().withValues(alpha: 0.9),
                      _getStateColor().withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.2, 0.6, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getStateColor().withValues(alpha: 0.5),
                      blurRadius: 20 + (pulse * 10),
                      spreadRadius: 5 + (pulse * 5),
                    ),
                  ],
                ),
              );
            },
          ),

          // Inner Patterns / Activity
          _buildInnerActivity(),
        ],
      ),
    );
  }

  Widget _buildGlowLayer(double opacity, double scaleMultiplier) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        return Transform.scale(
          scale: 1.0 + (pulse * 0.1 * scaleMultiplier),
          child: Container(
            width: widget.size * 0.8,
            height: widget.size * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    _getStateColor().withValues(alpha: opacity * (1.0 - pulse * 0.3)),
                width: 1,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInnerActivity() {
    if (widget.state == OrbState.listening) {
      return _buildVoiceWaves();
    } else if (widget.state == OrbState.thinking) {
      return _buildNeuralSynapses();
    } else if (widget.state == OrbState.speaking) {
      return _buildPulseRings();
    }
    return const SizedBox.shrink();
  }

  Widget _buildVoiceWaves() {
    return Stack(
      children: List.generate(
        3,
        (i) => Center(
          child: Container(
            width: widget.size * 0.4,
            height: widget.size * 0.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: CyberNeuralColors.cyan.withValues(alpha: 0.5)),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                  duration: 1000.ms,
                  delay: (i * 300).ms,
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(2.0, 2.0))
              .fadeOut(duration: 1000.ms, delay: (i * 300).ms),
        ),
      ),
    );
  }

  Widget _buildNeuralSynapses() {
    return Center(
      child: SizedBox(
        width: widget.size * 0.5,
        height: widget.size * 0.5,
        child: CustomPaint(
          painter: SynapsePainter(_getStateColor()),
        ),
      ).animate(onPlay: (c) => c.repeat()).rotate(duration: 3.seconds),
    );
  }

  Widget _buildPulseRings() {
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
                  Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                  duration: 800.ms,
                  delay: (i * 400).ms,
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.2, 1.2))
              .fadeOut(duration: 800.ms, delay: (i * 400).ms),
        ),
      ),
    );
  }

  Color _getStateColor() {
    switch (widget.state) {
      case OrbState.listening:
        return CyberNeuralColors.cyan;
      case OrbState.thinking:
        return CyberNeuralColors.purple;
      case OrbState.speaking:
        return Colors.white;
      case OrbState.burnout:
        return CyberNeuralColors.alert;
      case OrbState.momentum:
        return CyberNeuralColors.gold;
      case OrbState.idle:
        return CyberNeuralColors.cyan.withValues(alpha: 0.7);
    }
  }
}

class SynapsePainter extends CustomPainter {
  final Color color;
  SynapsePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), paint);
      canvas.drawCircle(Offset(x, y), 2, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

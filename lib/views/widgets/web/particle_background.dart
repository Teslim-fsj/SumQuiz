import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  final int numberOfParticles;
  final Color particleColor;

  const ParticleBackground({
    super.key,
    this.numberOfParticles = 50,
    this.particleColor = Colors.white,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _particles = List.generate(
      widget.numberOfParticles,
      (index) => Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 3 + 1,
        speedX: (_random.nextDouble() - 0.5) * 0.0005,
        speedY: (_random.nextDouble() - 0.5) * 0.0005,
        opacity: _random.nextDouble() * 0.5 + 0.1,
      ),
    );

    _controller.addListener(() {
      setState(() {
        for (var particle in _particles) {
          particle.x += particle.speedX;
          particle.y += particle.speedY;

          // Wrap around edges
          if (particle.x < 0) particle.x = 1;
          if (particle.x > 1) particle.x = 0;
          if (particle.y < 0) particle.y = 1;
          if (particle.y > 1) particle.y = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ParticlePainter(
        particles: _particles,
        color: widget.particleColor,
      ),
      child: Container(),
    );
  }
}

class Particle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Color color;

  ParticlePainter({required this.particles, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        paint,
      );
    }

    // Draw connections between nearby particles
    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final dx = (particles[i].x - particles[j].x) * size.width;
        final dy = (particles[i].y - particles[j].y) * size.height;
        final distance = sqrt(dx * dx + dy * dy);

        if (distance < 150) {
          final paint = Paint()
            ..color = color.withOpacity((1 - distance / 150) * 0.1)
            ..strokeWidth = 0.5;

          canvas.drawLine(
            Offset(particles[i].x * size.width, particles[i].y * size.height),
            Offset(particles[j].x * size.width, particles[j].y * size.height),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

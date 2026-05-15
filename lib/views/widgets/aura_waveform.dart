import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum AuraTone { exciting, analytical, intense, calm }

class AuraWaveform extends StatefulWidget {
  final AuraTone tone;
  final bool isRecording;
  final Stream<double>? amplitudeStream;
  
  const AuraWaveform({
    super.key,
    this.tone = AuraTone.calm,
    this.isRecording = false,
    this.amplitudeStream,
  });

  @override
  State<AuraWaveform> createState() => _AuraWaveformState();
}

class _AuraWaveformState extends State<AuraWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _amplitudes = List.generate(40, (index) => 0.1);
  StreamSubscription<double>? _amplitudeSub;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _amplitudeSub = widget.amplitudeStream?.listen((amp) {
      if (mounted) {
        setState(() {
          _amplitudes.removeAt(0);
          _amplitudes.add(amp);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _amplitudeSub?.cancel();
    super.dispose();
  }

  Color _getToneColor(ThemeData theme) {
    switch (widget.tone) {
      case AuraTone.exciting: return const Color(0xFFEC4899); // Pink
      case AuraTone.analytical: return const Color(0xFF6B5CE7); // Purple
      case AuraTone.intense: return const Color(0xFFEF4444); // Red
      case AuraTone.calm: return const Color(0xFF0D9488); // Teal
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getToneColor(theme);
    
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.0),
            color.withOpacity(0.03),
            color.withOpacity(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_amplitudes.length, (index) {
              final phase = (index / _amplitudes.length) * 2 * math.pi;
              final animationValue = math.sin(_controller.value * 2 * math.pi + phase);
              final height = widget.isRecording 
                  ? 8 + (_amplitudes[index] * 35 * (0.8 + 0.2 * animationValue))
                  : 4.0;
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 3,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: color.withOpacity(widget.isRecording ? 0.7 : 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          );
        },
      ),
    ).animate(target: widget.isRecording ? 1 : 0).fadeIn().scaleY(begin: 0.8, end: 1);
  }
}

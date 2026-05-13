import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/cyber_neural_theme.dart';

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
          // Push new amplitude to the end and remove from start
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

  Color _getToneColor() {
    switch (widget.tone) {
      case AuraTone.exciting: return CyberNeuralColors.toneExciting;
      case AuraTone.analytical: return CyberNeuralColors.toneAnalytical;
      case AuraTone.intense: return CyberNeuralColors.toneIntense;
      case AuraTone.calm: return CyberNeuralColors.toneCalm;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getToneColor();
    
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.05),
            color.withValues(alpha: 0.0),
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
                  ? 10 + (_amplitudes[index] * 40 * (0.8 + 0.2 * animationValue))
                  : 4.0;
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 3,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: widget.isRecording ? 0.8 : 0.2),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    if (widget.isRecording)
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    ).animate(target: widget.isRecording ? 1 : 0).fadeIn().scaleY(begin: 0.5, end: 1);
  }
}

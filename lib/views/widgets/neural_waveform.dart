import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/cyber_neural_theme.dart';

class NeuralWaveform extends StatelessWidget {
  final bool isRecording;
  const NeuralWaveform({super.key, required this.isRecording});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(20, (index) {
          return Container(
            width: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              gradient: CyberNeuralColors.neuralGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scaleY(
              duration: (400 + (index * 50)).ms,
              begin: 0.2,
              end: isRecording ? (0.5 + math.Random().nextDouble()) : 0.2,
              curve: Curves.easeInOut,
           );
        }),
      ),
    );
  }
}

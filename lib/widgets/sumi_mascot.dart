import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/sumi_emotion.dart';

class SumiAnimationMap {
  final String eyes;
  final String mouth;
  final String motion;
  final String? props;
  final String? effects;

  const SumiAnimationMap({
    required this.eyes,
    required this.mouth,
    required this.motion,
    this.props,
    this.effects,
  });
}

class SumiMascot extends StatefulWidget {
  final SumiState state;
  final double size;

  const SumiMascot({
    super.key,
    this.state = SumiState.idle,
    this.size = 200.0,
  });

  @override
  State<SumiMascot> createState() => _SumiMascotState();
}

class _SumiMascotState extends State<SumiMascot> with TickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  late AnimationController _blinkController;
  bool _isBlinking = false;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  final Map<SumiState, SumiAnimationMap> animationMap = const {
    SumiState.idle: SumiAnimationMap(eyes: "open", mouth: "smile", motion: "float_slow"),
    SumiState.focused: SumiAnimationMap(eyes: "narrow", mouth: "neutral", motion: "float_slow", props: "pencil_active"),
    SumiState.thinking: SumiAnimationMap(eyes: "open", mouth: "neutral", motion: "float_slow", props: "pencil_active"),
    SumiState.correct: SumiAnimationMap(eyes: "open_bright", mouth: "smile", motion: "bounce_small"),
    SumiState.celebrating: SumiAnimationMap(eyes: "star", mouth: "open", motion: "bounce_high", effects: "sparkle"),
    SumiState.incorrect: SumiAnimationMap(eyes: "closed_sad", mouth: "sad", motion: "shake_small"),
    SumiState.reviewing: SumiAnimationMap(eyes: "focused", mouth: "neutral", motion: "float_slow", props: "flashcard_plus"),
    SumiState.confused: SumiAnimationMap(eyes: "narrow", mouth: "sad", motion: "shake_small"),
    SumiState.streakBoost: SumiAnimationMap(eyes: "star", mouth: "open", motion: "bounce_high"),
    SumiState.tired: SumiAnimationMap(eyes: "closed_sad", mouth: "sad", motion: "float_slow"),
  };

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _startRandomBlinking();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bounceAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -30.0).chain(CurveTween(curve: Curves.easeOut)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -30.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0).chain(CurveTween(curve: Curves.easeOut)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 1),
    ]).animate(_bounceController);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void didUpdateWidget(covariant SumiMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      final config = animationMap[widget.state] ?? animationMap[SumiState.idle]!;
      if (config.motion.contains('bounce')) {
        _bounceController.forward(from: 0.0);
      } else if (config.motion.contains('shake')) {
        _shakeController.forward(from: 0.0);
      }
    }
  }

  void _startRandomBlinking() async {
    while (mounted) {
      await Future.delayed(Duration(seconds: math.Random().nextInt(4) + 2));
      if (!mounted) break;
      
      setState(() => _isBlinking = true);
      await _blinkController.forward(from: 0.0);
      setState(() => _isBlinking = false);
      _blinkController.reverse();
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _blinkController.dispose();
    _bounceController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Widget _buildSvgPart(String partName, {double? width, double? height}) {
    return SvgPicture.asset(
      'assets/mascot/sumi/$partName.svg',
      width: width ?? widget.size,
      height: height ?? widget.size,
      fit: BoxFit.contain,
      placeholderBuilder: (context) => const SizedBox(), 
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _bounceController, _shakeController]),
      builder: (context, child) {
        final config = animationMap[widget.state] ?? animationMap[SumiState.idle]!;
        
        double yOffset = _floatAnimation.value;
        double xOffset = 0.0;

        if (config.motion.contains('bounce')) {
          yOffset += _bounceAnimation.value;
        } else if (config.motion.contains('shake')) {
          xOffset += _shakeAnimation.value;
          yOffset += 5.0; // slight drop down on fail
        }

        return Transform.translate(
          offset: Offset(xOffset, yOffset),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shadow
                Positioned(
                  bottom: 0,
                  child: Transform.translate(
                    offset: Offset(-xOffset, -yOffset),
                    child: Transform.scale(
                      scale: 1.0 - (_bounceAnimation.value / -100),
                      child: Opacity(
                        opacity: 0.4 - (_bounceAnimation.value / -200).clamp(0, 0.4),
                        child: _buildSvgPart('shadow', height: widget.size * 0.2),
                      ),
                    ),
                  ),
                ),

                // Back Tentacles
                _buildSvgPart('left_tentacle_2'),
                _buildSvgPart('right_tentacle_2'),

                // Body
                _buildSvgPart('body'),

                // Front Tentacles
                _buildSvgPart('left_tentacle_1'),
                _buildSvgPart('right_tentacle_1'),

                // Mouth State
                if (config.mouth == 'sad')
                  _buildSvgPart('mouth_sad')
                else if (config.mouth == 'open')
                  _buildSvgPart('mouth_open')
                else
                  _buildSvgPart('mouth_smile'),

                // Eyes State
                if (_isBlinking)
                  _buildSvgPart('left_eye_closed')
                else
                  _buildSvgPart('left_eye_open'),
                  
                if (_isBlinking)
                  _buildSvgPart('right_eye_closed')
                else
                  _buildSvgPart('right_eye_open'),

                // Cheeks
                if (widget.state == SumiState.celebrating || widget.state == SumiState.correct || widget.state == SumiState.streakBoost || widget.state == SumiState.idle) ...[
                  _buildSvgPart('blush_left'),
                  _buildSvgPart('blush_right'),
                ],

                // Accessories
                _buildSvgPart('glasses'),
                
                // Hat with tilt on thinking state
                Transform.rotate(
                  angle: widget.state == SumiState.thinking ? 0.2 : 0.0,
                  child: _buildSvgPart('graduation_hat'),
                ),

                // Props mapped by state
                if (config.props == 'pencil_active') ...[
                  _buildSvgPart('pencil_arm'),
                  _buildSvgPart('calculator_arm'),
                ] else if (config.props == 'flashcard_plus') ...[
                  _buildSvgPart('flashcard_plus'),
                ] else ...[
                  _buildSvgPart('pencil_arm'),
                  _buildSvgPart('calculator_arm'),
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/sumi_emotion.dart';

class SumiMascot extends StatefulWidget {
  final SumiState state;
  final double size;
  final String? dialogue;
  final bool showBubble;

  const SumiMascot({
    super.key,
    this.state = SumiState.idle,
    this.size = 200.0,
    this.dialogue,
    this.showBubble = true,
  });

  @override
  State<SumiMascot> createState() => _SumiMascotState();
}

class _SumiMascotState extends State<SumiMascot> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _breatheController;

  bool _isBlinking = false;

  @override
  void initState() {
    super.initState();

    _breatheController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3000) // Slower, deeper breathing
        )
      ..repeat(reverse: true);

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() async {
    if (!mounted) return;

    // Random interval, sometimes double-blinks
    int nextDelay = 2000 + Random().nextInt(4000);
    if (Random().nextDouble() > 0.8) nextDelay = 300; // Double blink chance

    await Future.delayed(Duration(milliseconds: nextDelay));

    if (!mounted) return;

    setState(() => _isBlinking = true);
    await _blinkController.forward(from: 0.0);
    setState(() => _isBlinking = false);

    _scheduleNextBlink();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  Widget _buildPart(String name) {
    return SvgPicture.asset(
      'assets/mascot/sumi/$name.svg',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        _buildDialogueBubble(theme),
        _buildAnimatedMascot(),
      ],
    );
  }

  Widget _buildAnimatedMascot() {
    /*
    bool eyesClosed = _isBlinking || 
        widget.state == SumiState.tired || 
        widget.state == SumiState.incorrect;
        
    String leftEye = eyesClosed ? 'left_eye_closed' : 'left_eye_open';
    String rightEye = eyesClosed ? 'right_eye_closed' : 'right_eye_open';
    
    String mouth = 'mouth_smile';
    if (widget.state == SumiState.incorrect || widget.state == SumiState.tired || widget.state == SumiState.confused) {
      mouth = 'mouth_sad';
    } else if (widget.state == SumiState.shocked || widget.state == SumiState.speaking || widget.state == SumiState.analytical) {
      mouth = 'mouth_open';
    } else if (widget.state == SumiState.thinking) {
      mouth = 'mouth_sad'; 
    }

    Widget shadow = _buildPart('shadow');
    Widget body = _buildPart('body');
    Widget leftTentacle1 = _buildPart('left_tentacle_1');
    Widget leftTentacle2 = _buildPart('left_tentacle_2');
    Widget rightTentacle1 = _buildPart('right_tentacle_1');
    Widget rightTentacle2 = _buildPart('right_tentacle_2');
    Widget head = _buildPart('head');
    Widget eyeL = _buildPart(leftEye);
    Widget eyeR = _buildPart(rightEye);
    Widget mouthPart = _buildPart(mouth);
    
    Widget? accessory;
    if (widget.state == SumiState.analytical || widget.state == SumiState.reviewing) {
      accessory = _buildPart('glasses');
    } else if (widget.state == SumiState.celebrating || widget.state == SumiState.streakBoost) {
      accessory = _buildPart('graduation_hat');
    } else if (widget.state == SumiState.focused) {
      accessory = _buildPart('pencil_arm');
    } else if (widget.state == SumiState.correct) {
      accessory = Stack(
        children: [_buildPart('blush_left'), _buildPart('blush_right')],
      );
    }

    // Base physics values
    double breatheOffset = sin(_breatheController.value * pi) * 3.0;
    double headTranslateY = breatheOffset;
    
    // Core animation parts
    Widget assembledBody = Stack(
      alignment: Alignment.center,
      children: [
        // Back tentacles with slight delay and wider sway
        leftTentacle2.animate(key: ValueKey('lt2_${widget.state}'), onPlay: (c) => c.repeat(reverse: true))
          .rotate(begin: -0.05, end: 0.1, duration: 2500.ms, curve: Curves.easeInOutSine),
        rightTentacle2.animate(key: ValueKey('rt2_${widget.state}'), onPlay: (c) => c.repeat(reverse: true))
          .rotate(begin: 0.05, end: -0.1, duration: 2600.ms, curve: Curves.easeInOutSine),

        body,

        // Front tentacles
        leftTentacle1.animate(key: ValueKey('lt1_${widget.state}'), onPlay: (c) => c.repeat(reverse: true))
          .rotate(begin: -0.02, end: 0.08, duration: 2200.ms, curve: Curves.easeInOutSine),
        rightTentacle1.animate(key: ValueKey('rt1_${widget.state}'), onPlay: (c) => c.repeat(reverse: true))
          .rotate(begin: 0.02, end: -0.08, duration: 2300.ms, curve: Curves.easeInOutSine),
          
        // Head Assembly
        Stack(
          alignment: Alignment.center,
          children: [
            head,
            
            // Eyes with independent darting logic if thinking
            Stack(
              alignment: Alignment.center,
              children: [eyeL, eyeR],
            ).animate(
               key: ValueKey('eyes_${widget.state}'),
               onPlay: widget.state == SumiState.thinking ? (c) => c.repeat() : null
             )
             .then(delay: 500.ms)
             .moveX(end: 8, duration: 150.ms, curve: Curves.easeOutCubic)
             .moveY(end: -4, duration: 150.ms)
             .then(delay: 1500.ms)
             .moveX(end: -8, duration: 200.ms, curve: Curves.easeOutCubic)
             .moveY(end: -2, duration: 200.ms)
             .then(delay: 1000.ms)
             .moveX(end: 0, duration: 150.ms)
             .moveY(end: 0, duration: 150.ms),

            // Mouth with speaking oscillation
            mouthPart.animate(
              key: ValueKey('mouth_${widget.state}'),
              onPlay: widget.state == SumiState.speaking ? (c) => c.repeat(reverse: true) : null
            ).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.4), duration: 150.ms),

            if (accessory != null) accessory,
          ],
        ).animate(key: ValueKey('head_base_${widget.state}'))
         .moveY(end: headTranslateY, duration: 500.ms)
      ],
    );

    // Apply state-specific complex modifiers to the entire assembly
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shadow
          shadow.animate(key: ValueKey('shadow_${widget.state}'))
                .scale(
                  end: widget.state == SumiState.correct || widget.state == SumiState.celebrating || widget.state == SumiState.streakBoost
                    ? const Offset(0.5, 0.5) 
                    : const Offset(1.0, 1.0), 
                  duration: 400.ms, 
                  curve: Curves.easeOut
                ),
          
          // Full Body Assembly Modifier
          _applyStateModifiers(assembledBody),
        ],
      ),
    );
    */

    // Clean fallback using the brand's primary 3D sumi mascot reaction asset
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: ClipOval(
        child: Image.asset(
          'assets/images/sumi.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.face_retouching_natural,
              color: Colors.purpleAccent,
              size: 48),
        ),
      ),
    )
        .animate(
            key: ValueKey('fallback_sumi_${widget.state}'),
            onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -8, duration: 2.seconds, curve: Curves.easeInOut)
        .shimmer(
            delay: 1.seconds,
            duration: 1500.ms,
            color: Colors.purpleAccent.withValues(alpha: 0.1));
  }

  Widget _applyStateModifiers(Widget child) {
    // We chain flutter_animate calls based on the state to give unique "personalities"

    if (widget.state == SumiState.correct ||
        widget.state == SumiState.celebrating ||
        widget.state == SumiState.streakBoost) {
      // Joyful Jump with Squash and Stretch
      return child
          .animate(key: ValueKey('correct_jump'))
          .scale(
              begin: const Offset(1.2, 0.8),
              end: const Offset(0.9, 1.1),
              duration: 200.ms,
              curve: Curves.easeOut) // Squash then stretch
          .moveY(
              end: -30, duration: 300.ms, curve: Curves.easeOutCirc) // Jump up
          .then()
          .moveY(
              end: 0, duration: 300.ms, curve: Curves.easeInCirc) // Fall down
          .scale(
              begin: const Offset(0.9, 1.1),
              end: const Offset(1.1, 0.9),
              duration: 150.ms) // Squash on impact
          .then()
          .scale(
              begin: const Offset(1.1, 0.9),
              end: const Offset(1.0, 1.0),
              duration: 200.ms,
              curve: Curves.elasticOut); // Settle
    } else if (widget.state == SumiState.incorrect ||
        widget.state == SumiState.tired) {
      // Defeated Droop
      return child
          .animate(key: ValueKey('sad_droop'))
          .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.05, 0.85),
              duration: 800.ms,
              curve: Curves.bounceOut) // Flatten out
          .moveY(end: 15, duration: 800.ms, curve: Curves.easeOut) // Sink down
          .rotate(end: 0.05, duration: 1000.ms); // Slight tilt of defeat
    } else if (widget.state == SumiState.thinking) {
      // Pondering tilt
      return child
          .animate(key: ValueKey('thinking_tilt'))
          .rotate(
              end: -0.05,
              duration: 600.ms,
              curve: Curves.easeInOut) // Tilt head left
          .moveY(end: -5, duration: 600.ms)
          .then()
          .rotate(
              end: 0.02,
              duration: 1200.ms,
              curve: Curves.easeInOut); // Slowly sway right
    } else if (widget.state == SumiState.confused) {
      // Confused back and forth tilt
      return child
          .animate(
              key: ValueKey('confused_tilt'),
              onPlay: (c) => c.repeat(reverse: true))
          .rotate(
              begin: -0.08,
              end: 0.08,
              duration: 800.ms,
              curve: Curves.easeInOutSine);
    } else if (widget.state == SumiState.shocked ||
        widget.state == SumiState.analytical) {
      // Wide awake, slight vibration
      return child
          .animate(
              key: ValueKey('shocked_vibes'),
              onPlay: (c) => c.repeat(reverse: true))
          .moveY(end: -10, duration: 200.ms, curve: Curves.easeOut)
          .scale(end: const Offset(1.05, 1.05), duration: 200.ms)
          .shake(hz: 8, offset: const Offset(1, 1), duration: 1.seconds);
    }

    // Default continuous breathing scale (Squash & Stretch breathing)
    return child
        .animate(
            key: const ValueKey('idle_breathe'),
            onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.03, 0.98), // Body gets slightly wider and shorter
          duration: 3000.ms,
          curve: Curves.easeInOutSine,
        );
  }

  Widget _buildDialogueBubble(ThemeData theme) {
    if (!widget.showBubble ||
        widget.dialogue == null ||
        widget.dialogue!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: -20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: widget.size * 1.8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            widget.dialogue!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ).animate().fadeIn(duration: 400.ms).scale(
            alignment: Alignment.bottomCenter,
            begin: const Offset(0.8, 0.8),
            curve: Curves.easeOutBack,
          ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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

class _SumiMascotState extends State<SumiMascot> {
  VideoPlayerController? _controller;
  String? _currentAsset;
  bool _hasError = false;
  bool _isInitializing = false;

  final Map<SumiState, String> _assetMap = {
    SumiState.idle: 'assets/mascot/animations/Happy.gif',
    SumiState.focused: 'assets/mascot/animations/Locked In Studying.gif',
    SumiState.thinking: 'assets/mascot/animations/Thinking.gif',
    SumiState.correct: 'assets/mascot/animations/Celebrating Success.gif',
    SumiState.celebrating: 'assets/mascot/animations/Celebrating Success.gif',
    SumiState.incorrect: 'assets/mascot/animations/Sad Disappointed.gif',
    SumiState.confused: 'assets/mascot/animations/Confused.gif',
    SumiState.tired: 'assets/mascot/animations/Sleepy Burned Out.gif',
    SumiState.streakBoost: 'assets/mascot/animations/Motivating User.gif',
    SumiState.analytical: 'assets/mascot/animations/AI Super Mode.gif',
    SumiState.speaking: 'assets/mascot/animations/Happy.gif',
    SumiState.shocked: 'assets/mascot/animations/Shocked.gif',
  };

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant SumiMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    final asset = _assetMap[widget.state] ?? _assetMap[SumiState.idle]!;
    
    if (asset == _currentAsset && !_hasError) return;
    if (_isInitializing && asset == _currentAsset) return;
    
    _currentAsset = asset;
    _isInitializing = true;
    _hasError = false;

    // Handle GIF separately
    if (asset.endsWith('.gif')) {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }
      _isInitializing = false;
      if (mounted) setState(() {});
      return;
    }

    // Dispose old controller
    final oldController = _controller;
    _controller = VideoPlayerController.asset(asset);
    
    try {
      // Add a 4-second timeout to prevent endless loading
      await _controller!.initialize().timeout(const Duration(seconds: 4));
      
      if (mounted && _currentAsset == asset) {
        await _controller!.setLooping(true);
        await _controller!.play();
        _hasError = false;
      }
      
      if (oldController != null) {
        await oldController.dispose();
      }
    } catch (e) {
      debugPrint('Error initializing Sumi video ($asset): $e');
      _hasError = true;
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }
    } finally {
      _isInitializing = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        _buildDialogueBubble(theme),
        _buildMascotBody(),
      ],
    );
  }

  Widget _buildMascotBody() {
    final asset = _assetMap[widget.state] ?? _assetMap[SumiState.idle]!;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: _hasError 
          ? _buildFallbackImage()
          : (asset.endsWith('.gif')
            ? Image.asset(
                asset,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _buildFallbackImage(),
              )
            : (_controller != null && _controller!.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const CircularProgressIndicator(strokeWidth: 2))),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Image.asset(
      'assets/images/sumi.png',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
    ).animate().fadeIn();
  }

  Widget _buildDialogueBubble(ThemeData theme) {
    if (!widget.showBubble || widget.dialogue == null || widget.dialogue!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: -10,
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

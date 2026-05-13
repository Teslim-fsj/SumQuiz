import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../theme/cyber_neural_theme.dart';
import '../../providers/sumi_provider.dart';
import '../../models/sumi_emotion.dart';
import '../../models/sumi_message.dart';
import '../../services/recording_service.dart';
import '../widgets/neural_orb.dart';

class SumiLiveScreen extends StatefulWidget {
  final String? groundingSource;
  const SumiLiveScreen({super.key, this.groundingSource});

  @override
  State<SumiLiveScreen> createState() => _SumiLiveScreenState();
}

class _SumiLiveScreenState extends State<SumiLiveScreen> {
  bool _isGroundedMode = false;
  double _voiceAmplitude = 0.0;
  StreamSubscription<double>? _amplitudeSub;
  final TextEditingController _liveTextController = TextEditingController();

  DateTime? _sessionStart;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SumiProvider>().startLiveSession(context: widget.groundingSource);
    });

    _amplitudeSub = RecordingService().amplitudeStream.listen((amp) {
      if (mounted) setState(() => _voiceAmplitude = amp);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _liveTextController.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SumiProvider>().stopLiveSession();
    });
    super.dispose();
  }

  OrbState _getOrbState(SumiProvider sumi) {
    if (sumi.isSumiSpeaking) return OrbState.speaking;
    if (sumi.isVoiceRecording) return OrbState.listening;
    
    switch (sumi.currentState) {
      case SumiState.thinking: return OrbState.thinking;
      case SumiState.analytical: return OrbState.momentum;
      case SumiState.tired: return OrbState.burnout;
      case SumiState.focused: return OrbState.thinking;
      default: return OrbState.idle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sumi = context.watch<SumiProvider>();
    
    return Scaffold(
      backgroundColor: CyberNeuralColors.background,
      body: Stack(
        children: [
          // Ambient Background System
          _buildAmbientBackground(sumi),

          // Main Content
          SafeArea(
            child: _isGroundedMode 
              ? _buildSplitScreenLayout(sumi)
              : _buildVoiceCentricLayout(sumi),
          ),

          // Top Floating Navigation Bar
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: _buildTopBar(sumi),
          ),

          // Exit Button
          Positioned(
            top: 20,
            right: 20,
            child: _buildExitButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBackground(SumiProvider sumi) {
    Color moodColor;
    switch (sumi.currentState) {
      case SumiState.tired: moodColor = CyberNeuralColors.amber; break;
      case SumiState.thinking: moodColor = CyberNeuralColors.purple; break;
      case SumiState.analytical: moodColor = CyberNeuralColors.gold; break;
      default: moodColor = CyberNeuralColors.cyan;
    }

    return AnimatedContainer(
      duration: 2.seconds,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            moodColor.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(SumiProvider sumi) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: CyberNeuralColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSessionTimer(),
              const SizedBox(width: 16),
              const VerticalDivider(color: Colors.white10, indent: 12, endIndent: 12),
              const SizedBox(width: 16),
              _buildGroundedIndicator(),
              const Spacer(),
              _buildNeuralHealth(),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.settings_outlined, size: 16, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionTimer() {
    final duration = DateTime.now().difference(_sessionStart ?? DateTime.now());
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(color: CyberNeuralColors.cyan, shape: BoxShape.circle),
        ).animate(onPlay: (c) => c.repeat()).fadeIn().fadeOut(),
        const SizedBox(width: 8),
        Text(
          "$minutes:$seconds",
          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildGroundedIndicator() {
    return Row(
      children: [
        const Icon(Icons.description_outlined, size: 14, color: CyberNeuralColors.textTertiary),
        const SizedBox(width: 8),
        Text(
          "Grounded in ${widget.groundingSource ?? 'Neural Core'}",
          style: GoogleFonts.inter(fontSize: 11, color: CyberNeuralColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildNeuralHealth() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CyberNeuralColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, size: 10, color: CyberNeuralColors.success),
          const SizedBox(width: 4),
          Text(
            "STABLE",
            style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: CyberNeuralColors.success),
          ),
        ],
      ),
    );
  }

  Widget _buildExitButton() {
    return IconButton(
      onPressed: () => context.pop(),
      icon: const Icon(Icons.close_rounded, color: Colors.white54),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }

  Widget _buildVoiceCentricLayout(SumiProvider sumi) {
    return Column(
      children: [
        const Spacer(),
        
        // Centerpiece — The Neural Orb
        NeuralOrb(
          state: _getOrbState(sumi),
          amplitude: _voiceAmplitude,
        ),
        
        const Spacer(),

        // Predictive AI Prompts
        _buildPredictivePrompts(sumi),
        
        const SizedBox(height: 24),

        // Voice Subtitle System
        _buildVoiceSubtitles(sumi),
        
        const Spacer(),

        // Text Input Overlay
        _buildLiveTextInput(sumi),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLiveTextInput(SumiProvider sumi) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 48,
      decoration: BoxDecoration(
        color: CyberNeuralColors.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _liveTextController,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: "TYPE YOUR QUERY...",
                hintStyle: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white24),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(bottom: 4),
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  sumi.askSumi(text, context: widget.groundingSource);
                  _liveTextController.clear();
                }
              },
            ),
          ),
          IconButton(
            onPressed: () {
              final text = _liveTextController.text;
              if (text.trim().isNotEmpty) {
                sumi.askSumi(text, context: widget.groundingSource);
                _liveTextController.clear();
              }
            },
            icon: const Icon(Icons.arrow_upward_rounded, size: 18, color: CyberNeuralColors.cyan),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictivePrompts(SumiProvider sumi) {
    final prompts = ["Explain the diagram", "Test my memory", "Simplify this topic", "What am I forgetting?"];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: prompts.map((p) => _buildPromptChip(p, sumi)).toList(),
      ),
    );
  }

  Widget _buildPromptChip(String text, SumiProvider sumi) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: ActionChip(
        label: Text(text),
        onPressed: () => sumi.askSumi(text, context: widget.groundingSource),
        backgroundColor: CyberNeuralColors.surface.withValues(alpha: 0.3),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
    );
  }

  Widget _buildVoiceSubtitles(SumiProvider sumi) {
    final text = sumi.isStreaming ? (sumi.streamingMessage ?? "Thinking...") : (sumi.dialogue ?? "Listening...");
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: Colors.white.withValues(alpha: 0.8),
          height: 1.5,
          letterSpacing: 0.2,
        ),
      ).animate(key: ValueKey(text)).fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildSplitScreenLayout(SumiProvider sumi) {
    return Row(
      children: [
        // Left Side — Document Viewer (65%)
        Expanded(
          flex: 65,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CyberNeuralColors.surface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: const Center(
              child: Icon(Icons.picture_as_pdf, size: 48, color: Colors.white10),
            ),
          ),
        ),

        // Right Side — AI Interface (35%)
        Expanded(
          flex: 35,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sumi.messages.length,
                  itemBuilder: (context, index) {
                    final msg = sumi.messages[index];
                    if (msg.role == MessageRole.user) {
                      return _buildAIResponseBubble(msg.text);
                    } else {
                      return _buildSumiResponse(msg.text);
                    }
                  },
                ),
              ),
              if (sumi.isStreaming)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildSumiResponse(sumi.streamingMessage ?? "..."),
                ),
              
              // Neural Status Indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _getTurnIndicator(sumi),
                  style: GoogleFonts.jetBrainsMono(fontSize: 9, color: CyberNeuralColors.cyan, letterSpacing: 1),
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
              ),

              _buildNeuralOrbSmall(sumi),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  String _getTurnIndicator(SumiProvider sumi) {
    if (sumi.isSumiSpeaking) return "NEURAL BROADCAST ACTIVE";
    if (sumi.isProcessingVoice) return "SYNAPSES FIRING...";
    if (sumi.isVoiceRecording) return "AWAITING NEURAL INPUT";
    return "LINK STABLE - READY";
  }

  Widget _buildAIResponseBubble(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: CyberNeuralColors.surfaceAlt.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
    );
  }

  Widget _buildSumiResponse(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "SUMI ANALYSIS",
          style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: CyberNeuralColors.cyan, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white, height: 1.5),
        ),
        const SizedBox(height: 16),
        // Dynamic knowledge chips could be added here in the future
      ],
    );
  }

  Widget _buildKnowledgeChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CyberNeuralColors.cyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CyberNeuralColors.cyan.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.psychology_outlined, size: 12, color: CyberNeuralColors.cyan),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: CyberNeuralColors.cyan)),
        ],
      ),
    );
  }

  Widget _buildNeuralOrbSmall(SumiProvider sumi) {
    return GestureDetector(
      onTap: () => setState(() => _isGroundedMode = !_isGroundedMode),
      child: NeuralOrb(
        state: _getOrbState(sumi),
        amplitude: _voiceAmplitude,
      ),
    );
  }
}

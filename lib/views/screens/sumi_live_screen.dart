import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/sumi_provider.dart';
import '../../models/sumi_emotion.dart';
import '../../models/sumi_message.dart';
import '../../services/recording_service.dart';
import '../widgets/aura_orb.dart';
import '../widgets/aura_alert_banner.dart';

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
    final theme = Theme.of(context);
    final sumi = context.watch<SumiProvider>();
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Ambient Background Aura
          _buildAmbientBackground(theme, sumi),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                if (sumi.errorMessage != null)
                  AuraAlertBanner(
                    title: "Neural Disruption",
                    description: sumi.errorMessage!,
                    onIgnore: () => sumi.clearError(),
                    actionLabel: "RETRY",
                    onAction: () => sumi.startLiveSession(context: widget.groundingSource),
                  ),
                Expanded(
                  child: _isGroundedMode 
                    ? _buildSplitScreenLayout(theme, sumi)
                    : _buildVoiceCentricLayout(theme, sumi),
                ),
              ],
            ),
          ),

          // Top Floating Navigation Bar
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: _buildTopBar(theme, sumi),
          ),

          // Exit Button
          Positioned(
            top: 24,
            right: 24,
            child: _buildExitButton(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBackground(ThemeData theme, SumiProvider sumi) {
    Color moodColor;
    switch (sumi.currentState) {
      case SumiState.tired: moodColor = Colors.orange; break;
      case SumiState.thinking: moodColor = Colors.deepPurple; break;
      case SumiState.analytical: moodColor = Colors.amber; break;
      default: moodColor = theme.colorScheme.primary;
    }

    return AnimatedContainer(
      duration: 2.seconds,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            moodColor.withOpacity(0.04),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme, SumiProvider sumi) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSessionTimer(theme),
              const SizedBox(width: 20),
              const VerticalDivider(width: 1, indent: 16, endIndent: 16),
              const SizedBox(width: 20),
              _buildGroundedIndicator(theme),
              const Spacer(),
              _buildStatusBadge(theme),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildSessionTimer(ThemeData theme) {
    final duration = DateTime.now().difference(_sessionStart ?? DateTime.now());
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
        ).animate(onPlay: (c) => c.repeat()).fadeIn().fadeOut(),
        const SizedBox(width: 10),
        Text(
          "$minutes:$seconds",
          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
        ),
      ],
    );
  }

  Widget _buildGroundedIndicator(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.auto_awesome_outlined, size: 16, color: theme.hintColor),
        const SizedBox(width: 10),
        Text(
          "${widget.groundingSource ?? 'Global'}",
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: theme.hintColor),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF22C55E)),
          const SizedBox(width: 6),
          Text(
            "LIVE LINK",
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF22C55E)),
          ),
        ],
      ),
    );
  }

  Widget _buildExitButton(ThemeData theme) {
    return IconButton(
      onPressed: () => context.pop(),
      icon: Icon(Icons.close_rounded, color: theme.hintColor),
      style: IconButton.styleFrom(
        backgroundColor: theme.cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildVoiceCentricLayout(ThemeData theme, SumiProvider sumi) {
    return Column(
      children: [
        const Spacer(flex: 2),
        
        // Centerpiece — The Aura Orb
        Stack(
          alignment: Alignment.center,
          children: [
            AuraOrb(
              state: _getOrbState(sumi),
              amplitude: _voiceAmplitude,
              size: 200,
            ).animate().scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
            if (widget.groundingSource != null)
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.groundingSource!.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms),
              ),
          ],
        ),
        
        const Spacer(),

        // Predictive Prompts
        _buildPredictivePrompts(theme, sumi),
        
        const SizedBox(height: 32),

        // Subtitles / Dialogue
        _buildVoiceSubtitles(theme, sumi),
        
        const Spacer(flex: 2),

        // Bottom Actions
        _buildBottomActions(theme, sumi),
        
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildBottomActions(ThemeData theme, SumiProvider sumi) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _liveTextController,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: GoogleFonts.inter(fontSize: 14, color: theme.hintColor.withOpacity(0.5)),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          HapticFeedback.lightImpact();
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
                        HapticFeedback.lightImpact();
                        sumi.askSumi(text, context: widget.groundingSource);
                        _liveTextController.clear();
                      }
                    },
                    icon: Icon(Icons.arrow_upward_rounded, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildFloatingAction(
            _isGroundedMode ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
            () => setState(() => _isGroundedMode = !_isGroundedMode),
            theme
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildFloatingAction(IconData icon, VoidCallback onTap, ThemeData theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: theme.cardColor,
          shape: BoxShape.circle,
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: theme.hintColor, size: 22),
      ),
    );
  }

  Widget _buildPredictivePrompts(ThemeData theme, SumiProvider sumi) {
    final prompts = ["Summarize this", "Test my knowledge", "Give an analogy", "Next steps?"];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: prompts.map((p) => _buildPromptChip(theme, p, sumi)).toList(),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildPromptChip(ThemeData theme, String text, SumiProvider sumi) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: ActionChip(
        label: Text(text),
        onPressed: () => sumi.askSumi(text, context: widget.groundingSource),
        backgroundColor: theme.cardColor,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), 
          side: BorderSide(color: theme.dividerColor.withOpacity(0.1))
        ),
        elevation: 0,
        pressElevation: 0,
      ),
    );
  }

  Widget _buildVoiceSubtitles(ThemeData theme, SumiProvider sumi) {
    final text = sumi.isStreaming ? (sumi.streamingMessage ?? "Synthesizing...") : (sumi.dialogue ?? "Listening...");
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8),
          height: 1.5,
          letterSpacing: -0.2,
        ),
      ).animate(key: ValueKey(text)).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
    );
  }

  Widget _buildSplitScreenLayout(ThemeData theme, SumiProvider sumi) {
    return Row(
      children: [
        // Content Area (60%)
        Expanded(
          flex: 60,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 48, color: theme.colorScheme.primary.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  Text(
                    'CONTEXTUAL VIEW',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          ),
        ),

        // AI Panel (40%)
        Expanded(
          flex: 40,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: sumi.messages.length,
                  itemBuilder: (context, index) {
                    final msg = sumi.messages[index];
                    return _buildCompactMessage(theme, msg);
                  },
                ),
              ),
              if (sumi.isStreaming)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildCompactStreaming(theme, sumi.streamingMessage ?? "..."),
                ),
              
              const SizedBox(height: 16),
              AuraOrb(state: _getOrbState(sumi), amplitude: _voiceAmplitude, size: 100),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactMessage(ThemeData theme, SumiMessage msg) {
    final isUser = msg.role == MessageRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isUser ? "YOU" : "SUMI",
            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: isUser ? theme.hintColor : theme.colorScheme.primary, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            msg.text,
            style: GoogleFonts.inter(fontSize: 14, color: theme.textTheme.bodyLarge?.color, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStreaming(ThemeData theme, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "SUMI",
          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: theme.colorScheme.primary, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 14, color: theme.textTheme.bodyLarge?.color, height: 1.5),
        ),
      ],
    );
  }
}

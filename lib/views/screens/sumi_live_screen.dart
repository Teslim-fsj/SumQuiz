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
import '../widgets/upgrade_dialog.dart';

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
    final colorScheme = theme.colorScheme;
    final sumi = context.watch<SumiProvider>();

    // Show upgrade sheet whenever the limit flag is triggered
    if (sumi.limitReached) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          sumi.clearLimitReached();
          UpgradeDialog.show(context, featureName: 'Sumi Live Tutoring');
        }
      });
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
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
            top: MediaQuery.paddingOf(context).top + 16,
            left: 24,
            right: 24,
            child: _buildTopBar(theme, sumi),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBackground(ThemeData theme, SumiProvider sumi) {
    final colorScheme = theme.colorScheme;
    Color moodColor;
    switch (sumi.currentState) {
      case SumiState.tired: moodColor = Colors.orange; break;
      case SumiState.thinking: moodColor = colorScheme.tertiary; break;
      case SumiState.analytical: moodColor = colorScheme.secondary; break;
      default: moodColor = colorScheme.primary;
    }

    return AnimatedContainer(
      duration: 2.seconds,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            moodColor.withValues(alpha: 0.08),
            colorScheme.surface,
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme, SumiProvider sumi) {
    final colorScheme = theme.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  shape: const CircleBorder(),
                ),
              ),
              const SizedBox(width: 16),
              _buildSessionTimer(theme),
              if (widget.groundingSource != null) ...[
                const SizedBox(width: 16),
                Container(width: 1, height: 24, color: colorScheme.outline.withValues(alpha: 0.2)),
                const SizedBox(width: 16),
                _buildGroundedIndicator(theme),
              ],
              const Spacer(),
              _buildStatusBadge(theme),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildSessionTimer(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final duration = DateTime.now().difference(_sessionStart ?? DateTime.now());
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
        ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 800.ms).fadeOut(duration: 800.ms),
        const SizedBox(width: 10),
        Text(
          "$minutes:$seconds",
          style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildGroundedIndicator(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(Icons.auto_awesome_rounded, size: 16, color: colorScheme.tertiary),
        const SizedBox(width: 8),
        Text(
          "${widget.groundingSource}",
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Icon(Icons.spatial_audio_off_rounded, size: 14, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            "VOICE SYNC",
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCentricLayout(ThemeData theme, SumiProvider sumi) {
    return Column(
      children: [
        const Spacer(flex: 3),
        
        // Centerpiece — The Aura Orb
        Stack(
          alignment: Alignment.center,
          children: [
            AuraOrb(
              state: _getOrbState(sumi),
              amplitude: _voiceAmplitude,
              size: 240,
            ).animate().scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack, duration: 800.ms),
          ],
        ),
        
        const Spacer(flex: 2),

        // Subtitles / Dialogue
        _buildVoiceSubtitles(theme, sumi),
        
        const SizedBox(height: 48),

        // Predictive Prompts
        _buildPredictivePrompts(theme, sumi),
        
        const Spacer(flex: 1),

        // Bottom Actions
        _buildBottomActions(theme, sumi),
        
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildBottomActions(ThemeData theme, SumiProvider sumi) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _liveTextController,
                      style: GoogleFonts.inter(fontSize: 15, color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: "Type a message instead...",
                        hintStyle: GoogleFonts.inter(fontSize: 15, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
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
                    icon: Icon(Icons.arrow_upward_rounded, color: colorScheme.onPrimary),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildFloatingAction(
            _isGroundedMode ? Icons.close_fullscreen_rounded : Icons.splitscreen_rounded,
            () => setState(() => _isGroundedMode = !_isGroundedMode),
            theme
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildFloatingAction(IconData icon, VoidCallback onTap, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: colorScheme.onSurfaceVariant, size: 24),
      ),
    );
  }

  Widget _buildPredictivePrompts(ThemeData theme, SumiProvider sumi) {
    final prompts = ["Explain that again", "Test my knowledge", "Give me an analogy", "Can we summarize?"];
    final colorScheme = theme.colorScheme;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: prompts.map((p) => Container(
          margin: const EdgeInsets.only(right: 12),
          child: ActionChip(
            label: Text(p),
            onPressed: () => sumi.askSumi(p, context: widget.groundingSource),
            backgroundColor: colorScheme.surface,
            labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100), 
              side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2))
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            elevation: 0,
            pressElevation: 0,
          ),
        )).toList(),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildVoiceSubtitles(ThemeData theme, SumiProvider sumi) {
    final colorScheme = theme.colorScheme;
    final text = sumi.isStreaming ? (sumi.streamingMessage ?? "Synthesizing...") : (sumi.dialogue ?? "I'm listening...");
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface.withValues(alpha: 0.9),
          height: 1.3,
        ),
      ).animate(key: ValueKey(text)).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
    );
  }

  Widget _buildSplitScreenLayout(ThemeData theme, SumiProvider sumi) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 100), // Account for top bar
      child: Row(
        children: [
          // Content Area (50%)
          Expanded(
            flex: 50,
            child: Container(
              margin: const EdgeInsets.only(left: 24, bottom: 24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 64, color: colorScheme.tertiary.withValues(alpha: 0.3)),
                    const SizedBox(height: 24),
                    Text(
                      'ACTIVE CONTEXT',
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant, letterSpacing: 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // AI Panel (50%)
          Expanded(
            flex: 50,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    itemCount: sumi.messages.length,
                    itemBuilder: (context, index) {
                      final msg = sumi.messages[index];
                      return _buildCompactMessage(theme, msg);
                    },
                  ),
                ),
                if (sumi.isStreaming)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: _buildCompactStreaming(theme, sumi.streamingMessage ?? "..."),
                  ),
                
                const SizedBox(height: 24),
                AuraOrb(state: _getOrbState(sumi), amplitude: _voiceAmplitude, size: 120),
                const SizedBox(height: 32),
                _buildBottomActions(theme, sumi),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMessage(ThemeData theme, SumiMessage msg) {
    final colorScheme = theme.colorScheme;
    final isUser = msg.role == MessageRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isUser ? "YOU" : "SUMI",
            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: isUser ? colorScheme.onSurfaceVariant : colorScheme.primary, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUser ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) : colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isUser ? colorScheme.outline.withValues(alpha: 0.1) : colorScheme.primary.withValues(alpha: 0.1)),
            ),
            child: Text(
              msg.text,
              style: GoogleFonts.inter(fontSize: 15, color: colorScheme.onSurface, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStreaming(ThemeData theme, String text) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "SUMI",
          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.primary, letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
          ),
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 15, color: colorScheme.onSurface, height: 1.6),
          ),
        ),
      ],
    );
  }
}

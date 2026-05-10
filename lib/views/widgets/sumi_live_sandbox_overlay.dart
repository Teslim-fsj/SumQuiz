import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/sumi_provider.dart';
import '../../models/sumi_emotion.dart';
import '../../widgets/sumi_mascot.dart';
import '../../services/compute_manager.dart';
import 'dart:ui';
import 'sumi_chat_view.dart';
import '../../models/sumi_message.dart';

class SumiLiveSandboxOverlay extends StatefulWidget {
  const SumiLiveSandboxOverlay({super.key});

  @override
  State<SumiLiveSandboxOverlay> createState() => _SumiLiveSandboxOverlayState();
}

class _SumiLiveSandboxOverlayState extends State<SumiLiveSandboxOverlay> {
  bool _isListening = false;
  bool _isProcessing = false;
  String? _currentFileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sumiProvider = context.watch<SumiProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Glassmorphic Backdrop
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
            ),
          ),

          // Close Button
          Positioned(
            top: 50,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                if (_currentFileName == null)
                  Expanded(child: Center(child: _buildUploadPrompt(theme)))
                else
                  Expanded(child: _buildTutorMode(theme, sumiProvider)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildUploadPrompt(ThemeData theme) {
    return Column(
      children: [
        SumiMascot(
          state: SumiState.idle,
          size: 180,
          dialogue: "Drop a file here to start a Quick Tutor session!",
        ).animate().fadeIn().scale(),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: () {
            setState(() {
              _currentFileName = "Biology_Chapter_1.pdf";
              _isProcessing = true;
            });
            Future.delayed(const Duration(seconds: 2), () {
              setState(() => _isProcessing = false);
            });
          },
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.upload_file, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  "Upload External Resource",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "PDF, Image, or URL",
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
        ),
      ],
    );
  }

  Widget _buildTutorMode(ThemeData theme, SumiProvider sumi) {
    return Column(
      children: [
        // Compact Header with Mascot
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              SumiMascot(
                state: sumi.currentState,
                size: 60,
                showBubble: false,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Sumi Tutor",
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Grounded in: $_currentFileName",
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const Divider(height: 1),

        // ChatGPT-Style Chat View
        const Expanded(
          child: SumiChatView(),
        ),

        // Voice Controls (Sticky at bottom if needed, or integrated into ChatView)
        // For now, let's keep them separate as a modern toggle
        _buildVoiceControls(theme, sumi),
      ],
    );
  }


  Widget _buildVoiceControls(ThemeData theme, SumiProvider sumi) {
    return Column(
      children: [
        if (_isListening)
          _buildWaveform(theme)
        else
          const SizedBox(height: 40),
          
        const SizedBox(height: 20),
        
        GestureDetector(
          onTapDown: (_) => setState(() => _isListening = true),
          onTapUp: (_) async {
            setState(() {
              _isListening = false;
              _isProcessing = true;
            });
            
            // Compute Orchestration (Invisible Economy)
            final compute = ComputeManager();
            final canProceed = await compute.orchestrateAction(
              "user_id_here", // Should be passed from parent
              "mascot",
            );

            if (!canProceed) {
              sumi.showTutorMessage(
                "I'm integrating your recent progress. Let's take a quick 1-minute neural reset!",
                state: SumiState.tired,
              );
              setState(() => _isProcessing = false);
              return;
            }

            // Simulated Voice Recognition (Production placeholder)
            await Future.delayed(const Duration(seconds: 1));
            setState(() => _isProcessing = false);
            
            const mockTranscript = "Explain the primary function of the mitochondria.";
            await sumi.askSumi(mockTranscript, context: "Studying Biology: $_currentFileName");
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _isListening ? Colors.red.withValues(alpha: 0.2) : theme.colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 40,
            ),
          ).animate(onPlay: (controller) => controller.repeat())
           .shimmer(duration: 2.seconds, color: Colors.white24),
        ),
        const SizedBox(height: 16),
        Text(
          _isListening ? "Listening..." : "Hold to Speak",
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildWaveform(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(15, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 4,
          height: 10 + (math.Random().nextDouble() * 30),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .scaleY(duration: (200 + (index * 50)).ms, begin: 0.5, end: 1.5);
      }),
    );
  }
}

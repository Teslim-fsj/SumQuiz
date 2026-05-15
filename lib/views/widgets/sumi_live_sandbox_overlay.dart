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
  final bool _isListening = false;
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
                Icon(Icons.upload_file,
                    size: 48, color: theme.colorScheme.primary),
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
        // Compact Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Sumi Tutor",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Grounded in: $_currentFileName",
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ChatGPT-Style Chat View
        Expanded(
          child: SumiChatView(groundingContext: _currentFileName),
        ),
      ],
    );
  }
}

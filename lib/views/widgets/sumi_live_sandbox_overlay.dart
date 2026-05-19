import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/sumi_provider.dart';
import 'dart:ui';
import 'sumi_chat_view.dart';
import 'upgrade_dialog.dart';

/// Inline overlay (shown as a modal route) that provides Sumi tutoring —
/// voice + text — with no upfront file-upload gate.
/// Users can optionally add context files via the [SumiChatView] '+' button.
class SumiLiveSandboxOverlay extends StatefulWidget {
  /// Optional pre-loaded context (e.g. extracted text from a deck or note).
  final String? groundingContext;

  const SumiLiveSandboxOverlay({super.key, this.groundingContext});

  @override
  State<SumiLiveSandboxOverlay> createState() => _SumiLiveSandboxOverlayState();
}

class _SumiLiveSandboxOverlayState extends State<SumiLiveSandboxOverlay> {
  @override
  void initState() {
    super.initState();
    // Start the tutor session immediately — no upload required.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLimitAndStart();
    });
  }

  Future<void> _checkLimitAndStart() async {
    final sumi = context.read<SumiProvider>();
    // Reset any stale limit flag from a previous session
    if (sumi.limitReached) sumi.clearLimitReached();
  }

  void _onLimitReached(BuildContext ctx) {
    final sumi = ctx.read<SumiProvider>();
    sumi.clearLimitReached();
    UpgradeDialog.show(ctx, featureName: 'Sumi Tutoring');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Consumer<SumiProvider>(
      builder: (ctx, sumi, _) {
        // React to limit reached once per trigger
        if (sumi.limitReached) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _onLimitReached(ctx);
          });
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Glassmorphic backdrop
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(color: cs.surface.withValues(alpha: 0.92)),
              ),

              // Close button
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                right: 16,
                child: IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: cs.onSurfaceVariant, size: 28),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    shape: const CircleBorder(),
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 72, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sumi Tutor',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // Live indicator dot
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: sumi.isLiveSession
                                      ? cs.primary
                                      : cs.outlineVariant,
                                  shape: BoxShape.circle,
                                ),
                              )
                                  .animate(onPlay: (c) => c.repeat())
                                  .fadeIn(duration: 700.ms)
                                  .fadeOut(duration: 700.ms),
                              const SizedBox(width: 8),
                              Text(
                                sumi.isVoiceRecording
                                    ? 'Listening...'
                                    : sumi.isStreaming
                                        ? 'Thinking...'
                                        : sumi.isSumiSpeaking
                                            ? 'Speaking...'
                                            : widget.groundingContext != null
                                                ? 'Grounded in your material'
                                                : 'Ask me anything',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: -0.1, end: 0),

                    const Divider(height: 1),

                    // ── Chat / tutoring view ────────────────────────────────
                    Expanded(
                      child: SumiChatView(
                        groundingContext: widget.groundingContext,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

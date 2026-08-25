import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../providers/sumi_provider.dart';
import '../../models/sumi_message.dart';
import '../../services/content_extraction_service.dart';
import '../../utils/youtube_pro_gate.dart';
import 'upgrade_dialog.dart';

class SumiChatView extends StatefulWidget {
  final String? groundingContext;
  const SumiChatView({super.key, this.groundingContext});

  @override
  State<SumiChatView> createState() => _SumiChatViewState();
}

class _SumiChatViewState extends State<SumiChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _additionalContext = '';
  bool _isExtractingContext = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sumiProvider = context.watch<SumiProvider>();

    // Show upgrade sheet once when the limit flag fires
    if (sumiProvider.limitReached) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          sumiProvider.clearLimitReached();
          UpgradeDialog.show(context, featureName: 'Sumi Tutoring');
        }
      });
    }

    // Auto-scroll when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: sumiProvider.messages.length +
                (sumiProvider.isStreaming ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < sumiProvider.messages.length) {
                final message = sumiProvider.messages[index];
                return _buildMessageBubble(theme, message);
              } else {
                return _buildStreamingBubble(
                    theme, sumiProvider.streamingMessage ?? "");
              }
            },
          ),
        ),
        _buildInputArea(theme, sumiProvider),
        if (sumiProvider.isSumiSpeaking) _buildSpeakingIndicator(theme),
      ],
    );
  }

  Widget _buildSpeakingIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: theme.colorScheme.primary.withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.volume_up_rounded,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            'SUMI IS SPEAKING...',
            style: GoogleFonts.inter(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 1.2),
          ),
        ],
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
    );
  }

  Widget _buildStreamingBubble(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border:
                  Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: text.isEmpty
                ? _buildTypingIndicator(theme)
                : MarkdownBody(
                    data: text,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.inter(height: 1.5, fontSize: 14),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              "SUMI TUTOR",
              style: GoogleFonts.inter(
                color: theme.colorScheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
          3,
          (i) => Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scale(
                    delay: (i * 200).ms,
                    duration: 600.ms,
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    curve: Curves.easeInOut,
                  )
                  .fadeIn(
                    delay: (i * 200).ms,
                    duration: 600.ms,
                  )),
    );
  }

  Widget _buildMessageBubble(ThemeData theme, SumiMessage message) {
    final isUser = message.role == MessageRole.user;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 12, top: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B5CE7).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/sumi.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF6B5CE7),
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF6B5CE7)
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    border: Border.all(
                      color: isUser
                          ? Colors.transparent
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE2E8F0)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isUser
                            ? const Color(0xFF6B5CE7).withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isUser
                      ? Text(
                          message.text,
                          style: GoogleFonts.inter(
                            height: 1.5,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        )
                      : MarkdownBody(
                          data: message.text,
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.inter(
                              height: 1.5,
                              fontSize: 14,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            h1: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            h2: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            code: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFF1F5F9),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
                top: 6, left: isUser ? 0 : 44, right: isUser ? 4 : 0),
            child: Text(
              isUser ? "YOU" : "SUMI AI TUTOR",
              style: GoogleFonts.inter(
                color: isUser ? const Color(0xFF94A3B8) : const Color(0xFF6B5CE7),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildInputArea(ThemeData theme, SumiProvider sumi) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
            top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: "Ask Sumi anything or paste notes...",
                  hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 14),
                  prefixIcon: _isExtractingContext
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF6B5CE7)))
                      : IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              size: 20),
                          color: const Color(0xFF6B5CE7),
                          onPressed: _pickFiles,
                          tooltip: 'Attach PDF, notes, or image context',
                        ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.mic_none_rounded, size: 20),
                    color: const Color(0xFF6B5CE7),
                    onPressed: () => _startVoiceTutoring(sumi),
                    tooltip: 'Live voice mode',
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _sendMessage(sumi),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: () => _sendMessage(sumi),
            icon: sumi.isStreaming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.arrow_upward_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF6B5CE7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'png', 'jpg', 'jpeg', 'webp', 'md'],
      withData: true,
    );

    if (result != null &&
        result.files.single.bytes != null &&
        result.files.single.bytes!.isNotEmpty) {
      setState(() => _isExtractingContext = true);
      try {
        final extractionService = context.read<ContentExtractionService>();
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
        final fileName = result.files.single.name.toLowerCase();
        final bytes = result.files.single.bytes!;

        String type;
        dynamic input;
        String mimeType;

        if (fileName.endsWith('.pdf')) {
          type = 'pdf';
          input = bytes;
          mimeType = 'application/pdf';
        } else if (fileName.endsWith('.png') ||
            fileName.endsWith('.jpg') ||
            fileName.endsWith('.jpeg') ||
            fileName.endsWith('.webp')) {
          type = 'image';
          input = bytes;
          mimeType = fileName.endsWith('.png')
              ? 'image/png'
              : (fileName.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
        } else {
          type = 'text';
          input = utf8.decode(bytes, allowMalformed: true);
          mimeType = 'text/plain';
        }

        UserModel? user;
        try {
          user = context.read<UserModel?>();
        } catch (_) {}

        final allowPdf = userMayImportFromPdf(user);
        final allowWeb = userMayImportFromWeb(user);

        final extResult = await extractionService.extractContent(
          type: type,
          input: input,
          userId: userId,
          mimeType: mimeType,
          allowPdfImport: allowPdf,
          allowWebImport: allowWeb,
        );

        if (extResult.text.trim().isNotEmpty) {
          setState(() {
            _additionalContext +=
                '\n\n[Content from ${result.files.single.name}]:\n${extResult.text.trim()}';
            _isExtractingContext = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                content: Text(
                  'Added ${result.files.single.name} to context',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
        } else {
          setState(() => _isExtractingContext = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No extractable content found in ${result.files.single.name}',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ),
            );
          }
        }
      } catch (e) {
        setState(() => _isExtractingContext = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _startVoiceTutoring(SumiProvider sumi) {
    context.push(
        '/sumi-live?source=${widget.groundingContext ?? "General Context"}');
  }

  void _sendMessage(SumiProvider sumi) {
    final text = _controller.text.trim();
    if (text.isEmpty || sumi.isStreaming) return;

    HapticFeedback.lightImpact();

    final fullContext = [
      if (widget.groundingContext != null) widget.groundingContext!,
      if (_additionalContext.isNotEmpty) _additionalContext,
    ].join('\n\n');

    sumi.askSumi(text, context: fullContext.isNotEmpty ? fullContext : null);
    _controller.clear();
    _additionalContext = ''; // Clear additional context after sending
    _scrollToBottom();
  }
}

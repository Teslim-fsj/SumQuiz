import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import '../../providers/sumi_provider.dart';
import '../../models/sumi_message.dart';

class SumiChatView extends StatefulWidget {
  final String? groundingContext;
  const SumiChatView({super.key, this.groundingContext});

  @override
  State<SumiChatView> createState() => _SumiChatViewState();
}

class _SumiChatViewState extends State<SumiChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: sumiProvider.messages.length + (sumiProvider.isStreaming ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < sumiProvider.messages.length) {
                final message = sumiProvider.messages[index];
                return _buildMessageBubble(theme, message);
              } else {
                return _buildStreamingBubble(theme, sumiProvider.streamingMessage ?? "");
              }
            },
          ),
        ),
        _buildInputArea(theme, sumiProvider),
        if (sumiProvider.isSumiSpeaking)
          _buildSpeakingIndicator(theme),
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
          Icon(Icons.volume_up_rounded, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            'SUMI IS SPEAKING...',
            style: GoogleFonts.inter(
              color: theme.colorScheme.primary, 
              fontWeight: FontWeight.bold, 
              fontSize: 10,
              letterSpacing: 1.2
            ),
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
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
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
      children: List.generate(3, (i) => 
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
        ).animate(onPlay: (c) => c.repeat()).scale(
          delay: (i * 200).ms,
          duration: 600.ms,
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
          curve: Curves.easeInOut,
        ).fadeIn(
          delay: (i * 200).ms,
          duration: 600.ms,
        )
      ),
    );
  }

  Widget _buildMessageBubble(ThemeData theme, SumiMessage message) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary.withValues(alpha: 0.08)
                        : theme.cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    border: Border.all(
                      color: isUser 
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : theme.dividerColor.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 5, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: isUser 
                    ? Text(
                        message.text,
                        style: GoogleFonts.inter(
                          height: 1.5,
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      )
                    : MarkdownBody(
                        data: message.text,
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.inter(height: 1.5, fontSize: 14),
                        ),
                      ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
                top: 8, left: isUser ? 0 : 4, right: isUser ? 4 : 0),
            child: Text(
              isUser ? "YOU" : "SUMI TUTOR",
              style: GoogleFonts.inter(
                color: isUser ? theme.hintColor : theme.colorScheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildInputArea(ThemeData theme, SumiProvider sumi) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Ask Sumi anything...",
                  hintStyle: GoogleFonts.inter(color: theme.hintColor.withValues(alpha: 0.5), fontSize: 14),
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    onPressed: _pickFiles,
                    tooltip: 'Add context',
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.mic_none_rounded, size: 20),
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    onPressed: () => _startVoiceTutoring(sumi),
                    tooltip: 'Voice mode',
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(sumi),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: () => _sendMessage(sumi),
            icon: sumi.isStreaming 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.arrow_upward_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg', 'mp3', 'wav'],
    );
    
    if (result != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            content: Text(
              '${result.files.length} sources added to context',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }
  }

  void _startVoiceTutoring(SumiProvider sumi) {
    context.push('/sumi-live?source=${widget.groundingContext ?? "General Context"}');
  }

  void _sendMessage(SumiProvider sumi) {
    final text = _controller.text.trim();
    if (text.isEmpty || sumi.isStreaming) return;

    HapticFeedback.lightImpact();
    sumi.askSumi(text, context: widget.groundingContext);
    _controller.clear();
    _scrollToBottom();
  }
}

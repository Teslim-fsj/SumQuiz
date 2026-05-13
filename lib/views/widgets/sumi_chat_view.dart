import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/cyber_neural_theme.dart';
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: CyberNeuralColors.cyan.withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.volume_up_rounded, size: 16, color: CyberNeuralColors.cyan),
          const SizedBox(width: 8),
          Text(
            'NEURAL LINK ACTIVE...',
            style: GoogleFonts.jetBrainsMono(color: CyberNeuralColors.cyan, fontWeight: FontWeight.bold, fontSize: 10),
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
              color: CyberNeuralColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: CyberNeuralColors.cyan.withValues(alpha: 0.1)),
            ),
            child: text.isEmpty 
              ? _buildTypingIndicator(theme)
              : Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: Colors.white),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "SUMI AI",
            style: GoogleFonts.jetBrainsMono(
              color: CyberNeuralColors.cyan,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
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
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
            color: CyberNeuralColors.cyan,
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
                        ? CyberNeuralColors.surfaceAlt
                        : CyberNeuralColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    border: Border.all(
                      color: isUser 
                        ? Colors.white.withValues(alpha: 0.05)
                        : CyberNeuralColors.cyan.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: Colors.white,
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
              isUser ? "USER" : "SUMI AI",
              style: GoogleFonts.jetBrainsMono(
                color: isUser ? Colors.white38 : CyberNeuralColors.cyan,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
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
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: CyberNeuralColors.background,
        border: Border(
            top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "NEURAL COMMAND...",
                hintStyle: GoogleFonts.jetBrainsMono(
                    color: Colors.white24, fontSize: 12),
                prefixIcon: IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: CyberNeuralColors.cyan,
                  onPressed: _pickFiles,
                  tooltip: 'Upload resources',
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.mic_none_rounded),
                  color: CyberNeuralColors.cyan,
                  onPressed: () => _startVoiceTutoring(sumi),
                  tooltip: 'Live voice tutoring',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                fillColor: CyberNeuralColors.surface,
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(sumi),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: () => _sendMessage(sumi),
            icon: sumi.isStreaming 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: CyberNeuralColors.cyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            backgroundColor: CyberNeuralColors.surface,
            content: Text(
              '${result.files.length} FILES LINKED TO NEURAL CORE',
              style: GoogleFonts.jetBrainsMono(color: CyberNeuralColors.cyan, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }
  }

  void _startVoiceTutoring(SumiProvider sumi) {
    context.push('/sumi-live?source=${widget.groundingContext ?? "Neural Core"}');
  }

  void _sendMessage(SumiProvider sumi) {
    final text = _controller.text.trim();
    if (text.isEmpty || sumi.isStreaming) return;

    sumi.askSumi(text, context: widget.groundingContext);
    _controller.clear();
    _scrollToBottom();
  }
}

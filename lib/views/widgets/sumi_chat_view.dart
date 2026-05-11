import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/sumi_provider.dart';
import '../../models/sumi_message.dart';
import '../../widgets/sumi_mascot.dart';
import '../../models/sumi_emotion.dart';

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
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.volume_up_rounded, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            'Sumi is speaking...',
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold),
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
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: text.isEmpty 
              ? _buildTypingIndicator(theme)
              : Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            "Sumi",
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 10,
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
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
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
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      if (isUser)
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: isUser
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
                top: 4, left: isUser ? 0 : 4, right: isUser ? 4 : 0),
            child: Text(
              isUser ? "You" : "Sumi",
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 10,
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
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
            top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Ask Sumi anything...",
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                prefixIcon: IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: theme.colorScheme.primary,
                  onPressed: _pickFiles,
                  tooltip: 'Upload resources',
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.mic_none_rounded),
                  color: theme.colorScheme.primary,
                  onPressed: () => _startVoiceTutoring(sumi),
                  tooltip: 'Live voice tutoring',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                fillColor:
                    theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
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
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
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
          SnackBar(content: Text('${result.files.length} files attached for study grounding')),
        );
      }
    }
  }

  void _startVoiceTutoring(SumiProvider sumi) {
    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => Consumer<SumiProvider>(
          builder: (context, sumi, _) => Container(
            height: 350,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (sumi.isProcessingVoice || sumi.isSumiSpeaking)
                  const SumiMascot(state: SumiState.thinking, size: 100)
                else
                  const SumiMascot(state: SumiState.idle, size: 100).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.seconds),
                const SizedBox(height: 24),
                Text(
                  sumi.isSumiSpeaking ? 'Sumi is speaking' : (sumi.isProcessingVoice ? 'Sumi is thinking' : (sumi.isVoiceRecording ? 'Sumi is listening' : 'Ready to talk?')),
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (sumi.isVoiceRecording)
                  Text(
                    _formatDuration(sumi.recordingDuration),
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.red),
                  )
                else if (sumi.isLiveSession)
                  const Text('Live Session Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                else
                  const Text('Speak clearly for the best help'),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!sumi.isLiveSession && !sumi.isProcessingVoice)
                      Column(
                        children: [
                            IconButton.filled(
                              onPressed: () => sumi.startVoiceRecording(),
                              icon: const Icon(Icons.mic, size: 32),
                              padding: const EdgeInsets.all(20),
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => sumi.startLiveSession(context: widget.groundingContext),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Start Live Session'),
                          ),
                        ],
                      )
                    else if (sumi.isLiveSession || sumi.isVoiceRecording)
                      IconButton.filled(
                        onPressed: () async {
                          if (sumi.isLiveSession) {
                            await sumi.stopLiveSession();
                          } else {
                            await sumi.stopVoiceRecording(context: widget.groundingContext);
                          }
                          if (!mounted) return;
                          if (!sumi.isLiveSession) Navigator.pop(context);
                        },
                        icon: Icon(sumi.isLiveSession ? Icons.stop_circle : Icons.stop, size: 32),
                        padding: const EdgeInsets.all(20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                      ),
                    const SizedBox(width: 20),
                    if (!sumi.isProcessingVoice && !sumi.isSumiSpeaking)
                      TextButton(
                        onPressed: () {
                          if (sumi.isLiveSession) sumi.stopLiveSession();
                          if (sumi.isVoiceRecording) sumi.stopVoiceRecording();
                          Navigator.pop(context);
                        },
                        child: const Text('Close'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  void _sendMessage(SumiProvider sumi) {
    final text = _controller.text.trim();
    if (text.isEmpty || sumi.isStreaming) return;

    sumi.askSumi(text, context: widget.groundingContext);
    _controller.clear();
    _scrollToBottom();
  }
}

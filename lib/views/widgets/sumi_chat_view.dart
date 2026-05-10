import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/sumi_provider.dart';
import '../../models/sumi_message.dart';
import '../../widgets/sumi_mascot.dart';
import '../../models/sumi_emotion.dart';

class SumiChatView extends StatefulWidget {
  const SumiChatView({super.key});

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sumiProvider = context.watch<SumiProvider>();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: sumiProvider.messages.length,
            itemBuilder: (context, index) {
              final message = sumiProvider.messages[index];
              return _buildMessageBubble(theme, message);
            },
          ),
        ),
        _buildInputArea(theme, sumiProvider),
      ],
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
              if (!isUser) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const SumiMascot(
                      state: SumiState.idle, size: 24, showBubble: false),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.4),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      if (isUser)
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.2),
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
              if (isUser) ...[
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Icon(Icons.person,
                      size: 18, color: theme.colorScheme.onSecondaryContainer),
                ),
              ],
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
                top: 4, left: isUser ? 0 : 54, right: isUser ? 54 : 0),
            child: Text(
              isUser ? "You" : "Sumi",
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
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
            top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Ask Sumi anything...",
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                fillColor:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(sumi),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: () => _sendMessage(sumi),
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(SumiProvider sumi) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    sumi.addMessage(text, MessageRole.user);
    _controller.clear();
    _scrollToBottom();

    // Mock AI Response
    Future.delayed(const Duration(seconds: 1), () {
      sumi.addMessage(
          "Thinking about that... I'm integrating your question into our current study context.",
          MessageRole.sumi);
      _scrollToBottom();
    });
  }
}

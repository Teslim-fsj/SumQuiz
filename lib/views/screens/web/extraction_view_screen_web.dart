import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/services/notification_integration.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/models/extraction_result.dart';

class ExtractionViewScreenWeb extends StatefulWidget {
  final ExtractionResult? result;

  const ExtractionViewScreenWeb({super.key, this.result});

  @override
  State<ExtractionViewScreenWeb> createState() =>
      _ExtractionViewScreenWebState();
}

enum OutputType { summary, quiz, flashcards }

class _ExtractionViewScreenWebState extends State<ExtractionViewScreenWeb> {
  late TextEditingController _textController;
  late TextEditingController _titleController;
  final Set<OutputType> _selectedOutputs = {
    OutputType.summary,
    OutputType.quiz,
    OutputType.flashcards
  };
  bool _isLoading = false;
  String _loadingMessage = 'Generating...';

  static const int minTextLength = 10;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.result?.text ?? '');
    _titleController = TextEditingController(
        text: widget.result?.suggestedTitle ?? 'Untitled Creation');

    // Guard against null or empty extraction results
    if (widget.result == null || (widget.result!.text.trim().isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No content was extracted. Please try again with a different source.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
          if (context.canPop()) {
            context.pop();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _toggleOutput(OutputType type) {
    setState(() {
      if (_selectedOutputs.contains(type)) {
        _selectedOutputs.remove(type);
      } else {
        _selectedOutputs.add(type);
      }
    });
  }

  Future<void> _handleGenerate() async {
    if (_textController.text.trim().length < minTextLength) {
      _showError(
          'Text is too short. Please provide at least $minTextLength characters.');
      return;
    }

    if (_selectedOutputs.isEmpty) {
      _showError('Please select at least one output type.');
      return;
    }

    final user = context.read<UserModel?>();
    final aiService = context.read<EnhancedAIService>();
    final localDb = context.read<LocalDatabaseService>();
    final authService = context.read<AuthService>();

    if (user != null) {
      final usageService = UsageService();
      if (!await usageService.canGenerateDeck(user.uid)) {
        if (mounted) {
          showDialog(
              context: context,
              builder: (_) => const UpgradeDialog(featureName: 'Daily Limit'));
        }
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Preparing generation...';
    });

    try {
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User is not logged in');
      }

      final userId = currentUser.uid;
      final requestedOutputs = _selectedOutputs.map((e) => e.name).toList();

      final folderId = await aiService.generateAndStoreOutputs(
        text: _textController.text,
        title: _titleController.text.isNotEmpty
            ? _titleController.text
            : 'Untitled Creation',
        requestedOutputs: requestedOutputs,
        userId: userId,
        localDb: localDb,
        onProgress: (message) {
          if (mounted) {
            setState(() => _loadingMessage = message);
          }
        },
      );

      if (user != null) {
        await UsageService().recordAction(user.uid, 'generate');
      }

      // 🔔 Schedule notifications after content generation
      if (mounted) {
        try {
          await NotificationIntegration.onContentGenerated(
            context,
            userId,
            _titleController.text.isNotEmpty
                ? _titleController.text
                : 'Untitled Creation',
          );
        } catch (e) {
          debugPrint('Failed to schedule notifications: $e');
        }
      }

      if (mounted) {
        context
            .pushNamed('results-view', pathParameters: {'folderId': folderId});
      }
    } catch (e) {
      if (mounted) _showError('Generation failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Editor
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.tertiary
                                      ]),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.edit_note,
                                        color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Source Content",
                                          style: GoogleFonts.outfit(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.color,
                                          ),
                                        ),
                                        Text(
                                          "Review and edit your content before generating",
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: TextField(
                                  controller: _textController,
                                  maxLines: null,
                                  expands: true,
                                  style: GoogleFonts.outfit(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                    fontSize: 16,
                                    height: 1.7,
                                  ),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.all(20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: theme.colorScheme.outline
                                              .withValues(alpha: 0.2),
                                          width: 1.5),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: theme.colorScheme.outline
                                              .withValues(alpha: 0.2),
                                          width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: theme.colorScheme.primary,
                                          width: 2),
                                    ),
                                    hintText:
                                        "Edit your content here... The AI will process this text to generate summaries, quizzes, and flashcards",
                                    hintStyle: GoogleFonts.outfit(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().slideX(begin: -0.05).fadeIn(),

                    const SizedBox(width: 32),

                    // Right: Configuration
                    SizedBox(
                      width: 380,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Configuration",
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Customize your learning materials",
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Title Section
                            Text(
                              "TITLE",
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.color
                                    ?.withValues(alpha: 0.5),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _titleController,
                              style: GoogleFonts.outfit(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color,
                                  fontSize: 16),
                              decoration: InputDecoration(
                                hintText: "Enter a title for your content...",
                                hintStyle: GoogleFonts.outfit(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Theme.of(context).dividerColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Theme.of(context).dividerColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Output types section
                            Text(
                              "OUTPUT TYPES",
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.color
                                    ?.withValues(alpha: 0.5),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...OutputType.values.map((type) {
                              final isSelected =
                                  _selectedOutputs.contains(type);
                              final gradients = {
                                OutputType.summary: const LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF8B5CF6)
                                  ],
                                ),
                                OutputType.quiz: const LinearGradient(
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF06B6D4)
                                  ],
                                ),
                                OutputType.flashcards: const LinearGradient(
                                  colors: [
                                    Color(0xFFEC4899),
                                    Color(0xFFF97316)
                                  ],
                                ),
                              };
                              final icons = {
                                OutputType.summary: Icons.article_outlined,
                                OutputType.quiz: Icons.quiz_outlined,
                                OutputType.flashcards: Icons.style_outlined,
                              };

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTap: () => _toggleOutput(type),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient:
                                          isSelected ? gradients[type] : null,
                                      color: !isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.3)
                                          : null,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.transparent
                                            : Theme.of(context).dividerColor,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: gradients[type]!
                                                    .colors
                                                    .first
                                                    .withOpacity(0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          icons[type],
                                          color: isSelected
                                              ? Colors.white
                                              : Theme.of(context)
                                                  .iconTheme
                                                  .color
                                                  ?.withValues(alpha: 0.7),
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            type.name.toUpperCase(),
                                            style: GoogleFonts.outfit(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.color,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: 32),

                            // Confidence indicator
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Theme.of(context).dividerColor),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.shield_outlined,
                                        color: theme.colorScheme.primary,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'AI Confidence',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.color,
                                          ),
                                        ),
                                        Text(
                                          'High confidence in content quality',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            // Generate button
                            if (_isLoading)
                              _buildLoadingIndicator()
                            else
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.tertiary
                                  ]),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _handleGenerate,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 20),
                                    minimumSize: const Size(double.infinity, 0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.auto_awesome,
                                          color: Colors.white),
                                      const SizedBox(width: 12),
                                      Text(
                                        'GENERATE CONTENT',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ).animate().slideX(begin: 0.05).fadeIn(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back,
                color: Theme.of(context).iconTheme.color),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review & Generate',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).textTheme.headlineMedium?.color,
                  ),
                ),
                Text(
                  'Refine your content before AI processing',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'AI Ready',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: theme.colorScheme.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _loadingMessage,
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Processing with AI...',
            style: GoogleFonts.outfit(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              setState(() => _isLoading = false);
            },
            icon: const Icon(Icons.close, color: Colors.redAccent),
            label: const Text(
              'Cancel',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

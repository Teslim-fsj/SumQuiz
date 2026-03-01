import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/services/notification_integration.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class ExtractionViewScreen extends StatefulWidget {
  final ExtractionResult? result;

  const ExtractionViewScreen({super.key, this.result});

  @override
  State<ExtractionViewScreen> createState() => _ExtractionViewScreenState();
}

enum OutputType {
  summary,
  quiz,
  flashcards,
}

class _ExtractionViewScreenState extends State<ExtractionViewScreen> {
  late TextEditingController _textController;
  late TextEditingController _titleController;
  final Set<OutputType> _selectedOutputs =
      {}; // Default to none, allow multi-select
  bool _isLoading = false;
  String _loadingMessage = 'Generating...';
  bool _isEditingTitle = false;
  CancellationToken? _cancelToken;

  // Minimum character count validation - 50 chars for better AI quality
  static const int minTextLength = 50;

  @override
  void initState() {
    super.initState();

    try {
      // Null check comes first, before any debugPrint statements that access widget.result!
      if (widget.result == null ||
          widget.result!.text.trim().isEmpty ||
          widget.result!.text.startsWith('[')) {
        _textController = TextEditingController(text: '');
        _titleController = TextEditingController(text: 'Untitled Creation');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Could not extract content. Please try a different source.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            if (context.canPop()) context.pop();
          }
        });
        return;
      }

      debugPrint('ExtractionViewScreen.initState called');
      debugPrint('Widget result: ${widget.result != null ? "exists" : "null"}');
      if (widget.result != null) {
        debugPrint('Result text length: ${widget.result!.text.length}');
        debugPrint(
            'Result text preview: ${widget.result!.text.substring(0, (widget.result!.text.length > 50) ? 50 : widget.result!.text.length)}...');
        debugPrint('Suggested title: ${widget.result?.suggestedTitle}');
      }

      final rawText = widget.result?.text ?? '';

      debugPrint('Processing valid extraction result');

      // Heuristic normalization:
      // If text appears to be "one word per line" (many short lines), join them.
      String normalizedText = rawText.trim();

      // Count lines and average line length
      final lines = normalizedText.split('\n');
      if (lines.length > 10) {
        double totalLength = 0;
        for (var l in lines) {
          totalLength += l.trim().length;
        }
        double avgLength = totalLength / lines.length;

        // If average line length is very short (< 20 chars), it's likely broken layout
        if (avgLength < 20) {
          // Join lines with space, but preserve double newlines (paragraphs)
          normalizedText = normalizedText
              .replaceAll(
                  RegExp(r'(?<!\n)\n(?!\n)'), ' ') // Join single newlines
              .replaceAll(RegExp(r' +'), ' ') // Normalize spaces
              .replaceAll(
                  RegExp(r'\n{3,}'), '\n\n'); // Normalize paragraph breaks
        } else {
          // Just normalize excessive spacing
          normalizedText = normalizedText.replaceAll(RegExp(r'\n{3,}'), '\n\n');
        }
      } else {
        normalizedText = normalizedText.replaceAll(RegExp(r'\n{3,}'), '\n\n');
      }

      _textController = TextEditingController(text: normalizedText);
      _titleController = TextEditingController(
          text: widget.result?.suggestedTitle ?? 'Untitled Creation');
      _selectedOutputs.add(OutputType.summary); // Select Summary by default

      debugPrint('ExtractionViewScreen initState completed');
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: true);
      rethrow;
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _toggleOutput(OutputType type) {
    // All output types now available to all users within their limits
    // The limit check happens in _handleGenerate()
    setState(() {
      if (_selectedOutputs.contains(type)) {
        _selectedOutputs.remove(type);
      } else {
        _selectedOutputs.add(type);
      }
    });
  }

  /// Check if API key is properly configured before processing
  Future<bool> _isApiKeyConfigured() async {
    try {
      final service = context.read<EnhancedAIService>();
      debugPrint('API key check: EnhancedAIService accessed successfully');
      // Test the service health
      final isHealthy = await service.isServiceHealthy();
      if (!isHealthy) {
        debugPrint('AI service is not healthy');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('API key check failed: $e');
      return false;
    }
  }

  Future<void> _handleGenerate() async {
    // Check if API key is configured
    if (!await _isApiKeyConfigured()) {
      _showError(
          '🔑 API key is not configured. Please set up your API key in the .env file.');
      return;
    }

    if (_textController.text.trim().length < minTextLength) {
      _showError(
          'The text is too short. Please provide at least $minTextLength characters to ensure high-quality content generation.');
      return;
    }

    if (_selectedOutputs.isEmpty) {
      _showError(
          'Please select at least one output type to generate (Summary, Quiz, or Flashcards).');
      return;
    }

    // Obtain services before any async await to avoid lint warnings
    final aiService = context.read<EnhancedAIService>();
    final localDb = context.read<LocalDatabaseService>();
    final authService = context.read<AuthService>();

    final user = context.read<UserModel?>();

    // Check usage limits for all users (Freemium & Pro caps)
    if (user != null) {
      final usageService = UsageService();
      final canProceed = await usageService.canGenerateDeck(user.uid);
      if (!mounted) return;
      if (!canProceed) {
        _showUpgradeDialog('Daily Limit');
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
        debugPrint('User is not logged in');
        if (mounted) {
          _showError('User is not logged in. Please sign in to continue.');
        }
        return;
      }

      final userId = currentUser.uid;
      debugPrint('Current user ID: $userId');

      final requestedOutputs = _selectedOutputs.map((e) => e.name).toList();
      debugPrint('Requested outputs: $requestedOutputs');

      // Add validation for requested outputs
      if (requestedOutputs.isEmpty) {
        debugPrint('No output types selected');
        if (mounted) {
          _showError('Please select at least one output type to generate.');
        }
        return;
      }

      _cancelToken = CancellationToken();

      String? folderId;
      try {
        folderId = await aiService.generateAndStoreOutputs(
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
          cancelToken: _cancelToken,
        );
      } catch (e, stack) {
        debugPrint('Error generating content: $e');
        debugPrint('Stack trace: $stack');
        if (mounted) {
          _showError(
              'Error generating content: ${e.toString().split(':').first}');
        }
        return;
      }

      // Record usage (Deck Generation)
      if (user != null) {
        try {
          await UsageService().recordDeckGeneration(user.uid);
        } catch (e) {
          debugPrint('Error recording deck generation: $e');
          // Don't fail the operation if usage recording fails
        }
      }
      if (!mounted) return;

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
        } catch (e, stack) {
          // Don't block navigation if notification scheduling fails
          debugPrint('Failed to schedule notifications: $e');
          debugPrint('Notification error stack: $stack');
        }
      }

      if (mounted) {
        debugPrint('Navigation to results-view with folderId: $folderId');
        // Navigate to the results screen, which shows what was just created
        try {
          context.go('/library/results-view/$folderId');
        } catch (e, stack) {
          debugPrint('Navigation error: $e');
          debugPrint('Navigation error stack: $stack');
          // Show error but don't crash
          _showError('Navigation failed: $e');
        }
      }
    } on EnhancedAIServiceException catch (e) {
      debugPrint('EnhancedAIServiceException: ${e.message}');
      debugPrint('Error code: ${e.code}');

      if (mounted) {
        String errorMsg = 'AI Processing Error: ${e.message}';

        // Check for specific error types
        if (e.message.contains('API') || e.message.contains('key')) {
          errorMsg =
              'API configuration error. Please check your API key in the .env file.';
        } else if (e.message.contains('disabled') ||
            e.message.contains('stability')) {
          errorMsg =
              'File processing is temporarily disabled. Try pasting text directly.';
        } else if (e.message.contains('NOT_FOUND')) {
          errorMsg = 'AI model not found. Please check your API configuration.';
        } else if (e.message.contains('No content') ||
            e.message.contains('empty')) {
          errorMsg =
              'No content was provided. Please check the text and try again.';
        }

        _showError(errorMsg);
      }
    } catch (e, stackTrace) {
      // Log the actual error for debugging
      debugPrint('Error generating content: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        String errorMsg = 'Failed to generate content.';
        if (e.toString().contains('quota') || e.toString().contains('limit')) {
          errorMsg =
              'AI usage limit exceeded. Please try again later or upgrade to Pro.';
        } else if (e.toString().contains('internet') ||
            e.toString().contains('network')) {
          errorMsg =
              'Network error. Please check your internet connection and try again.';
        } else if (e.toString().contains('API') ||
            e.toString().contains('key')) {
          errorMsg =
              'API configuration error. Please check your API key in the .env file.';
        } else if (e.toString().contains('No content') ||
            e.toString().contains('empty')) {
          errorMsg =
              'No content was provided. Please check the text and try again.';
        } else {
          // Provide more user-friendly error message
          if (e is TypeError) {
            errorMsg =
                'Content processing error. Please try again with different content.';
          } else {
            errorMsg =
                'Failed to generate content: ${e.toString().split(':').first}';
          }
        }
        _showError(errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showUpgradeDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => UpgradeDialog(featureName: feature),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: _isEditingTitle
            ? _buildTitleEditor(theme)
            : Text(_titleController.text,
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
                overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Edit Title',
            icon: Icon(_isEditingTitle ? Icons.check : Icons.edit_outlined,
                color: theme.colorScheme.onSurface, size: 22),
            onPressed: () => setState(() => _isEditingTitle = !_isEditingTitle),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated Gradient Background
          Animate(
            onPlay: (controller) => controller.repeat(reverse: true),
            effects: [
              CustomEffect(
                duration: 10.seconds,
                builder: (context, value, child) {
                  final colorOpacity = isDark ? 0.3 : 0.15;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                theme.colorScheme.surface,
                                theme.colorScheme.primaryContainer
                                    .withValues(alpha: colorOpacity),
                              ]
                            : [
                                const Color(0xFFE3F2FD),
                                const Color(0xFFBBDEFB).withValues(alpha: 0.5),
                              ],
                      ),
                    ),
                    child: child,
                  );
                },
              )
            ],
            child: Container(),
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 100), // Space for FAB
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Usage Banner for free users
                  _buildUsageBanner(theme),
                  Text('1. Choose content to create:',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface))
                      .animate()
                      .fadeIn()
                      .slideX(),
                  const SizedBox(height: 12),
                  _buildOutputSelector(theme).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 24),
                  Text('2. Review your text:',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface))
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .slideX(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildDocumentDisplayArea(theme)
                        .animate()
                        .fadeIn(delay: 300.ms)
                        .scale(begin: const Offset(0.95, 0.95)),
                  ),
                ],
              ),
            ),
          ),
          if (!_isLoading)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildGenerateButton(theme)
                  .animate()
                  .fadeIn(delay: 400.ms)
                  .slideY(begin: 0.2),
            ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withValues(alpha: 0.9),
                        border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: theme.colorScheme.primary),
                          const SizedBox(height: 24),
                          Text(
                            _loadingMessage,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: theme.colorScheme.onSurface),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          TextButton.icon(
                            onPressed: () {
                              _cancelToken?.cancel();
                              setState(() => _isLoading = false);
                            },
                            icon: Icon(Icons.close, color: Colors.redAccent),
                            label: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleEditor(ThemeData theme) {
    return TextField(
      controller: _titleController,
      autofocus: true,
      style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
      cursorColor: theme.colorScheme.primary,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: 'Enter a title...',
        hintStyle: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      ),
      onSubmitted: (_) => setState(() => _isEditingTitle = false),
    );
  }

  Widget _buildOutputSelector(ThemeData theme) {
    return Wrap(
      spacing: 12.0,
      runSpacing: 8.0,
      children: OutputType.values.map((type) {
        final isSelected = _selectedOutputs.contains(type);
        return GestureDetector(
          onTap: () => _toggleOutput(type),
          child: AnimatedContainer(
            duration: 200.ms,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.2)
                  : theme.cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.dividerColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  StringExtension(type.name).capitalize(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                ]
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDocumentDisplayArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: TextField(
        readOnly: false, // Always editable
        controller: _textController,
        maxLines: null,
        expands: true,
        style: theme.textTheme.bodyMedium
            ?.copyWith(height: 1.5, color: theme.colorScheme.onSurface),
        cursorColor: theme.colorScheme.primary,
        decoration: InputDecoration.collapsed(
          hintText:
              'Your extracted or pasted text appears here. You can edit it before generating.',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
      ),
    );
  }

  Widget _buildGenerateButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: _handleGenerate,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.onPrimary),
              const SizedBox(width: 12),
              Text('Generate Content',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  /// Usage banner showing remaining generations for free users
  Widget _buildUsageBanner(ThemeData theme) {
    final user = context.watch<UserModel?>();

    // Don't show for Pro users
    if (user == null || user.isPro) {
      return const SizedBox.shrink();
    }

    // Calculate usage
    final now = DateTime.now();
    final lastGen = user.lastDeckGenerationDate;
    final isNewDay = lastGen == null ||
        now.year != lastGen.year ||
        now.month != lastGen.month ||
        now.day != lastGen.day;

    final used = isNewDay ? 0 : user.dailyDecksGenerated;
    final limit = 2; // Free tier daily limit
    final remaining = limit - used;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: remaining > 0
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: remaining > 0
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            remaining > 0 ? Icons.info_outline : Icons.warning_amber_rounded,
            color:
                remaining > 0 ? theme.colorScheme.primary : Colors.orange[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              remaining > 0
                  ? 'Free Plan: $used/$limit today'
                  : 'Daily limit reached',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/subscription'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Upgrade',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }
}

// A simple extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

import 'dart:developer' as developer;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../services/local_database_service.dart';
import '../../services/enhanced_ai_service.dart';
import '../../services/usage_service.dart';
import 'package:collection/collection.dart';
import '../widgets/upgrade_dialog.dart';
import '../../models/public_deck.dart';
import '../../services/firestore_service.dart';
import '../../services/mastery_service.dart';
import '../../services/export_service.dart';
import '../../services/notification_integration.dart';

enum ScreenState { initial, loading, error, success }

class SummaryScreen extends StatefulWidget {
  final LocalSummary? summary;
  final String? id;

  const SummaryScreen({super.key, this.summary, this.id});

  @override
  SummaryScreenState createState() => SummaryScreenState();
}

class SummaryScreenState extends State<SummaryScreen> {
  final TextEditingController _textController = TextEditingController();
  String? _pdfFileName;
  ScreenState _state = ScreenState.initial;
  String _summaryContent = '';
  String _summaryTitle = '';
  List<String> _summaryTags = [];
  String _errorMessage = '';
  String _loadingMessage = 'Generating Summary...';
  bool _isGeneratingQuiz = false;

  late final EnhancedAIService _aiService;
  late final LocalDatabaseService _localDbService;

  @override
  void initState() {
    super.initState();
    _localDbService = LocalDatabaseService();
    _localDbService.init();
    _aiService = EnhancedAIService(
        iapService: Provider.of<IAPService>(context, listen: false),
        localDb: _localDbService);
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    if (widget.summary != null) {
      _summaryContent = widget.summary!.content;
      _summaryTitle = widget.summary!.title;
      _summaryTags = widget.summary!.tags;
      _state = ScreenState.success;

      final user = Provider.of<UserModel?>(context, listen: false);
      if (user != null && widget.summary!.topicIds.isNotEmpty) {
        final mastery = Provider.of<MasteryService>(context, listen: false);
        for (final topicId in widget.summary!.topicIds) {
          mastery.processSignal(LearningSignal(
            topicId: topicId,
            type: SignalType.summaryRead,
            timestamp: DateTime.now(),
            metadata: {'context': 'summary_view', 'userId': user.uid},
          ));
        }
      }
    } else if (widget.id != null) {
      setState(() {
        _state = ScreenState.loading;
        _loadingMessage = 'Loading Summary...';
      });

      try {
        LocalSummary? summary = await _localDbService.getSummary(widget.id!);
        if (summary == null && mounted) {
          final user = Provider.of<UserModel?>(context, listen: false);
          if (user != null) {
            final firestore = FirestoreService();
            final fsDoc = await firestore.getSummary(user.uid, widget.id!);
            if (fsDoc != null) {
              summary = LocalSummary(
                id: fsDoc.id,
                title: fsDoc.title,
                content: fsDoc.content,
                timestamp: fsDoc.timestamp.toDate(),
                userId: user.uid,
              );
              await _localDbService.saveSummary(summary);
            }
          }
        }

        if (summary != null && mounted) {
          final s = summary;
          setState(() {
            _summaryContent = s.content;
            _summaryTitle = s.title;
            _summaryTags = s.tags;
            _state = ScreenState.success;
          });

          final user = Provider.of<UserModel?>(context, listen: false);
          if (user != null && s.topicIds.isNotEmpty) {
            final mastery = Provider.of<MasteryService>(context, listen: false);
            for (final topicId in s.topicIds) {
              mastery.processSignal(LearningSignal(
                topicId: topicId,
                type: SignalType.summaryRead,
                timestamp: DateTime.now(),
                metadata: {'context': 'summary_view', 'userId': user.uid},
              ));
            }
          }
        } else if (mounted) {
          setState(() {
            _state = ScreenState.error;
            _errorMessage = 'Summary not found.';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _state = ScreenState.error;
            _errorMessage = 'Error loading summary: $e';
          });
        }
      }
    }
  }

  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _pdfFileName = result.files.single.name;
        });
      }
    } catch (e, s) {
      developer.log('Error picking or reading PDF',
          name: 'summary.screen', error: e, stackTrace: s);
      setState(() {
        _state = ScreenState.error;
        _errorMessage = "Error picking or reading PDF: $e";
      });
    }
  }

  void _generateSummary() async {
    final userModel = Provider.of<UserModel?>(context, listen: false);
    final usageService = Provider.of<UsageService?>(context, listen: false);
    if (!mounted || userModel == null || usageService == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('User not available. Please log in again.')));
      return;
    }

    if (!userModel.isPro &&
        !(await usageService.canPerformAction(userModel.uid, 'summaries'))) {
      if (mounted) {
        await NotificationIntegration.onUsageLimitHit(context);
        if (mounted) {
          showDialog(
              context: context,
              builder: (context) =>
                  const UpgradeDialog(featureName: 'summaries'));
        }
      }
      return;
    }

    setState(() {
      _state = ScreenState.loading;
      _loadingMessage = 'Generating summary...';
    });

    try {
      final folderId = await _aiService.generateAndStoreOutputs(
        text: _textController.text,
        title: _summaryTitle.isNotEmpty ? _summaryTitle : 'Summary',
        requestedOutputs: ['summary'],
        userId: userModel.uid,
        localDb: _localDbService,
        onProgress: (message) {
          setState(() {
            _loadingMessage = message;
          });
        },
      );

      final content = await _localDbService.getFolderContents(folderId);

      if (content.isNotEmpty) {
        if (!userModel.isPro) {
          await usageService.recordAction(userModel.uid, 'summaries');
        }
        if (!mounted) return;
        await NotificationIntegration.onContentGenerated(
            context, userModel.uid, _summaryTitle);
        if (!mounted) return;
        context.go('/library/results-view/$folderId');
      } else {
        throw Exception('Failed to retrieve the generated summary.');
      }
    } catch (e, s) {
      developer.log('An unexpected error occurred during summary generation',
          name: 'summary.screen', error: e, stackTrace: s);
      setState(() {
        _state = ScreenState.error;
        _errorMessage = "An unexpected error occurred. Please try again.";
      });
    }
  }

  void _retry() => setState(() {
        _state = ScreenState.initial;
        _summaryContent = _summaryTitle = _errorMessage = '';
        _summaryTags = [];
        _textController.clear();
        _pdfFileName = null;
      });

  void _copySummary() {
    Clipboard.setData(ClipboardData(text: _summaryContent));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary content copied to clipboard!')));
  }

  void _saveToLibrary() async {
    final user = context.read<UserModel?>();
    if (user == null) return;

    try {
      final summaryToSave = LocalSummary(
        id: const Uuid().v4(),
        userId: user.uid,
        title: _summaryTitle,
        content: _summaryContent,
        tags: _summaryTags,
        timestamp: DateTime.now(),
        isSynced: false,
      );
      await _localDbService.saveSummary(summaryToSave);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Summary saved to library!')));
    } catch (e, s) {
      developer.log('Error saving summary',
          name: 'summary.screen', error: e, stackTrace: s);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error saving summary.')));
    }
  }

  Future<void> _publishDeck() async {
    final user = context.read<UserModel?>();
    if (user == null) return;

    setState(() => _loadingMessage = 'Publishing Deck...');

    final quizzes = await _localDbService.getAllQuizzes(user.uid);
    final relatedQuiz =
        quizzes.where((q) => q.title == _summaryTitle).firstOrNull;

    final flashcards = await _localDbService.getAllFlashcardSets(user.uid);
    final relatedFlashcards =
        flashcards.where((fs) => fs.title == _summaryTitle).firstOrNull;

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Publish Deck', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: $_summaryTitle', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text('Includes:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            _buildIncludedItem('Summary', true),
            _buildIncludedItem('Quiz', relatedQuiz != null),
            _buildIncludedItem('Flashcards', relatedFlashcards != null),
            const SizedBox(height: 16),
            Text('This will make the deck public and shareable.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
              child: Text('Publish', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final summaryData = {
        'title': _summaryTitle,
        'content': _summaryContent,
        'tags': _summaryTags,
      };

      Map<String, dynamic> quizData = {};
      if (relatedQuiz != null) {
        quizData = {
          'title': relatedQuiz.title,
          'questions': relatedQuiz.questions
              .map((q) => {
                    'question': q.question,
                    'options': q.options,
                    'correctAnswer': q.correctAnswer,
                  })
              .toList(),
        };
      }

      Map<String, dynamic> flashcardData = {};
      if (relatedFlashcards != null) {
        flashcardData = {
          'title': relatedFlashcards.title,
          'flashcards': relatedFlashcards.flashcards
              .map((f) => {
                    'question': f.question,
                    'answer': f.answer,
                  })
              .toList(),
        };
      }

      final shareCode = const Uuid().v4().substring(0, 6).toUpperCase();

      final publicDeck = PublicDeck(
        id: '',
        creatorId: user.uid,
        creatorName: user.displayName,
        title: _summaryTitle,
        description: 'Created by ${user.displayName}',
        shareCode: shareCode,
        summaryData: summaryData,
        quizData: quizData,
        flashcardData: flashcardData,
        noteData: {},
        publishedAt: DateTime.now(),
      );

      final firestoreService = FirestoreService();
      final published = await firestoreService.publishDeck(publicDeck);
      final deckId = published.id;

      if (!mounted) return;

      final shareUrl = 'https://sumquiz.xyz/deck?id=$deckId';

      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: Text('Published Successfully!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF0D9488), size: 64),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: SelectableText(shareUrl,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0D9488), fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    Text('Share Code', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    SelectableText(shareCode,
                        style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: const Color(0xFF0D9488))),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text: 'Code: $shareCode\nLink: $shareUrl'));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Details Copied!')));
                      },
                      child: Text('Copy Details', style: GoogleFonts.inter())),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                ],
              ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error publishing: $e')));
      }
    }
  }

  Widget _buildIncludedItem(String label, bool isIncluded) {
    return Row(
      children: [
        Icon(isIncluded ? Icons.check_circle_rounded : Icons.cancel_rounded, 
             size: 14, 
             color: isIncluded ? const Color(0xFF0D9488) : Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: isIncluded ? Colors.black : Colors.grey)),
      ],
    );
  }

  Future<void> _generateQuiz() async {
    setState(() => _isGeneratingQuiz = true);
    try {
      final user = context.read<UserModel?>();
      if (user == null || _summaryContent.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No summary content available to generate quiz.')));
        }
        return;
      }
      if (!mounted) return;
      context.push('/create-content', extra: {
        'initialText': _summaryContent,
        'initialTitle': _summaryTitle,
        'mode': 'quiz'
      });
    } catch (e, s) {
      developer.log('Error navigating to quiz generation',
          name: 'summary.screen', error: e, stackTrace: s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start quiz generation: $e')));
    } finally {
      if (mounted) setState(() => _isGeneratingQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.summary == null ? 'New Synthesis' : 'Summary',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: const Color(0xFF0D9488))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          Consumer<UserModel?>(
            builder: (context, user, _) {
              if (user != null && _state == ScreenState.success) {
                final isStudent = user.role == UserRole.student;
                return IconButton(
                  icon: Icon(isStudent ? Icons.share_rounded : Icons.public_rounded),
                  tooltip: isStudent ? 'Share with Friends' : 'Publish Deck',
                  onPressed: _publishDeck,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (_state) {
      case ScreenState.loading:
        return _buildLoadingState(theme);
      case ScreenState.error:
        return _buildErrorState(theme);
      case ScreenState.success:
        return _buildSuccessState(theme);
      default:
        return _buildInitialState(theme);
    }
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
            ),
          ),
          const SizedBox(height: 24),
          Text(_loadingMessage,
              style: GoogleFonts.inter(
                  color: theme.hintColor, fontWeight: FontWeight.w500)),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildInitialState(ThemeData theme) {
    final canGenerate = _textController.text.isNotEmpty || _pdfFileName != null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Knowledge Synthesis',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary),
              ).animate().fadeIn().slideY(begin: -0.1),
              const SizedBox(height: 8),
              Text(
                'Transform your source material into a concise summary.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: theme.hintColor),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: 12,
                  style: GoogleFonts.inter(fontSize: 15, height: 1.6),
                  decoration: InputDecoration(
                    hintText: 'Paste your insights or research notes here...',
                    hintStyle: GoogleFonts.inter(color: theme.hintColor.withOpacity(0.5)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(24),
                  ),
                  onChanged: (text) => setState(() {}),
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickPdf,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _pdfFileName != null ? const Color(0xFF0D9488).withOpacity(0.05) : theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _pdfFileName != null ? const Color(0xFF0D9488) : theme.dividerColor.withOpacity(0.1),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_rounded, size: 20, color: _pdfFileName != null ? const Color(0xFF0D9488) : theme.hintColor),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                _pdfFileName ?? 'Upload PDF Source',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _pdfFileName != null ? const Color(0xFF0D9488) : theme.hintColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_pdfFileName != null) ...[
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                        onPressed: () => setState(() => _pdfFileName = null),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        style: IconButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.1), foregroundColor: Colors.redAccent),
                    )
                  ]
                ],
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: canGenerate ? _generateSummary : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text('Synthesize Knowledge', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms).scale(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 24),
            Text('Synthesis Interrupted',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(_errorMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: theme.hintColor)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _retry,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Try Again', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildSuccessState(ThemeData theme) {
    if (_summaryTitle.isEmpty && _summaryContent.isEmpty) {
      return Center(
          child: Text('No synthesis available',
              style: GoogleFonts.inter(color: theme.hintColor)));
    }

    final isViewingSaved = widget.summary != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _summaryTitle,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.displayLarge?.color,
                ),
              ).animate().fadeIn().slideY(begin: -0.1),
              const SizedBox(height: 16),
              if (_summaryTags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _summaryTags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#$tag',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF0D9488),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 32),
              
              // Content Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: MarkdownBody(
                  data: _summaryContent,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.inter(fontSize: 15, height: 1.7, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8)),
                    h1: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, height: 2),
                    h2: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, height: 1.8),
                    h3: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, height: 1.6),
                    listBullet: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF0D9488)),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms),
              
              const SizedBox(height: 32),
              
              // Action Row
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      onTap: _copySummary,
                      theme: theme,
                    ),
                  ),
                  if (!isViewingSaved) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.bookmark_add_rounded,
                        label: 'Save',
                        onTap: _saveToLibrary,
                        theme: theme,
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingQuiz ? null : _generateQuiz,
                      icon: _isGeneratingQuiz
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.quiz_rounded, size: 18),
                      label: Text('Practice Quiz', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, required ThemeData theme}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: theme.hintColor),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: theme.hintColor)),
          ],
        ),
      ),
    );
  }
}

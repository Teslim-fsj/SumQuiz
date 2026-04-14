import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:sumquiz/services/exam_pdf_generator.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:sumquiz/utils/share_code_generator.dart';
import 'package:sumquiz/utils/youtube_pro_gate.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';

import '../../widgets/create_content/web_exam_setup_step.dart';
import '../../widgets/create_content/web_exam_config_step.dart';
import '../../widgets/create_content/web_exam_review_step.dart';

class ExamCreationScreenWeb extends StatefulWidget {
  const ExamCreationScreenWeb({super.key});

  @override
  State<ExamCreationScreenWeb> createState() => _ExamCreationScreenWebState();
}

class _ExamCreationScreenWebState extends State<ExamCreationScreenWeb> {
  // Wizard State
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // controllers
  final _schoolNameController = TextEditingController(text: 'SUMQUIZ ACADEMY');
  final _subjectController = TextEditingController();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '60');

  // state variables
  String _selectedLevel = 'High School / Secondary';
  int _numberOfQuestions = 20;
  double _easyRatio = 0.3;
  double _hardRatio = 0.2;
  bool _includeMultipleChoice = true;
  bool _includeShortAnswer = false;
  bool _includeTheory = false;
  bool _includeTrueFalse = false;
  bool _evenTopicCoverage = true;
  bool _focusWeakAreas = false;

  String _sourceMaterial = '';
  final List<String> _processedFileNames = [];
  bool _isProcessingSource = false;
  bool _isGeneratingQuestions = false;
  String _processingMessage = '';
  bool _showPreview = false;
  CancellationToken? _cancelToken;

  List<LocalQuizQuestion> _generatedQuestions = [];

  // Marks allocation
  final int _marksA = 1;
  final int _marksB = 5;
  final int _marksC = 10;

  // Editor Controllers (to prevent focus loss during live edit)
  final Map<int, TextEditingController> _qTitleControllers = {};
  final Map<String, TextEditingController> _optControllers = {};

  @override
  void dispose() {
    _cancelToken?.cancel();
    _schoolNameController.dispose();
    _subjectController.dispose();
    _titleController.dispose();
    _durationController.dispose();
    _pageController.dispose();
    for (var c in _qTitleControllers.values) {
      c.dispose();
    }
    for (var c in _optControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Logic Methods ---

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.nextPage(duration: 400.ms, curve: Curves.easeInOut);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: 400.ms, curve: Curves.easeInOut);
    }
  }

  Future<void> _pickSource(String type) async {
    try {
      FilePickerResult? result;
      if (type == 'PDF') {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
          allowMultiple: true,
        );
      } else if (type == 'Image') {
        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
          allowMultiple: true,
        );
      }

      if (!mounted) return;

      if (type == 'Notes') {
        _showNotesInputDialog();
        return;
      }

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isProcessingSource = true;
        });

        final enhancedAiService =
            Provider.of<EnhancedAIService>(context, listen: false);
        final extractionService = ContentExtractionService(enhancedAiService);
        final user = Provider.of<UserModel?>(context, listen: false);

        _cancelToken = CancellationToken();

        final files = result.files;
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final bytes = file.bytes;
          final name = file.name;

          if (bytes == null) continue;

          setState(() {
            _processingMessage =
                'Extracting [${i + 1}/${files.length}]: $name...';
          });

          try {
            final res = await extractionService.extractContent(
              type: type.toLowerCase(),
              input: bytes,
              userId: user?.uid,
              mimeType: type == 'PDF'
                  ? 'application/pdf'
                  : (name.toLowerCase().endsWith('.png')
                      ? 'image/png'
                      : 'image/jpeg'),
              allowYouTubeImport: userMayImportFromYouTube(user),
              onProgress: (msg) => setState(() => _processingMessage =
                  '[${i + 1}/${files.length}] $msg'),
              cancelToken: _cancelToken,
            );

            setState(() {
              if (_sourceMaterial.isNotEmpty) {
                _sourceMaterial += '\n\n--- Source: $name ---\n\n';
              }
              _sourceMaterial += res.text;
              _processedFileNames.add(name);
            });
          } catch (e) {
            _showError('Failed to extract $name: $e');
          }
        }

        setState(() {
          _isProcessingSource = false;
          _processingMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessingSource = false;
        _processingMessage = '';
      });
      _showError('Error selecting source: $e');
    }
  }

  void _showNotesInputDialog() {
    final controller = TextEditingController(text: _sourceMaterial);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Source Material'),
        content: SizedBox(
          width: 600,
          child: TextField(
            controller: controller,
            maxLines: 15,
            decoration: const InputDecoration(
              hintText: 'Paste your teaching notes or syllabus content here...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => _sourceMaterial = controller.text);
              Navigator.pop(context);
            },
            child: const Text('Use Notes'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateQuestions() async {
    if (_titleController.text.isEmpty || _subjectController.text.isEmpty) {
      _showError('Please enter exam title and subject');
      return;
    }

    setState(() {
      _isGeneratingQuestions = true;
      _processingMessage = 'Brewing your professional exam paper...';
    });

    try {
      final aiService = Provider.of<EnhancedAIService>(context, listen: false);
      final user = Provider.of<UserModel?>(context, listen: false);

      final quiz = await aiService.generateExam(
        text: _sourceMaterial,
        title: _titleController.text,
        subject: _subjectController.text,
        level: _selectedLevel,
        questionCount: _numberOfQuestions,
        questionTypes: [
          if (_includeMultipleChoice) 'Multiple Choice',
          if (_includeShortAnswer) 'Short Answer',
          if (_includeTrueFalse) 'True/False',
          if (_includeTheory) 'Theory',
        ],
        difficultyMix: (1.0 - _easyRatio + _hardRatio) / 2,
        evenTopicCoverage: _evenTopicCoverage,
        focusWeakAreas: _focusWeakAreas,
        userId: user?.uid ?? 'anonymous',
      );

      setState(() {
        _generatedQuestions = quiz.questions;
        _isGeneratingQuestions = false;
        _showPreview = true;
      });
    } catch (e) {
      setState(() => _isGeneratingQuestions = false);
      _showError('Generation failed: $e');
    }
  }

  Future<void> _exportExam() async {
    setState(() {
      _isGeneratingQuestions = true;
      _processingMessage = 'Finalizing PDF document...';
    });

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final user = Provider.of<UserModel?>(context, listen: false);
      final shareCode = ShareCodeGenerator.generate();

      final publicDeck = PublicDeck(
        id: const Uuid().v4(),
        creatorId: user?.uid ?? 'anonymous',
        creatorName: user?.displayName ?? 'SumQuiz Tutor',
        shareCode: shareCode,
        title: _titleController.text,
        description: 'Practice version of the exam: ${_titleController.text}',
        summaryData: {},
        flashcardData: {},
        quizData: {
          'title': _titleController.text,
          'questions': _generatedQuestions.map((q) => q.toMap()).toList(),
        },
        publishedAt: DateTime.now(),
      );

      await firestore.publishDeck(publicDeck);

      final pdfGenerator = ExamPdfGenerator();
      final config = ExamPdfConfig(
        schoolName: _schoolNameController.text.trim().isEmpty
            ? 'SUMQUIZ ACADEMY'
            : _schoolNameController.text.trim(),
        examTitle: _titleController.text,
        subject: _subjectController.text,
        classLevel: _selectedLevel,
        durationMinutes: int.tryParse(_durationController.text) ?? 60,
        shareCode: shareCode,
        marksA: _marksA,
        marksB: _marksB,
        marksC: _marksC,
        includeAnswerSheet: true,
        includeMarkingScheme: true,
      );

      final studentPaper = pdfGenerator.generateStudentPaper(
        questions: _generatedQuestions,
        config: config,
      );
      final bytes = await studentPaper.save();

      // Desktop/Mobile/Browser standard print
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: '${_titleController.text}.pdf',
      );

      // Web specific download fallback if printing is blocked
      try {
        await Printing.sharePdf(
          bytes: bytes,
          filename: '${_titleController.text}.pdf',
        );
      } catch (e) {
        debugPrint('Web download fallback error: $e');
      }

      setState(() => _isGeneratingQuestions = false);
    } catch (e) {
      setState(() => _isGeneratingQuestions = false);
      _showError('Export failed: $e');
    }
  }

  Future<void> _regenerateQuestion(int index) async {
    setState(() {
      _isGeneratingQuestions = true;
      _processingMessage = 'Regenerating question ${index + 1}...';
    });

    try {
      final aiService = Provider.of<EnhancedAIService>(context, listen: false);
      final oldQuestion = _generatedQuestions[index];

      final regeneratedQuestion = await aiService.regenerateQuestion(
        sourceText: _sourceMaterial,
        subject: _subjectController.text,
        level: _selectedLevel,
        oldQuestion: oldQuestion,
      );

      setState(() {
        _generatedQuestions[index] = regeneratedQuestion;
        _isGeneratingQuestions = false;
      });
    } catch (e) {
      setState(() => _isGeneratingQuestions = false);
      _showError('Regeneration failed: $e');
    }
  }

  // PDF generation is now handled by ExamPdfGenerator service.

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showYoutubeInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Add YouTube Source', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter a YouTube URL to extract its transcript and generate exam questions.'),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/watch?v=...',
                  prefixIcon: const Icon(Icons.play_circle_filled, color: Colors.redAccent),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(context);
                _extractFromYoutube(url);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Extract Source'),
          ),
        ],
      ),
    );
  }

  Future<void> _extractFromYoutube(String url) async {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (!userMayImportFromYouTube(user)) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) =>
            const UpgradeDialog(featureName: 'YouTube import'),
      );
      return;
    }

    setState(() {
      _isProcessingSource = true;
      _processingMessage = 'Analyzing YouTube video...';
    });

    try {
      final extractionService = Provider.of<ContentExtractionService>(context, listen: false);

      final result = await extractionService.extractContent(
        type: 'youtube',
        input: url,
        userId: user?.uid,
        allowYouTubeImport: userMayImportFromYouTube(user),
        onProgress: (msg) => setState(() => _processingMessage = msg),
      );
      
      if (!mounted) return;
      setState(() {
        _sourceMaterial = result.text;
        _isProcessingSource = false;
        _processedFileNames.add('YouTube: ${result.suggestedTitle}');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingSource = false);
      _showError('YouTube Error: $e');
    }
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<UserModel?>(context);

    // Only block if they are at the limit AND not Pro
    if (user != null && !user.isPro && user.examsGenerated >= 3) {
      return _buildUpgradeScreen();
    }

    return Container(
      color: const Color(0xFFF1F5F9), 
      child: Stack(
        children: [
          (_isProcessingSource || _isGeneratingQuestions) ? _buildOverlayLoading() : const SizedBox.shrink(),
          Column(
            children: [
              _buildModernStepIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // STEP 1: SETUP
                    WebExamSetupStep(
                      titleController: _titleController,
                      subjectController: _subjectController,
                      schoolNameController: _schoolNameController,
                      durationController: _durationController,
                      selectedLevel: _selectedLevel,
                      onLevelChanged: (v) => setState(() => _selectedLevel = v ?? _selectedLevel),
                      onPickSourcePdf: () => _pickSource('PDF'),
                      onPickSourceNotes: () => _pickSource('Notes'),
                      onPickSourceYoutube: () {
                        if (!userMayImportFromYouTube(user)) {
                          showDialog<void>(
                            context: context,
                            builder: (_) => const UpgradeDialog(
                              featureName: 'YouTube import',
                            ),
                          );
                          return;
                        }
                        _showYoutubeInputDialog();
                      },
                      onNext: _nextStep,
                      hasSource: _sourceMaterial.isNotEmpty,
                      uploadStatusMessage: _processedFileNames.isNotEmpty ? 'Processed: ${_processedFileNames.join(", ")}' : 'Material Ready',
                    ),
                    // STEP 2: CONFIGURATION
                    WebExamConfigStep(
                      numberOfQuestions: _numberOfQuestions,
                      onQuestionsChanged: (v) => setState(() => _numberOfQuestions = v.round()),
                      easyCount: (_numberOfQuestions * _easyRatio).round(),
                      mediumCount: (_numberOfQuestions * (1.0 - _easyRatio - _hardRatio)).round(),
                      hardCount: (_numberOfQuestions * _hardRatio).round(),
                      onEasyChanged: (v) => setState(() {
                        _easyRatio = v;
                        if (_easyRatio + _hardRatio > 1.0) _hardRatio = 1.0 - _easyRatio;
                      }),
                      onHardChanged: (v) => setState(() {
                        _hardRatio = v;
                        if (_easyRatio + _hardRatio > 1.0) _easyRatio = 1.0 - _hardRatio;
                      }),
                      includeMultipleChoice: _includeMultipleChoice,
                      includeTrueFalse: _includeTrueFalse,
                      includeTheory: _includeTheory,
                      includeFillInBlank: _includeShortAnswer,
                      onTypeToggled: (type, val) {
                        setState(() {
                          if (type == 'mcq') _includeMultipleChoice = val;
                          if (type == 'tf') _includeTrueFalse = val;
                          if (type == 'theory') _includeTheory = val;
                          if (type == 'fib') _includeShortAnswer = val;
                        });
                      },
                      evenTopicCoverage: _evenTopicCoverage,
                      focusWeakAreas: _focusWeakAreas,
                      onRuleToggled: (rule, val) {
                        setState(() {
                          if (rule == 'even') _evenTopicCoverage = val;
                          if (rule == 'weak') _focusWeakAreas = val;
                        });
                      },
                      onFinalize: () async {
                        await _generateQuestions();
                        if (_generatedQuestions.isNotEmpty) {
                          _nextStep();
                        }
                      },
                      onBack: _prevStep,
                      isGenerating: _isGeneratingQuestions,
                    ),
                    // STEP 3: REVIEW
                    WebExamReviewStep(
                      questions: _generatedQuestions,
                      onRegenerate: _regenerateQuestion,
                      onQuestionChanged: (index, updatedQ) {
                        setState(() {
                          _generatedQuestions[index] = updatedQ;
                        });
                      },
                      onBack: _prevStep,
                      onSaveLibrary: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Library.')));
                        context.go('/library');
                      },
                      onPdfExport: _exportExam,
                      onPublish: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publishing to Class...')));
                      },
                      easyCount: (_numberOfQuestions * _easyRatio).round(),
                      mediumCount: (_numberOfQuestions * (1.0 - _easyRatio - _hardRatio)).round(),
                      hardCount: (_numberOfQuestions * _hardRatio).round(),
                      topicCounts: const {'Metabolism': 8, 'Cell Structures': 12, 'Genetics': 5},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStepIndicator() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => context.go('/library'),
          ),
          const SizedBox(width: 16),
          Text('Formal Exam Architect', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
          const Spacer(),
          _stepBubble(0, 'Setup', Icons.settings),
          _stepLine(),
          _stepBubble(1, 'Config', Icons.tune),
          _stepLine(),
          _stepBubble(2, 'Review', Icons.remove_red_eye),
          const Spacer(),
          if (_currentStep < 2) 
            TextButton(
              onPressed: _nextStep, 
              child: Text(_currentStep == 0 ? 'Review Source' : 'Generate Paper', style: const TextStyle(fontWeight: FontWeight.bold))
            ),
        ],
      ),
    );
  }

  Widget _stepBubble(int index, String label, IconData icon) {
    bool isCompleted = _currentStep > index;
    bool isActive = _currentStep == index;
    
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? Colors.green : (isActive ? const Color(0xFF4F46E5) : Colors.grey[200]),
          ),
          child: Icon(isCompleted ? Icons.check : icon, size: 14, color: isCompleted || isActive ? Colors.white : Colors.grey[500]),
        ),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.black : Colors.grey[500])),
      ],
    );
  }

  Widget _stepLine() {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.grey[200],
    );
  }

  Widget _buildUpgradeScreen() {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant
                .withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_rounded, size: 80),
              const SizedBox(height: 24),
              Text('Tutor Exam Pro',
                  style: GoogleFonts.outfit(
                      fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'Unlock professional exam generation, bulk question creation, and high-fidelity PDF exports designed for real classrooms.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.push('/settings/subscription'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56)),
                child: const Text('Upgrade to Pro'),
              ),
              TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go Home')),
            ],
          ),
        ).animate().fadeIn().scale(),
      ),
    );
  }

  Widget _buildOverlayLoading() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(_processingMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: () => _cancelToken?.cancel(),
                  child: const Text('Cancel Request')),
            ],
          ),
        ),
      ),
    );
  }
}

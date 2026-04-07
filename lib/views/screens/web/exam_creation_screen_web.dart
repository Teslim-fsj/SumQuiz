import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  final double _difficultyValue = 0.5;
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
  int _marksA = 1;
  int _marksB = 5;
  int _marksC = 10;

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
        difficultyMix: _difficultyValue,
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

      final pdf = await _generatePdfDocument(shareCode);
      final bytes = await pdf.save();

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

  Future<pw.Document> _generatePdfDocument(String shareCode) async {
    final pdf = pw.Document();

    final sectionA = _generatedQuestions
        .where((q) =>
            q.questionType == 'Multiple Choice' ||
            q.questionType == 'True/False')
        .toList();
    final sectionB = _generatedQuestions
        .where((q) => q.questionType == 'Short Answer')
        .toList();
    final sectionC = _generatedQuestions
        .where((q) =>
            q.questionType == 'Theory' ||
            q.questionType == 'Essay' ||
            (!['Multiple Choice', 'True/False', 'Short Answer']
                .contains(q.questionType)))
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (pw.Context context) =>
            _buildPdfHeader(shareCode, isFirstPage: false),
        build: (pw.Context context) => [
          _buildPdfHeader(shareCode, isFirstPage: true),
          pw.SizedBox(height: 10),
          if (sectionA.isNotEmpty) ...[
            _pdfSectionTitle(
                'SECTION A – OBJECTIVE (${sectionA.length * _marksA} MARKS)'),
            pw.SizedBox(height: 8),
            for (int i = 0; i < sectionA.length; i++)
              _pdfQuestionItem(sectionA[i], i + 1, _marksA),
            pw.SizedBox(height: 15),
          ],
          if (sectionB.isNotEmpty) ...[
            _pdfSectionTitle(
                'SECTION B – SHORT ANSWER (${sectionB.length * _marksB} MARKS)'),
            pw.SizedBox(height: 8),
            for (int i = 0; i < sectionB.length; i++)
              _pdfQuestionItem(
                  sectionB[i], i + sectionA.length + 1, _marksB),
            pw.SizedBox(height: 15),
          ],
          if (sectionC.isNotEmpty) ...[
            _pdfSectionTitle(
                'SECTION C – THEORY / ESSAY (${sectionC.length * _marksC} MARKS)'),
            pw.SizedBox(height: 8),
            for (int i = 0; i < sectionC.length; i++)
              _pdfQuestionItem(sectionC[i],
                  i + sectionA.length + sectionB.length + 1, _marksC),
          ],
        ],
      ),
    );

    // Add Answer Scheme Page
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      header: (pw.Context context) =>
          _buildPdfHeader(shareCode, isFirstPage: false),
      build: (pw.Context context) => [
        _pdfSectionTitle('MARKING SCHEME & ANSWER KEY'),
        pw.SizedBox(height: 10),
          if (sectionA.isNotEmpty) ...[
            pw.Text('SECTION A - OBJECTIVE',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 8),
            for (int i = 0; i < sectionA.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                    '${i + 1}. ${sectionA[i].options.contains(sectionA[i].correctAnswer) ? String.fromCharCode(65 + sectionA[i].options.indexOf(sectionA[i].correctAnswer)) : ""} - ${sectionA[i].correctAnswer}',
                    style: const pw.TextStyle(fontSize: 10)),
              ),
            pw.SizedBox(height: 15),
          ],
          if (sectionB.isNotEmpty) ...[
            pw.Text('SECTION B - SHORT ANSWER',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 8),
            for (int i = 0; i < sectionB.length; i++)
              pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                            '${i + sectionA.length + 1}. ${sectionB[i].correctAnswer}',
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.green700)),
                        if (sectionB[i].explanation != null &&
                            sectionB[i].explanation!.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('Explanation: ${sectionB[i].explanation}',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontStyle: pw.FontStyle.italic,
                                  color: PdfColors.grey700)),
                        ]
                      ])),
            pw.SizedBox(height: 15),
          ],
          if (sectionC.isNotEmpty) ...[
            pw.Text('SECTION C - THEORY / ESSAY',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 8),
            for (int i = 0; i < sectionC.length; i++)
              pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                            '${i + sectionA.length + sectionB.length + 1}. Expected Answer/Points:',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text(sectionC[i].correctAnswer,
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.green700)),
                        if (sectionC[i].explanation != null &&
                            sectionC[i].explanation!.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('Marking Guide: ${sectionC[i].explanation}',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontStyle: pw.FontStyle.italic,
                                  color: PdfColors.grey700)),
                        ]
                      ])),
          ],
      ],
    ));

    return pdf;
  }

  pw.Widget _buildPdfHeader(String shareCode, {bool isFirstPage = true}) {
    if (!isFirstPage) {
      return pw.Column(children: [
        pw.Center(
          child: pw.Text(_schoolNameController.text.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
        ),
        pw.SizedBox(height: 5),
        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
        pw.SizedBox(height: 10),
      ]);
    }

    return pw.Column(children: [
      pw.Center(
        child: pw.Text(_schoolNameController.text.toUpperCase(),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      ),
      pw.SizedBox(height: 15),
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SUBJECT: ${_subjectController.text.toUpperCase()}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.SizedBox(height: 4),
                  pw.Text('CLASS: $_selectedLevel',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.SizedBox(height: 4),
                  pw.Text('TIME ALLOWED: ${_durationController.text} MINUTES',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.SizedBox(height: 12),
                  pw.Text(
                      'STUDENT NAME: __________________________________________',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ]),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(children: [
                pw.Text('Review Online:',
                    style: pw.TextStyle(
                        fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('sumquiz.xyz/s/$shareCode',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.blue800)),
                pw.SizedBox(height: 4),
                pw.Container(
                  height: 35,
                  width: 35,
                  child: pw.BarcodeWidget(
                    color: PdfColors.black,
                    barcode: pw.Barcode.qrCode(),
                    data: "https://sumquiz.xyz/s/$shareCode",
                  ),
                ),
              ]),
            ),
          ]),
      pw.SizedBox(height: 10),
      pw.Divider(thickness: 1.5),
    ]);
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(
          top: pw.BorderSide(width: 1),
          bottom: pw.BorderSide(width: 1),
        ),
      ),
      width: double.infinity,
      child: pw.Text(title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
    );
  }

  pw.Widget _pdfQuestionItem(LocalQuizQuestion q, int number, int marks) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child:
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('$number. ', style: const pw.TextStyle(fontSize: 10)),
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                      text: q.question,
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.TextSpan(
                      text: ' ($marks Mark${marks > 1 ? 's' : ''})',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          fontStyle: pw.FontStyle.italic)),
                ],
              ),
            ),
          ),
        ]),
        if (q.questionType == 'Multiple Choice') ...[
          pw.SizedBox(height: 4),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 15),
            child: pw.Column(children: [
              for (int i = 0; i < q.options.length; i++)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 1.5),
                  child: pw.Row(children: [
                    pw.Text('(${String.fromCharCode(65 + i)}) ',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(q.options[i],
                        style: const pw.TextStyle(fontSize: 9)),
                  ]),
                ),
            ]),
          ),
        ] else if (q.questionType == 'Theory' || q.questionType == 'Essay') ...[
          pw.SizedBox(height: 30),
        ] else if (q.questionType == 'Short Answer') ...[
          pw.SizedBox(height: 10),
          pw.Text('Answer: __________________________________________________',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ]),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
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
          _isProcessingSource ? _buildOverlayLoading() : const SizedBox.shrink(),
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
                      onNext: _nextStep,
                      hasSource: _sourceMaterial.isNotEmpty,
                      uploadStatusMessage: _processedFileNames.isNotEmpty ? 'Processed: ${_processedFileNames.join(", ")}' : 'Material Ready',
                    ),
                    // STEP 2: CONFIGURATION
                    WebExamConfigStep(
                      numberOfQuestions: _numberOfQuestions,
                      onQuestionsChanged: (v) => setState(() => _numberOfQuestions = v.round()),
                      easyCount: (_numberOfQuestions * (1.0 - _difficultyValue) * 0.7).floor(),
                      mediumCount: (_numberOfQuestions * _difficultyValue).round(),
                      hardCount: (_numberOfQuestions * (1.0 - _difficultyValue) * 0.3).ceil(),
                      onEasyChanged: (v) {}, // Mocked for UI, ideally update a complex state
                      onHardChanged: (v) {},
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
                      onFinalize: () {
                        _generateQuestions();
                        _nextStep();
                      },
                      isGenerating: _isGeneratingQuestions,
                    ),
                    // STEP 3: REVIEW
                    WebExamReviewStep(
                      questions: _generatedQuestions,
                      onRegenerate: (index) {
                        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Regenerate specific AI feature coming soon.')));
                        setState(() {
                          _generatedQuestions.removeAt(index);
                        });
                      },
                      onSaveLibrary: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Library.')));
                        context.go('/library');
                      },
                      onPdfExport: _exportExam,
                      onPublish: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publishing to Class...')));
                      },
                      easyCount: _generatedQuestions.where((q) => q.question.length < 50).length, // Fake mockup stats
                      mediumCount: _generatedQuestions.where((q) => q.question.length >= 50 && q.question.length < 100).length,
                      hardCount: _generatedQuestions.where((q) => q.question.length >= 100).length,
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
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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

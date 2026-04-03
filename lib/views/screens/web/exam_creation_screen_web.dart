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
        // _showPreview = true; // This variable is not defined in the provided code.
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          Row(
            children: [
              // Left Panel (Steps & Forms)
              _buildWizardPanel(),
              const VerticalDivider(width: 1),
              // Right Panel (Live Preview)
              Expanded(child: _buildPreviewPanel()),
            ],
          ),
          if (_isGeneratingQuestions || _isProcessingSource)
            _buildOverlayLoading(),
        ],
      ),
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

  Widget _buildWizardPanel() {
    final theme = Theme.of(context);
    return Container(
      width: 500,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
            right: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.1))),
      ),
      child: Column(
        children: [
          _buildWizardHeader(),
          const Divider(height: 1),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildWizardFooter(),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Container(
          width: 800,
          margin: const EdgeInsets.all(40),
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
          child: _generatedQuestions.isEmpty
              ? _buildEmptyPreview()
              : _buildExamPreview(),
        ),
      ),
    );
  }

  Widget _buildEmptyPreview() {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.description_outlined,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        const SizedBox(height: 24),
        Text(
          'No Exam Generated Yet',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Generate your exam on the left to see the live preview here.',
          style: GoogleFonts.outfit(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
      ],
    );
  }

  Widget _buildExamPreview() {
    return Column(
      children: [
        _buildPreviewHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(32),
            itemCount: _generatedQuestions.length,
            itemBuilder: (context, index) =>
                _editablePaperQuestion(_generatedQuestions[index], index + 1),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewHeader() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
            bottom: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary
                  ]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.remove_red_eye_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Preview',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    'Dynamic update as you edit',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ],
          ),
          TextButton.icon(
            onPressed: _exportExam,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Export PDF'),
          ),
        ],
      ),
    );
  }



  Widget _buildWizardHeader() {
    final theme = Theme.of(context);
    final user = Provider.of<UserModel?>(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 16),
              Text(
                'Exam Builder',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (user != null && !user.isPro) ...[
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${user.examsGenerated}/3 Free Exams Used',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _stepIndicator(0, 'Context'),
              _stepConnector(),
              _stepIndicator(1, 'Source'),
              _stepConnector(),
              _stepIndicator(2, 'Rules'),
              _stepConnector(),
              _stepIndicator(3, 'Finalize'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepIndicator(int step, String label) {
    final theme = Theme.of(context);
    bool isActive = _currentStep == step;
    bool isDone = _currentStep > step;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? theme.colorScheme.tertiary
                : (isActive
                    ? theme.colorScheme.error
                    : theme.colorScheme.surface),
            border: Border.all(
                color: isActive
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? theme.colorScheme.tertiary
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _stepConnector() {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18, left: 8, right: 8),
        color: theme.colorScheme.outline.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildWizardFooter() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              child: const Text('Back'),
            )
          else
            const SizedBox(),
          if (_currentStep < 3)
            ElevatedButton(
              onPressed: _canGoNext() ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Next Step'),
            )
          else
            Consumer<UserModel?>(
              builder: (context, user, child) {
                final theme = Theme.of(context);
                final bool isLimitReached = user != null && !user.isPro && user.examsGenerated >= 3;
                
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLimitReached)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Limit Reached',
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: (_sourceMaterial.isEmpty || isLimitReached) ? null : _generateQuestions,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        backgroundColor: isLimitReached ? theme.colorScheme.outline : null,
                      ),
                      child: Text(isLimitReached ? 'Upgrade to Pro' : 'Generate Paper'),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  bool _canGoNext() {
    if (_currentStep == 0) {
      return _titleController.text.isNotEmpty &&
          _subjectController.text.isNotEmpty;
    }
    if (_currentStep == 1) {
      return _sourceMaterial.isNotEmpty;
    }
    return true;
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _wizardSectionHeader(
              'CONTEXTUAL DATA', 'Define your institution and class details.'),
          const SizedBox(height: 32),
          _titleField('Institution Name', _schoolNameController,
              'e.g. Oakbridge High School'),
          const SizedBox(height: 24),
          _titleField(
              'Subject', _subjectController, 'e.g. Advanced Mathematics'),
          const SizedBox(height: 24),
          _titleField(
              'Exam Title', _titleController, 'e.g. Mid-Term Assessment'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Class / Level',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLevel,
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                      items: [
                        'Primary / Elementary',
                        'Middle School',
                        'High School / Secondary',
                        'Vocational / Technical',
                        'Undergraduate (University)',
                        'Postgraduate (Masters/PhD)',
                        'Professional Certification',
                        'Corporate Training'
                      ]
                          .map(
                              (l) => DropdownMenuItem<String>(value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedLevel = v ?? 'High School / Secondary'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _titleField('Duration (mins)', _durationController, '60',
                    isNumber: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _wizardSectionHeader('RESOURCE INGESTION',
              'Upload the material the AI will use to generate questions.'),
          const SizedBox(height: 32),
          if (_sourceMaterial.isEmpty) ...[
            _sourceUploadCard(
                'Upload PDF Document',
                'Highly recommended for textbooks & notes',
                Icons.picture_as_pdf_outlined,
                () => _pickSource('PDF')),
            const SizedBox(height: 16),
            _sourceUploadCard(
                'Paste Study Notes',
                'Copy-paste raw text or syllabus content',
                Icons.note_alt_outlined,
                () => _pickSource('Notes')),
            const SizedBox(height: 16),
            _sourceUploadCard(
                'Scan Examination Paper',
                'OCR extraction from physical papers',
                Icons.camera_alt_outlined,
                () => _pickSource('Image')),
          ] else
            _uploadedStateCard(),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _wizardSectionHeader(
              'EXAM STRUCTURE', 'Configure the question mix and difficulty.'),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Weight (Total Questions)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('$_numberOfQuestions Items',
                    style: TextStyle(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Slider(
            value: _numberOfQuestions.toDouble(),
            min: 5,
            max: 50,
            activeColor: theme.colorScheme.tertiary,
            onChanged: (v) => setState(() => _numberOfQuestions = v.round()),
          ),
          const SizedBox(height: 32),
          const Text('Question Components',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _checkboxTile(
              'Objective / MCQ',
              'Includes distractors & correct answer',
              _includeMultipleChoice,
              (v) => setState(() => _includeMultipleChoice = v!)),
          _checkboxTile('True / False', 'Quick conceptual validation',
              _includeTrueFalse, (v) => setState(() => _includeTrueFalse = v!)),
          _checkboxTile(
              'Short Answer',
              'Fill-in-the-gap or definitions',
              _includeShortAnswer,
              (v) => setState(() => _includeShortAnswer = v!)),
          _checkboxTile(
              'Theory / Essay',
              'Long-form responses (marking scheme included)',
              _includeTheory,
              (v) => setState(() => _includeTheory = v!)),
          const SizedBox(height: 32),
          _wizardSectionHeader(
              'AI STRATEGY', 'Fine-tune the intelligence behavior.'),
          const SizedBox(height: 16),
          _switchTile(
              'Even Topic Coverage',
              'Ensure questions are spread across all pages',
              _evenTopicCoverage,
              (v) => setState(() => _evenTopicCoverage = v)),
          _switchTile(
              'Focus Complex Areas',
              'Prioritize technical or difficult concepts',
              _focusWeakAreas,
              (v) => setState(() => _focusWeakAreas = v)),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _wizardSectionHeader('MARKS ALLOCATION',
              'Define how many points each section contributes.'),
          const SizedBox(height: 32),
          _marksAllocationRow('Section A (Objective)', 'For MCQs and T/F',
              _marksA, (v) => setState(() => _marksA = v)),
          const SizedBox(height: 24),
          _marksAllocationRow('Section B (Structured)', 'For Short Answers',
              _marksB, (v) => setState(() => _marksB = v)),
          const SizedBox(height: 24),
          _marksAllocationRow('Section C (Continuous)', 'For Theory & Essays',
              _marksC, (v) => setState(() => _marksC = v)),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFEDD5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFC2410C)),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'AI will generate a high-quality paper based on these rules. You can edit every question individually in the preview pane.',
                    style: TextStyle(color: Color(0xFF9A3412), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editablePaperQuestion(LocalQuizQuestion q, int index) {
    final theme = Theme.of(context);
    int marks =
        (q.questionType == 'Multiple Choice' || q.questionType == 'True/False')
            ? _marksA
            : (q.questionType == 'Short Answer' ? _marksB : _marksC);

    // Get or create controller for question title
    if (!_qTitleControllers.containsKey(index)) {
      _qTitleControllers[index] = TextEditingController(text: q.question);
    }
    final qCtrl = _qTitleControllers[index]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: qCtrl,
                  onChanged: (v) => q.question = v,
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: const InputDecoration(
                      border: InputBorder.none, isCollapsed: true),
                ),
              ),
              const SizedBox(width: 8),
              Text('($marks Marks)',
                  style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4))),
              IconButton(
                onPressed: () {
                  setState(() {
                    _generatedQuestions.removeAt(index - 1);
                    _qTitleControllers.remove(index);
                    _qTitleControllers.clear();
                    _optControllers.clear();
                  });
                },
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.redAccent),
              ),
            ],
          ),
          if (q.questionType == 'Multiple Choice')
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 12),
              child: Column(
                children: [
                  for (int i = 0; i < q.options.length; i++) ...[
                    Builder(builder: (context) {
                      final optKey = '${index}_$i';
                      if (!_optControllers.containsKey(optKey)) {
                        _optControllers[optKey] =
                            TextEditingController(text: q.options[i]);
                      }
                      final optCtrl = _optControllers[optKey]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Text('(${String.fromCharCode(65 + i)}) ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Expanded(
                              child: TextField(
                                controller: optCtrl,
                                onChanged: (v) => q.options[i] = v,
                                decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isCollapsed: true),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _wizardSectionHeader(String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(subtitle,
            style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14)),
      ],
    );
  }

  Widget _titleField(String label, TextEditingController ctrl, String hint,
      {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
              hintText: hint, border: const OutlineInputBorder()),
        ),
      ],
    );
  }

  Widget _sourceUploadCard(
      String title, String sub, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: theme.colorScheme.tertiary),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(sub,
                      style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Widget _uploadedStateCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          border: Border.all(color: const Color(0xFFDCFCE7)),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: theme.colorScheme.tertiary),
              const SizedBox(width: 16),
              const Expanded(
                  child: Text('Content Ingested Successfully',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534)))),
              IconButton(
                  tooltip: 'Clear All Sources',
                  onPressed: () => setState(() {
                        _sourceMaterial = '';
                        _processedFileNames.clear();
                      }),
                  icon: const Icon(Icons.delete_sweep_outlined,
                      color: Colors.red)),
            ],
          ),
          const SizedBox(height: 16),
          if (_processedFileNames.isNotEmpty) ...[
            Text('Processed Files:',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.tertiary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _processedFileNames
                  .map((name) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.insert_drive_file_outlined,
                                size: 12, color: Color(0xFF166534)),
                            const SizedBox(width: 6),
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF166534))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            _sourceMaterial.length > 300
                ? '${_sourceMaterial.substring(0, 300)}...'
                : _sourceMaterial,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF166534), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _checkboxTile(
      String title, String sub, bool val, Function(bool?) onChange) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      value: val,
      onChanged: onChange,
      activeColor: theme.colorScheme.tertiary,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _switchTile(
      String title, String sub, bool val, Function(bool) onChange) {
    final theme = Theme.of(context);
    return SwitchListTile(
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      value: val,
      onChanged: onChange,
      activeThumbColor: theme.colorScheme.tertiary,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _marksAllocationRow(
      String label, String sub, int val, Function(int) onChange) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text(sub,
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4))),
            ],
          ),
        ),
        SizedBox(
          width: 80,
          child: TextField(
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            onChanged: (v) => onChange(int.tryParse(v) ?? 1),
            decoration: InputDecoration(
              hintText: '$val',
              suffixText: 'pts',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
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

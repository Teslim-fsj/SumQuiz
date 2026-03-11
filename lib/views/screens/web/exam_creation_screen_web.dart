import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:sumquiz/utils/share_code_generator.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';

class ExamCreationScreenWeb extends StatefulWidget {
  const ExamCreationScreenWeb({super.key});

  @override
  State<ExamCreationScreenWeb> createState() => _ExamCreationScreenWebState();
}

class _ExamCreationScreenWebState extends State<ExamCreationScreenWeb> {
  // controllers
  final _schoolNameController = TextEditingController(text: 'SUMQUIZ ACADEMY');
  final _subjectController = TextEditingController();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '60');

  // state variables
  String _selectedLevel = 'JSS1';
  int _numberOfQuestions = 20;
  double _difficultyValue = 0.5;
  bool _includeMultipleChoice = true;
  bool _includeShortAnswer = false;
  bool _includeTheory = false;
  bool _includeTrueFalse = false;

  String _sourceMaterial = '';
  bool _isProcessingSource = false;
  bool _isGeneratingQuestions = false;
  String _processingMessage = '';
  CancellationToken? _cancelToken;

  List<LocalQuizQuestion> _generatedQuestions = [];
  bool _showPreview = false;

  // Marks allocation
  int _marksA = 1;
  int _marksB = 5;
  int _marksC = 10;

  @override
  void dispose() {
    _cancelToken?.cancel();
    _schoolNameController.dispose();
    _subjectController.dispose();
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // --- Logic Methods ---

  Future<void> _pickSource(String type) async {
    setState(() {
      _isProcessingSource = true;
      _processingMessage = 'Selecting $type...';
    });

    try {
      FilePickerResult? result;
      if (type == 'PDF') {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
        );
      } else if (type == 'Image') {
        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
      } else {
        _showNotesInputDialog();
        setState(() => _isProcessingSource = false);
        return;
      }

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final name = result.files.single.name;

        setState(() => _processingMessage = 'Extracting content from $name...');

        final enhancedAiService =
            Provider.of<EnhancedAIService>(context, listen: false);
        final extractionService = ContentExtractionService(enhancedAiService);
        final user = Provider.of<UserModel?>(context, listen: false);

        _cancelToken = CancellationToken();
        final res = await extractionService.extractContent(
          type: type.toLowerCase(),
          input: bytes,
          userId: user?.uid,
          mimeType: type == 'PDF' ? 'application/pdf' : 'image/jpeg',
          onProgress: (msg) => setState(() => _processingMessage = msg),
          cancelToken: _cancelToken,
        );

        setState(() {
          _sourceMaterial = res.text;
          _isProcessingSource = false;
        });
      } else {
        setState(() => _isProcessingSource = false);
      }
    } catch (e) {
      setState(() => _isProcessingSource = false);
      _showError('Error extracting source: $e');
    }
  }

  void _showNotesInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Source Material'),
        content: TextField(
          controller: controller,
          maxLines: 15,
          decoration: const InputDecoration(
            hintText: 'Paste your teaching notes or syllabus content here...',
            border: OutlineInputBorder(),
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
    // PDF generation logic similar to mobile but web-optimized
    // It should include the QR loop we just built
    setState(() => _isGeneratingQuestions = true);
    setState(() => _processingMessage = 'Finalizing PDF document...');

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final user = Provider.of<UserModel?>(context, listen: false);
      final shareCode = ShareCodeGenerator.generate();

      // Create a public deck for the QR loop
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

      // Generate the PDF
      final pdf = await _generatePdfDocument(shareCode);

      // On Web, use Printing.sharePdf or Printing.layoutPdf
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${_titleController.text}.pdf',
      );

      setState(() => _isGeneratingQuestions = false);
    } catch (e) {
      setState(() => _isGeneratingQuestions = false);
      _showError('Export failed: $e');
    }
  }

  Future<pw.Document> _generatePdfDocument(String shareCode) async {
    final pdf = pw.Document();

    // Group questions by type for sections
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
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) => _buildPdfHeader(shareCode),
        build: (pw.Context context) => [
          pw.SizedBox(height: 20),
          if (sectionA.isNotEmpty) ...[
            _pdfSectionTitle(
                'SECTION A – OBJECTIVE (${sectionA.length * _marksA} MARKS)'),
            pw.SizedBox(height: 10),
            pw.ListView.builder(
              itemCount: sectionA.length,
              itemBuilder: (context, index) =>
                  _pdfQuestionItem(sectionA[index], index + 1, _marksA),
            ),
            pw.SizedBox(height: 20),
          ],
          if (sectionB.isNotEmpty) ...[
            _pdfSectionTitle(
                'SECTION B – SHORT ANSWER (${sectionB.length * _marksB} MARKS)'),
            pw.SizedBox(height: 10),
            pw.ListView.builder(
              itemCount: sectionB.length,
              itemBuilder: (context, index) => _pdfQuestionItem(
                  sectionB[index], index + sectionA.length + 1, _marksB),
            ),
            pw.SizedBox(height: 20),
          ],
          if (sectionC.isNotEmpty) ...[
            _pdfSectionTitle(
                'SECTION C – THEORY / ESSAY (${sectionC.length * _marksC} MARKS)'),
            pw.SizedBox(height: 10),
            pw.ListView.builder(
              itemCount: sectionC.length,
              itemBuilder: (context, index) => _pdfQuestionItem(sectionC[index],
                  index + sectionA.length + sectionB.length + 1, _marksC),
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfHeader(String shareCode) {
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
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 8),
                  pw.Text('CLASS: $_selectedLevel',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 8),
                  pw.Text('DATE: ____________________',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 8),
                  pw.Text('TIME ALLOWED: ${_durationController.text} MINUTES',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 15),
                  pw.Text(
                      'STUDENT NAME: __________________________________________',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                ]),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(children: [
                pw.Text('Practice & Review:',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('sumquiz.app/s/$shareCode',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.blue800)),
                pw.SizedBox(height: 6),
                pw.Container(
                  height: 60,
                  width: 60,
                  child: pw.BarcodeWidget(
                    color: PdfColors.black,
                    barcode: pw.Barcode.qrCode(),
                    data: "https://sumquiz.app/s/$shareCode",
                  ),
                ),
              ]),
            ),
          ]),
      pw.SizedBox(height: 20),
      pw.Divider(),
    ]);
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      width: double.infinity,
      child: pw.Text(title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
    );
  }

  pw.Widget _pdfQuestionItem(LocalQuizQuestion q, int number, int marks) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      child:
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('$number. ', style: const pw.TextStyle(fontSize: 11)),
          pw.Expanded(
            child: pw.Text('${q.question} ($marks Mark${marks > 1 ? 's' : ''})',
                style: const pw.TextStyle(fontSize: 11)),
          ),
        ]),
        if (q.questionType == 'Multiple Choice') ...[
          pw.SizedBox(height: 8),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 20),
            child: pw.Column(children: [
              for (int i = 0; i < q.options.length; i++)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(children: [
                    pw.Text('(${String.fromCharCode(65 + i)}) ',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(q.options[i],
                        style: const pw.TextStyle(fontSize: 10)),
                  ]),
                ),
            ]),
          ),
        ] else if (q.questionType == 'Theory' || q.questionType == 'Essay') ...[
          pw.SizedBox(height: 40), // Space for answer
        ] else if (q.questionType == 'Short Answer') ...[
          pw.SizedBox(height: 20),
          pw.Text('Answer: __________________________________________________',
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
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
    final user = Provider.of<UserModel?>(context);

    // Pro logic
    if (user != null && !user.isPro) {
      return _buildUpgradeScreen();
    }

    return Scaffold(
      backgroundColor: WebColors.background,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Row(
              children: [
                _buildLeftPane(),
                const VerticalDivider(width: 1),
                Expanded(child: _buildRightPane()),
              ],
            ),
          ),
          if (_isGeneratingQuestions || _isProcessingSource)
            _buildOverlayLoading(),
        ],
      ),
    );
  }

  Widget _buildUpgradeScreen() {
    return Scaffold(
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: WebColors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_rounded,
                  size: 80, color: WebColors.primary),
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back')),
            ],
          ),
        ).animate().fadeIn().scale(),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        color: WebColors.background,
        image: DecorationImage(
          image: const NetworkImage(
              'https://www.transparenttextures.com/patterns/cubes.png'),
          opacity: 0.05,
          repeat: ImageRepeat.repeat,
        ),
      ),
    );
  }

  Widget _buildLeftPane() {
    return Container(
      width: 450,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBreadcrumbs(),
            const SizedBox(height: 24),
            Text('Exam Configuration',
                style: GoogleFonts.outfit(
                    fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Define the structure of your paper.',
                style: WebTheme.lightTheme.textTheme.bodyMedium),
            const SizedBox(height: 32),
            _buildMetadataForm(),
            const SizedBox(height: 32),
            _buildSourceSection(),
            const SizedBox(height: 32),
            _buildQuestionSettings(),
            const SizedBox(height: 48),
            _buildGenerateCTA(),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          style: IconButton.styleFrom(backgroundColor: WebColors.background),
        ),
        const SizedBox(width: 12),
        const Text('Library / Tutor Exam',
            style: TextStyle(color: WebColors.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildMetadataForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _formHeader('GENERAL INFORMATION'),
        const SizedBox(height: 16),
        TextField(
          controller: _schoolNameController,
          decoration:
              const InputDecoration(labelText: 'School / Institution Name'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
              labelText: 'Exam Title (e.g., First Term Examination)'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedLevel,
                decoration: const InputDecoration(labelText: 'Target Class'),
                items: ['JSS1', 'JSS2', 'JSS3', 'SS1', 'SS2', 'SS3', 'Tertiary']
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedLevel = v!),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Duration', suffixText: 'mins'),
              ),
            ),
            const SizedBox(width: 16),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _formHeader('SOURCE MATERIAL'),
        const SizedBox(height: 16),
        if (_sourceMaterial.isEmpty)
          Row(
            children: [
              _sourceButton('PDF', Icons.picture_as_pdf_outlined,
                  () => _pickSource('PDF')),
              const SizedBox(width: 12),
              _sourceButton('SCAN', Icons.camera_alt_outlined,
                  () => _pickSource('Image')),
              const SizedBox(width: 12),
              _sourceButton(
                  'NOTES', Icons.note_alt_outlined, () => _pickSource('Notes')),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WebColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WebColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: WebColors.success, size: 20),
                    const SizedBox(width: 8),
                    const Text('Content Extracted',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => setState(() => _sourceMaterial = ''),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _sourceMaterial.length > 150
                      ? '${_sourceMaterial.substring(0, 150)}...'
                      : _sourceMaterial,
                  style: const TextStyle(
                      fontSize: 12, color: WebColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sourceButton(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            border: Border.all(color: WebColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: WebColors.primary, size: 24),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _formHeader('QUESTION STRUCTURE'),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Count', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('$_numberOfQuestions Questions',
                style: const TextStyle(color: WebColors.primary)),
          ],
        ),
        Slider(
          value: _numberOfQuestions.toDouble(),
          min: 5,
          max: 100,
          onChanged: (v) => setState(() => _numberOfQuestions = v.round()),
        ),
        const SizedBox(height: 16),
        const Text('Question Types',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            _typeChip('Objective', _includeMultipleChoice,
                (v) => setState(() => _includeMultipleChoice = v)),
            _typeChip('Short Answer', _includeShortAnswer,
                (v) => setState(() => _includeShortAnswer = v)),
            _typeChip('Theory', _includeTheory,
                (v) => setState(() => _includeTheory = v)),
            _typeChip('True/False', _includeTrueFalse,
                (v) => setState(() => _includeTrueFalse = v)),
          ],
        ),
      ],
    );
  }

  Widget _typeChip(String label, bool selected, Function(bool) onSelected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: WebColors.primaryLight,
      checkmarkColor: WebColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildGenerateCTA() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _sourceMaterial.isEmpty ? null : _generateQuestions,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Generate Exam Paper'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Questions will be editable after generation.',
              style: TextStyle(fontSize: 12, color: WebColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildRightPane() {
    if (!_showPreview) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildPreviewHeader(),
        Expanded(
          child: _buildQuestionsList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined,
              size: 100, color: WebColors.primary.withOpacity(0.1)),
          const SizedBox(height: 24),
          Text('Live Exam Preview',
              style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: WebColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
              'Configure your exam and generate to see the live preview here.',
              style: TextStyle(color: WebColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPreviewHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: WebColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EXAM PREVIEW',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1,
                      color: WebColors.textTertiary)),
              const SizedBox(height: 4),
              Text(_titleController.text,
                  style: GoogleFonts.outfit(
                      fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          _marksConfig(),
          const SizedBox(width: 32),
          OutlinedButton.icon(
            onPressed: () => setState(() => _showPreview = false),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Config'),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _exportExam,
            icon: const Icon(Icons.print_rounded),
            label: const Text('Export PDF'),
            style:
                ElevatedButton.styleFrom(backgroundColor: WebColors.secondary),
          ),
        ],
      ),
    );
  }

  Widget _marksConfig() {
    return Row(
      children: [
        _marksInput('MCQ', _marksA, (v) => setState(() => _marksA = v)),
        const SizedBox(width: 16),
        _marksInput('Short', _marksB, (v) => setState(() => _marksB = v)),
        const SizedBox(width: 16),
        _marksInput('Theory', _marksC, (v) => setState(() => _marksC = v)),
      ],
    );
  }

  Widget _marksInput(String label, int val, Function(int) onChanged) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 50,
          child: TextField(
            textAlign: TextAlign.center,
            decoration: const InputDecoration(contentPadding: EdgeInsets.zero),
            controller: TextEditingController(text: '$val'),
            keyboardType: TextInputType.number,
            onChanged: (v) => onChanged(int.tryParse(v) ?? 1),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsList() {
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        // Mock Paper Look
        Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)
            ],
            border: Border.all(color: WebColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header preview
              Center(
                  child: Text(_schoolNameController.text.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold))),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SUBJECT: ${_subjectController.text.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('CLASS: $_selectedLevel',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('TIME: 1 HOUR',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!)),
                    child: const Center(
                        child:
                            Icon(Icons.qr_code, size: 50, color: Colors.grey)),
                  )
                ],
              ),
              const SizedBox(height: 24),
              const Divider(thickness: 2),
              const SizedBox(height: 32),

              // Questions
              for (int i = 0; i < _generatedQuestions.length; i++)
                _editableQuestionWidget(_generatedQuestions[i], i + 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _editableQuestionWidget(LocalQuizQuestion q, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$index. ',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: q.question),
                  maxLines: null,
                  onChanged: (v) => q.question = v,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                      border: InputBorder.none, isCollapsed: true),
                ),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _generatedQuestions.removeAt(index - 1)),
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          if (q.questionType == 'Multiple Choice') ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                children: [
                  for (int j = 0; j < q.options.length; j++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text('(${String.fromCharCode(65 + j)}) ',
                              style: const TextStyle(
                                  color: WebColors.textTertiary)),
                          Expanded(
                            child: TextField(
                              controller:
                                  TextEditingController(text: q.options[j]),
                              onChanged: (v) => q.options[j] = v,
                              decoration: const InputDecoration(
                                  border: InputBorder.none, isCollapsed: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverlayLoading() {
    return Container(
      color: Colors.white.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(_processingMessage,
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _cancelToken?.cancel();
                setState(() {
                  _isGeneratingQuestions = false;
                  _isProcessingSource = false;
                });
              },
              child: const Text('Cancel Operation'),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _formHeader(String text) {
    return Text(text,
        style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: WebColors.textTertiary));
  }
}

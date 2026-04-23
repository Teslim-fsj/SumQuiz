import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sumquiz/models/local_quiz_question.dart';

/// Configuration for exam PDF generation.
class ExamPdfConfig {
  final String schoolName;
  final String examTitle;
  final String subject;
  final String classLevel;
  final int durationMinutes;
  final String? shareCode;

  // Marks per section
  final int marksA; // MCQ / True-False
  final int marksB; // Short Answer
  final int marksC; // Theory / Essay

  // Options
  final bool includeAnswerSheet;
  final bool includeMarkingScheme;
  final bool randomizeQuestions;
  final bool randomizeOptions;

  const ExamPdfConfig({
    required this.schoolName,
    required this.examTitle,
    required this.subject,
    required this.classLevel,
    required this.durationMinutes,
    this.shareCode,
    this.marksA = 2,
    this.marksB = 5,
    this.marksC = 10,
    this.includeAnswerSheet = true,
    this.includeMarkingScheme = true,
    this.randomizeQuestions = false,
    this.randomizeOptions = false,
  });

  int totalMarks(List<LocalQuizQuestion> questions) {
    int total = 0;
    for (final q in questions) {
      if (_isSectionA(q)) {
        total += marksA;
      } else if (_isSectionB(q)) {
        total += marksB;
      } else {
        total += marksC;
      }
    }
    return total;
  }
}

bool _isSectionA(LocalQuizQuestion q) =>
    q.questionType == 'Multiple Choice' || q.questionType == 'True/False';

bool _isSectionB(LocalQuizQuestion q) => q.questionType == 'Short Answer';

bool _isSectionC(LocalQuizQuestion q) =>
    q.questionType == 'Theory' ||
    q.questionType == 'Essay' ||
    (!_isSectionA(q) && !_isSectionB(q));

/// Generates professional, print-ready exam PDF documents.
///
/// This service is shared between the web and mobile export paths
/// to ensure consistent output across platforms.
class ExamPdfGenerator {
  // ─── Typography Constants ───
  static const double _titleSize = 18.0;
  static const double _headerMetaSize = 10.0;
  static const double _sectionTitleSize = 11.0;
  static const double _questionSize = 11.0;
  static const double _optionSize = 10.0;
  static const double _smallSize = 9.0;
  static const double _tinySize = 8.0;

  // ─── Spacing Constants ───
  static const double _questionSpacing = 5.0;
  static const double _sectionSpacing = 10.0;
  static const double _optionSpacing = 0.5;
  static const double _answerLineHeight = 14.0;

  // ─── Page format ───
  static const _pageMargin = pw.EdgeInsets.all(36); // ~1.27cm / 0.5in

  /// Generates the student exam paper.
  pw.Document generateStudentPaper({
    required List<LocalQuizQuestion> questions,
    required ExamPdfConfig config,
  }) {
    final doc = pw.Document(
      title: config.examTitle,
      author: config.schoolName,
      subject: config.subject,
    );

    // Sort questions into sections
    var allQuestions = List<LocalQuizQuestion>.from(questions);
    if (config.randomizeQuestions) allQuestions.shuffle();

    final sectionA = allQuestions.where(_isSectionA).toList();
    final sectionB = allQuestions.where(_isSectionB).toList();
    final sectionC = allQuestions.where(_isSectionC).toList();

    // Optionally shuffle MCQ options
    final processedA = config.randomizeOptions ? _shuffleOptions(sectionA) : sectionA;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: _pageMargin,
        footer: (pw.Context context) => _buildFooter(context, config),
        header: (pw.Context context) =>
            _buildPageHeader(context, config, isFirstPage: context.pageNumber == 1, questions: allQuestions),
        build: (pw.Context context) {
          final List<pw.Widget> content = [];
          int globalIndex = 0;

          // SECTION A - Objective
          if (processedA.isNotEmpty) {
            content.add(_buildSectionTitle(
                'SECTION A – OBJECTIVE (${processedA.length * config.marksA} MARKS)'));
            content.add(pw.SizedBox(height: 6));
            content.add(pw.Text(
                'Choose the correct option for each question.',
                style: pw.TextStyle(fontSize: _smallSize, fontStyle: pw.FontStyle.italic)));
            content.add(pw.SizedBox(height: 8));
            for (final q in processedA) {
              globalIndex++;
              content.add(_buildMCQQuestion(globalIndex, q, config.marksA));
            }
            content.add(pw.SizedBox(height: _sectionSpacing));
          }

          // SECTION B - Short Answer
          if (sectionB.isNotEmpty) {
            content.add(_buildSectionTitle(
                'SECTION B – SHORT ANSWER (${sectionB.length * config.marksB} MARKS)'));
            content.add(pw.SizedBox(height: 6));
            content.add(pw.Text(
                'Answer each question in the spaces provided.',
                style: pw.TextStyle(fontSize: _smallSize, fontStyle: pw.FontStyle.italic)));
            content.add(pw.SizedBox(height: 8));
            for (final q in sectionB) {
              globalIndex++;
              content.add(_buildShortAnswerQuestion(globalIndex, q, config.marksB));
            }
            content.add(pw.SizedBox(height: _sectionSpacing));
          }

          // SECTION C - Theory / Essay
          if (sectionC.isNotEmpty) {
            content.add(_buildSectionTitle(
                'SECTION C – THEORY / ESSAY (${sectionC.length * config.marksC} MARKS)'));
            content.add(pw.SizedBox(height: 6));
            content.add(pw.Text(
                'Answer the following questions in detail.',
                style: pw.TextStyle(fontSize: _smallSize, fontStyle: pw.FontStyle.italic)));
            content.add(pw.SizedBox(height: 8));
            for (final q in sectionC) {
              globalIndex++;
              content.add(_buildTheoryQuestion(globalIndex, q, config.marksC));
            }
          }

          return content;
        },
      ),
    );

    // Optional: Answer Sheet page
    if (config.includeAnswerSheet) {
      _addAnswerSheetPage(doc, processedA, sectionB, sectionC, config);
    }

    return doc;
  }

  /// Generates the teacher marking scheme as a separate document.
  pw.Document generateMarkingScheme({
    required List<LocalQuizQuestion> questions,
    required ExamPdfConfig config,
  }) {
    final doc = pw.Document(
      title: '${config.examTitle} – Marking Scheme',
      author: config.schoolName,
    );

    final sectionA = questions.where(_isSectionA).toList();
    final sectionB = questions.where(_isSectionB).toList();
    final sectionC = questions.where(_isSectionC).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: _pageMargin,
        footer: (pw.Context context) => _buildFooter(context, config, isMarkingScheme: true),
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(config.schoolName.toUpperCase(),
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('CONFIDENTIAL – FOR TEACHER USE ONLY',
                    style: pw.TextStyle(
                        fontSize: _tinySize,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red700)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('${config.examTitle} – MARKING SCHEME & ANSWER KEY',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Row(children: [
              pw.Text('Subject: ${config.subject}  |  Class: ${config.classLevel}  |  Total Marks: ${config.totalMarks(questions)}',
                  style: const pw.TextStyle(fontSize: _headerMetaSize)),
            ]),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.0),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (pw.Context context) {
          final List<pw.Widget> content = [];
          int globalIndex = 0;

          // SECTION A Answers
          if (sectionA.isNotEmpty) {
            content.add(pw.Text('SECTION A – OBJECTIVE ANSWERS',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _sectionTitleSize)));
            content.add(pw.SizedBox(height: 8));

            // Table format for MCQ answers
            final tableData = <List<String>>[
              ['Q#', 'Answer', 'Letter', 'Marks'],
            ];
            for (int i = 0; i < sectionA.length; i++) {
              globalIndex++;
              final q = sectionA[i];
              final letterIdx = q.options.indexOf(q.correctAnswer);
              final letter = letterIdx >= 0 ? String.fromCharCode(65 + letterIdx) : '—';
              tableData.add([
                '$globalIndex',
                q.correctAnswer,
                letter,
                '${config.marksA}',
              ]);
            }

            content.add(pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _smallSize),
              cellStyle: const pw.TextStyle(fontSize: _smallSize),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellAlignment: pw.Alignment.centerLeft,
              data: tableData,
            ));
            content.add(pw.SizedBox(height: _sectionSpacing));
          }

          // SECTION B Answers
          if (sectionB.isNotEmpty) {
            content.add(pw.Text('SECTION B – SHORT ANSWER',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _sectionTitleSize)));
            content.add(pw.SizedBox(height: 8));
            for (int i = 0; i < sectionB.length; i++) {
              globalIndex++;
              final q = sectionB[i];
              content.add(pw.Partition(
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.RichText(text: pw.TextSpan(children: [
                        pw.TextSpan(
                            text: '$globalIndex. ',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _optionSize)),
                        pw.TextSpan(
                            text: q.question,
                            style: const pw.TextStyle(fontSize: _optionSize)),
                      ])),
                      pw.SizedBox(height: 3),
                      pw.Text('Expected Answer: ${q.correctAnswer}',
                          style: pw.TextStyle(fontSize: _optionSize, color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                      if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('Note: ${q.explanation}',
                            style: pw.TextStyle(fontSize: _smallSize, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                      ],
                      pw.Divider(thickness: 0.3, color: PdfColors.grey300),
                    ],
                  ),
                ),
              ));
            }
            content.add(pw.SizedBox(height: _sectionSpacing));
          }

          // SECTION C Answers
          if (sectionC.isNotEmpty) {
            content.add(pw.Text('SECTION C – THEORY / ESSAY',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _sectionTitleSize)));
            content.add(pw.SizedBox(height: 8));
            for (int i = 0; i < sectionC.length; i++) {
              globalIndex++;
              final q = sectionC[i];
              content.add(pw.Partition(
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.5, color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.RichText(text: pw.TextSpan(children: [
                        pw.TextSpan(
                            text: '$globalIndex. ',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _optionSize)),
                        pw.TextSpan(
                            text: q.question,
                            style: const pw.TextStyle(fontSize: _optionSize)),
                        pw.TextSpan(
                            text: '  (${config.marksC} Marks)',
                            style: pw.TextStyle(fontSize: _smallSize, fontWeight: pw.FontWeight.bold)),
                      ])),
                      pw.SizedBox(height: 4),
                      pw.Text('Expected Key Points:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _smallSize, color: PdfColors.green800)),
                      pw.SizedBox(height: 2),
                      pw.Text(q.correctAnswer,
                          style: const pw.TextStyle(fontSize: _smallSize, color: PdfColors.green800)),
                      if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('Marking Guide: ${q.explanation}',
                            style: pw.TextStyle(fontSize: _smallSize, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                      ],
                    ],
                  ),
                ),
              ));
            }
          }

          return content;
        },
      ),
    );

    return doc;
  }

  // ═══════════════════════════════════════════════════════════════════
  // PAGE HEADER
  // ═══════════════════════════════════════════════════════════════════

  pw.Widget _buildPageHeader(
    pw.Context context,
    ExamPdfConfig config, {
    required bool isFirstPage,
    required List<LocalQuizQuestion> questions,
  }) {
    if (!isFirstPage) {
      // Compact header for subsequent pages
      return pw.Column(children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(config.schoolName.toUpperCase(),
                style: pw.TextStyle(
                    fontSize: _headerMetaSize,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600)),
            pw.Text('${config.subject}  |  ${config.classLevel}',
                style: const pw.TextStyle(
                    fontSize: _headerMetaSize, color: PdfColors.grey600)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
        pw.SizedBox(height: 4),
      ]);
    }

    // Full first-page header
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // School name
        pw.Center(
          child: pw.Text(config.schoolName.toUpperCase(),
              style: pw.TextStyle(fontSize: _titleSize, fontWeight: pw.FontWeight.bold)),
        ),
        if (config.examTitle.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(config.examTitle.toUpperCase(),
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          ),
        ],
        pw.SizedBox(height: 8),

        // Metadata row
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Left column: exam details
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      _headerMetaLine('SUBJECT', config.subject.toUpperCase()),
                      pw.SizedBox(width: 20),
                      _headerMetaLine('CLASS', config.classLevel.toUpperCase()),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    children: [
                      _headerMetaLine('DATE', '____________________'),
                      pw.SizedBox(width: 20),
                      _headerMetaLine('TIME ALLOWED', '${config.durationMinutes} MIN'),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  _headerMetaLine('TOTAL MARKS', '${config.totalMarks(questions)}'),
                  pw.SizedBox(height: 6),
                  pw.Text('STUDENT NAME: _____________________________________________',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _headerMetaSize)),
                  pw.SizedBox(height: 3),
                  pw.Text('CANDIDATE NO: ___________________',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _headerMetaSize)),
                ],
              ),
            ),

            // Right column: QR code
            if (config.shareCode != null)
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Scan to Practice Online',
                        style: pw.TextStyle(fontSize: _tinySize, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      height: 60,
                      width: 60,
                      child: pw.BarcodeWidget(
                        color: PdfColors.black,
                        barcode: pw.Barcode.qrCode(),
                        data: 'https://sumquiz.xyz/s/${config.shareCode}',
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('sumquiz.xyz/s/${config.shareCode}',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.blue800)),
                  ],
                ),
              ),
          ],
        ),

        pw.SizedBox(height: 8),

        // Instructions box
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('INSTRUCTIONS:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _headerMetaSize)),
              pw.SizedBox(height: 2),
              pw.Text('1. Answer ALL questions in the spaces provided.',
                  style: const pw.TextStyle(fontSize: _smallSize)),
              pw.Text('2. Section A carries ${config.marksA} mark${config.marksA > 1 ? 's' : ''} each.',
                  style: const pw.TextStyle(fontSize: _smallSize)),
              pw.Text('3. Section B carries ${config.marksB} marks each.',
                  style: const pw.TextStyle(fontSize: _smallSize)),
              pw.Text('4. Section C carries ${config.marksC} marks each.',
                  style: const pw.TextStyle(fontSize: _smallSize)),
              pw.Text('5. Ensure all answers are legible.',
                  style: const pw.TextStyle(fontSize: _smallSize)),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _headerMetaLine(String label, String value) {
    return pw.Row(children: [
      pw.Text('$label: ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _headerMetaSize)),
      pw.Text(value, style: const pw.TextStyle(fontSize: _headerMetaSize)),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // FOOTER
  // ═══════════════════════════════════════════════════════════════════

  pw.Widget _buildFooter(pw.Context context, ExamPdfConfig config, {bool isMarkingScheme = false}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            isMarkingScheme ? 'MARKING SCHEME – CONFIDENTIAL' : 'Generated by SumQuiz – sumquiz.xyz',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey500,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SECTION TITLE
  // ═══════════════════════════════════════════════════════════════════

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(
          top: pw.BorderSide(width: 1.2),
          bottom: pw.BorderSide(width: 1.2),
        ),
      ),
      width: double.infinity,
      child: pw.Text(title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _sectionTitleSize)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // QUESTION BUILDERS
  // ═══════════════════════════════════════════════════════════════════

  /// MCQ / True-False question with options.
  pw.Widget _buildMCQQuestion(int number, LocalQuizQuestion q, int marks) {
    return pw.Partition(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(bottom: _questionSpacing),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('$number. ',
                    style: pw.TextStyle(fontSize: _questionSize, fontWeight: pw.FontWeight.bold)),
                pw.Expanded(
                  child: pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(
                          text: q.question,
                          style: const pw.TextStyle(fontSize: _questionSize)),
                    ]),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 18),
              child: pw.Wrap(
                spacing: 15,
                runSpacing: 2,
                children: q.options.asMap().entries.map((entry) {
                  final letter = String.fromCharCode(65 + entry.key);
                  // Estimate if option is short enough for multi-column
                  final bool isShort = entry.value.length < 25;
                  return pw.Container(
                    width: isShort ? 120 : null,
                    padding: const pw.EdgeInsets.only(bottom: _optionSpacing),
                    child: pw.Text('$letter. ${entry.value}',
                        style: const pw.TextStyle(fontSize: _optionSize)),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Short Answer question with ruled lines.
  pw.Widget _buildShortAnswerQuestion(int number, LocalQuizQuestion q, int marks) {
    return pw.Partition(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(bottom: _questionSpacing),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('$number. ',
                    style: pw.TextStyle(fontSize: _questionSize, fontWeight: pw.FontWeight.bold)),
                pw.Expanded(
                  child: pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(
                          text: q.question,
                          style: const pw.TextStyle(fontSize: _questionSize)),
                      pw.TextSpan(
                          text: '  ($marks Marks)',
                          style: pw.TextStyle(
                              fontSize: _smallSize,
                              fontWeight: pw.FontWeight.bold,
                              fontStyle: pw.FontStyle.italic)),
                    ]),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            // 2 ruled answer lines
            for (int i = 0; i < 2; i++)
              pw.Container(
                margin: const pw.EdgeInsets.only(left: 18, bottom: 2),
                height: _answerLineHeight,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Theory / Essay question with bordered writing area.
  pw.Widget _buildTheoryQuestion(int number, LocalQuizQuestion q, int marks) {
    return pw.Partition(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(bottom: _questionSpacing + 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('$number. ',
                    style: pw.TextStyle(fontSize: _questionSize, fontWeight: pw.FontWeight.bold)),
                pw.Expanded(
                  child: pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(
                          text: q.question,
                          style: const pw.TextStyle(fontSize: _questionSize)),
                      pw.TextSpan(
                          text: '  ($marks Marks)',
                          style: pw.TextStyle(
                              fontSize: _smallSize,
                              fontWeight: pw.FontWeight.bold,
                              fontStyle: pw.FontStyle.italic)),
                    ]),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            // 4 ruled lines for essay (reduced from 6 for compactness)
            for (int i = 0; i < 4; i++)
              pw.Container(
                margin: const pw.EdgeInsets.only(left: 18, bottom: 2),
                height: _answerLineHeight,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ANSWER SHEET
  // ═══════════════════════════════════════════════════════════════════

  void _addAnswerSheetPage(
    pw.Document doc,
    List<LocalQuizQuestion> sectionA,
    List<LocalQuizQuestion> sectionB,
    List<LocalQuizQuestion> sectionC,
    ExamPdfConfig config,
  ) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: _pageMargin,
        footer: (pw.Context context) => _buildFooter(context, config),
        header: (pw.Context context) => pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(config.schoolName.toUpperCase(),
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('ANSWER KEY',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text('${config.subject} – ${config.classLevel} – ${config.examTitle}',
              style: const pw.TextStyle(fontSize: _headerMetaSize)),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 8),
        ]),
        build: (pw.Context context) {
          final List<pw.Widget> content = [];
          int globalIndex = 0;

          // Section A answers in grid format
          if (sectionA.isNotEmpty) {
            content.add(pw.Text('SECTION A – OBJECTIVE',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _sectionTitleSize)));
            content.add(pw.SizedBox(height: 8));

            final tableData = <List<String>>[
              ['Q#', 'Letter', 'Answer', 'Marks'],
            ];
            for (int i = 0; i < sectionA.length; i++) {
              globalIndex++;
              final q = sectionA[i];
              final idx = q.options.indexOf(q.correctAnswer);
              final letter = idx >= 0 ? String.fromCharCode(65 + idx) : '—';
              tableData.add(['$globalIndex', letter, q.correctAnswer, '${config.marksA}']);
            }

            content.add(pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _smallSize),
              cellStyle: const pw.TextStyle(fontSize: _smallSize),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellAlignment: pw.Alignment.centerLeft,
              data: tableData,
            ));
            content.add(pw.SizedBox(height: _sectionSpacing));
          }

          // Section B answers
          if (sectionB.isNotEmpty) {
            content.add(pw.Text('SECTION B – SHORT ANSWER',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _sectionTitleSize)));
            content.add(pw.SizedBox(height: 8));
            for (int i = 0; i < sectionB.length; i++) {
              globalIndex++;
              final q = sectionB[i];
              content.add(pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$globalIndex. ${q.correctAnswer}',
                        style: pw.TextStyle(fontSize: _optionSize, color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                    if (q.explanation != null && q.explanation!.isNotEmpty)
                      pw.Text('   ${q.explanation}',
                          style: pw.TextStyle(fontSize: _smallSize, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                  ],
                ),
              ));
            }
            content.add(pw.SizedBox(height: _sectionSpacing));
          }

          // Section C answers
          if (sectionC.isNotEmpty) {
            content.add(pw.Text('SECTION C – THEORY / ESSAY',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _sectionTitleSize)));
            content.add(pw.SizedBox(height: 8));
            for (int i = 0; i < sectionC.length; i++) {
              globalIndex++;
              final q = sectionC[i];
              content.add(pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5, color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$globalIndex. Expected Answer (${config.marksC} marks):',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: _optionSize)),
                    pw.SizedBox(height: 2),
                    pw.Text(q.correctAnswer,
                        style: const pw.TextStyle(fontSize: _smallSize, color: PdfColors.green800)),
                    if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text('Marking Guide: ${q.explanation}',
                          style: pw.TextStyle(fontSize: _smallSize, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                    ],
                  ],
                ),
              ));
            }
          }

          return content;
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════

  List<LocalQuizQuestion> _shuffleOptions(List<LocalQuizQuestion> questions) {
    return questions.map((q) {
      if (q.questionType == 'Multiple Choice' && q.options.length > 1) {
        final opts = List<String>.from(q.options)..shuffle();
        return q.copyWith(options: opts);
      }
      return q;
    }).toList();
  }
}

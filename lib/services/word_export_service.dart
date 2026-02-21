// Since Flutter doesn't have a direct way to create .docx files without external packages,
// and adding such packages would complicate the project, we'll create a simple RTF (Rich Text Format)
// file that can be opened in Word and other word processors.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import '../models/local_summary.dart';
import '../models/local_quiz.dart';
import '../models/local_flashcard_set.dart';

class WordExportService {
  static final WordExportService _instance = WordExportService._internal();
  factory WordExportService() => _instance;
  WordExportService._internal();

  Future<String> exportSummary(LocalSummary summary) async {
    // Check if user can export (Pro users can always export)
    final isPro = await _isUserPro(summary.userId);
    if (!isPro) {
      throw Exception(
          'Word export is only available for Pro users. Upgrade to unlock this feature.');
    }

    // Create RTF content
    final rtfContent = '''
{\\rtf1\\ansi\\ansicpg1252\\deff0\\nouicompat
{\\fonttbl{\\f0\\fnil\\fcharset0 Calibri;}}
{\\colortbl ;\\red0\\green0\\blue0;}
\\viewkind4\\uc1
\\pard\\sa200\\sl276\\slmult1\\f0\\fs22\\lang9\\b\\fs28 Summary\\b0\\par
\\pard\\sa200\\sl276\\slmult1 ${_escapeRtf(summary.content)}\\par
}
''';

    // Get directory for saving the file
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/summary_${summary.id}.rtf';

    // Write the file
    final file = File(filePath);
    await file.writeAsString(rtfContent);

    return filePath;
  }

  /// Check if user has Pro access
  Future<bool> _isUserPro(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      // Check for 'subscriptionExpiry' field
      if (data.containsKey('subscriptionExpiry')) {
        // Lifetime access is handled by a null expiry date
        if (data['subscriptionExpiry'] == null) return true;

        final expiryDate = (data['subscriptionExpiry'] as Timestamp).toDate();
        return expiryDate.isAfter(DateTime.now());
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String> exportQuiz(LocalQuiz quiz) async {
    // Check if user can export (Pro users can always export)
    final isPro = await _isUserPro(quiz.userId);
    if (!isPro) {
      throw Exception(
          'Word export is only available for Pro users. Upgrade to unlock this feature.');
    }

    // Create RTF content
    final buffer = StringBuffer();
    buffer.writeln('{\\rtf1\\ansi\\ansicpg1252\\deff0\\nouicompat');
    buffer.writeln('{\\fonttbl{\\f0\\fnil\\fcharset0 Calibri;}}');
    buffer.writeln('{\\colortbl ;\\red0\\green0\\blue0;}');
    buffer.writeln('\\viewkind4\\uc1');
    buffer.writeln(
        '\\pard\\sa200\\sl276\\slmult1\\f0\\fs22\\lang9\\b\\fs28 ${_escapeRtf(quiz.title)}\\b0\\par');
    buffer.writeln();

    for (int i = 0; i < quiz.questions.length; i++) {
      final question = quiz.questions[i];

      // Question
      buffer.writeln(
          '\\pard\\sa200\\sl276\\slmult1\\b Question ${i + 1}: ${_escapeRtf(question.question)}\\b0\\par');

      // Options
      for (int j = 0; j < question.options.length; j++) {
        buffer.writeln(
            '\\pard\\sa200\\sl276\\slmult1\\tx220\\tab ${String.fromCharCode(65 + j)}. ${_escapeRtf(question.options[j])}\\par');
      }

      buffer.writeln();
    }

    buffer.writeln('}');

    // Get directory for saving the file
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/quiz_${quiz.id}.rtf';

    // Write the file
    final file = File(filePath);
    await file.writeAsString(buffer.toString());

    return filePath;
  }

  Future<String> exportFlashcardSet(LocalFlashcardSet flashcardSet) async {
    // Check if user can export (Pro users can always export)
    final isPro = await _isUserPro(flashcardSet.userId);
    if (!isPro) {
      throw Exception(
          'Word export is only available for Pro users. Upgrade to unlock this feature.');
    }

    // Create RTF content
    final buffer = StringBuffer();
    buffer.writeln('{\\rtf1\\ansi\\ansicpg1252\\deff0\\nouicompat');
    buffer.writeln('{\\fonttbl{\\f0\\fnil\\fcharset0 Calibri;}}');
    buffer.writeln('{\\colortbl ;\\red0\\green0\\blue0;}');
    buffer.writeln('\\viewkind4\\uc1');
    buffer.writeln(
        '\\pard\\sa200\\sl276\\slmult1\\f0\\fs22\\lang9\\b\\fs28 ${_escapeRtf(flashcardSet.title)}\\b0\\par');
    buffer.writeln();

    for (int i = 0; i < flashcardSet.flashcards.length; i++) {
      final flashcard = flashcardSet.flashcards[i];

      // Question
      buffer.writeln(
          '\\pard\\sa200\\sl276\\slmult1\\b Question ${i + 1}:\\b0\\par');
      buffer.writeln(
          '\\pard\\sa200\\sl276\\slmult1 ${_escapeRtf(flashcard.question)}\\par');

      // Answer
      buffer.writeln('\\pard\\sa200\\sl276\\slmult1\\b Answer:\\b0\\par');
      buffer.writeln(
          '\\pard\\sa200\\sl276\\slmult1 ${_escapeRtf(flashcard.answer)}\\par');

      buffer.writeln();
    }

    buffer.writeln('}');

    // Get directory for saving the file
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/flashcards_${flashcardSet.id}.rtf';

    // Write the file
    final file = File(filePath);
    await file.writeAsString(buffer.toString());

    return filePath;
  }

  String _escapeRtf(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}');
  }
}

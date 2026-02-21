import 'package:share_plus/share_plus.dart';
import 'dart:developer' as developer;

import '../models/local_summary.dart';
import '../models/local_quiz.dart';
import '../models/local_flashcard_set.dart';
import 'pdf_export_service.dart';

class SharingService {
  final PdfExportService _pdfExportService = PdfExportService();

  Future<void> shareSummary(LocalSummary summary) async {
    try {
      final pdfPath = await _pdfExportService.exportSummary(summary);
      await Share.shareXFiles([XFile(pdfPath)],
          text: 'Here is the summary you requested!');
    } catch (e, s) {
      developer.log(
        'Error sharing summary',
        name: 'SharingService',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> shareQuiz(LocalQuiz quiz) async {
    try {
      final pdfPath = await _pdfExportService.exportQuiz(quiz);
      await Share.shareXFiles([XFile(pdfPath)],
          text: 'Here is the quiz you requested!');
    } catch (e, s) {
      developer.log(
        'Error sharing quiz',
        name: 'SharingService',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> shareFlashcardSet(LocalFlashcardSet flashcardSet) async {
    try {
      final pdfPath = await _pdfExportService.exportFlashcardSet(flashcardSet);
      await Share.shareXFiles([XFile(pdfPath)],
          text: 'Here are the flashcards you requested!');
    } catch (e, s) {
      developer.log(
        'Error sharing flashcard set',
        name: 'SharingService',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> shareText(String text) async {
    try {
      await Share.share(text);
    } catch (e, s) {
      developer.log(
        'Error sharing text',
        name: 'SharingService',
        error: e,
        stackTrace: s,
      );
    }
  }
}

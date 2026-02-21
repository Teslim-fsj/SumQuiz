// Helper method to share a library item
import 'package:flutter/material.dart';
import 'package:sumquiz/models/library_item.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/utils/share_code_generator.dart';
import 'package:sumquiz/views/widgets/share_deck_dialog.dart';
import 'package:uuid/uuid.dart';

class LibraryShareHelper {
  static Future<void> shareLibraryItem(
    BuildContext context,
    LibraryItem item,
    UserModel user,
  ) async {
    try {
      final db = LocalDatabaseService();

      // Fetch the actual content
      dynamic content;
      Map<String, dynamic> summaryData = {};
      Map<String, dynamic> quizData = {};
      Map<String, dynamic> flashcardData = {};

      switch (item.type) {
        case LibraryItemType.summary:
          final summary = await db.getSummary(item.id);
          if (summary != null) {
            summaryData = {
              'content': summary.content,
              'tags': summary.tags,
            };
          }
          break;
        case LibraryItemType.quiz:
          final quiz = await db.getQuiz(item.id);
          if (quiz != null) {
            quizData = {
              'questions': quiz.questions.map((q) => q.toMap()).toList(),
            };
          }
          break;
        case LibraryItemType.flashcards:
          final flashcardSet = await db.getFlashcardSet(item.id);
          if (flashcardSet != null) {
            flashcardData = {
              'flashcards':
                  flashcardSet.flashcards.map((f) => f.toMap()).toList(),
            };
          }
          break;
      }

      final shareCode = ShareCodeGenerator.generate();
      final publicDeckId = const Uuid().v4();

      final publicDeck = PublicDeck(
        id: publicDeckId,
        creatorId: user.uid,
        creatorName: user.displayName,
        title: item.title,
        description: "Shared ${item.type.toString().split('.').last}",
        shareCode: shareCode,
        summaryData: summaryData,
        quizData: quizData,
        flashcardData: flashcardData,
        publishedAt: DateTime.now(),
      );

      await FirestoreService().publishDeck(publicDeck);

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => ShareDeckDialog(
            shareCode: shareCode,
            deckTitle: item.title,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }
}

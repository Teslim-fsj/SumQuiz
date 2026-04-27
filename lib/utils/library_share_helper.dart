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
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LibraryShareHelper {
  static Future<void> shareLibraryItem(
    BuildContext context,
    LibraryItem item,
    UserModel user,
  ) async {
    try {
      final db = LocalDatabaseService();

      // Fetch the actual content
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
        case LibraryItemType.exam:
          // TODO: handle sharing exams if needed
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

      final publishedDeck = await FirestoreService().publishDeck(publicDeck);

      if (context.mounted) {
        final origin = kIsWeb ? Uri.base.origin : 'https://sumquiz.xyz';
        final shareLink = (publishedDeck.slug != null && publishedDeck.slug!.isNotEmpty)
            ? '$origin/s/${publishedDeck.slug}'
            : '$origin/deck?code=$shareCode';

        final String message = user.role == UserRole.student
            ? 'I just finished "${item.title}" on SumQuiz! Can you beat my score? Check it out here: $shareLink'
            : 'Check out this study pack I created on SumQuiz: "${item.title}". Access it here: $shareLink';

        await Share.share(message, subject: 'SumQuiz: ${item.title}');
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

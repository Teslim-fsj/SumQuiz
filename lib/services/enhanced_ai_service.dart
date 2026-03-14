import 'dart:async';

import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'dart:developer' as developer;

import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:sumquiz/services/usage_service.dart' as usage;
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'ai/ai_config.dart';

import 'ai/youtube_ai_service.dart';
import 'ai/web_ai_service.dart';
import 'ai/generator_ai_service.dart';
import 'ai/ai_types.dart';
import 'package:uuid/uuid.dart';
import 'package:sumquiz/models/folder.dart';
import 'package:sumquiz/services/spaced_repetition_service.dart';
import 'package:sumquiz/services/sync_service.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/local_flashcard.dart';
export 'ai/ai_types.dart';

// --- EXCEPTIONS moved to ai_types.dart ---

class EnhancedAIService {
  final YouTubeAIService _youtubeService = YouTubeAIService();
  final WebAIService _webService = WebAIService();
  final GeneratorAIService _generatorService = GeneratorAIService();

  EnhancedAIService({required IAPService iapService}) {
    // Initialize services immediately
    _initializeServices();
  }

  void _initializeServices() {
    // Services are already initialized in their constructors
    // but we can trigger initialization here if needed
  }

  /// Ensures all AI services are properly initialized
  Future<void> initialize() async {
    developer.log('EnhancedAIService.initialize called',
        name: 'EnhancedAIService');
    // Wait for all AI services to initialize
    await Future.wait([
      _youtubeService.ensureInitialized(),
      _webService.ensureInitialized(),
      _generatorService.ensureInitialized(),
    ]);
    developer.log('EnhancedAIService.initialize completed',
        name: 'EnhancedAIService');
  }

  Future<bool> isServiceHealthy() async {
    return await _generatorService.isServiceHealthy();
  }

  Future<void> _checkUsageLimits(String userId) async {
    developer.log('_checkUsageLimits called with userId: $userId',
        name: 'EnhancedAIService');
    try {
      // Unify with dashboard usage logic
      final usageService = usage.UsageService();
      final canProceed = await usageService.canGenerateDeck(userId);

      if (!canProceed) {
        developer.log('Usage limit reached for user: $userId',
            name: 'EnhancedAIService');
        throw EnhancedAIServiceException(
            'Daily generation limit reached. Upgrade to Pro for unlimited access.',
            code: 'USAGE_LIMIT_REACHED');
      }
      developer.log('Usage limits check passed for user: $userId',
          name: 'EnhancedAIService');
    } catch (e, stack) {
      developer.log('Error checking usage limits',
          name: 'EnhancedAIService', error: e, stackTrace: stack);
      throw EnhancedAIServiceException('Error checking usage limits: $e');
    }
  }

  // --- PUBLIC API ---

  Future<Result<ExtractionResult>> analyzeYouTubeVideo(String videoUrl,
      {required String userId, CancellationToken? cancelToken}) async {
    await _checkUsageLimits(userId);
    return _youtubeService.analyzeVideo(videoUrl, cancelToken: cancelToken);
  }

  Future<Result<ExtractionResult>> extractWebpageContent(
      {required String url,
      required String userId,
      CancellationToken? cancelToken}) async {
    await _checkUsageLimits(userId);
    return _webService.extractWebpage(url, cancelToken: cancelToken);
  }

  Future<String> refineContent(String rawText,
      {CancellationToken? cancelToken}) async {
    return _generatorService.refineContent(rawText, cancelToken: cancelToken);
  }

  Future<LocalSummary> generateSummary({
    required String text,
    required String userId,
    String depth = 'intermediate',
    void Function(String)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    onProgress?.call('Generating summary...');
    return _generatorService.generateSummary(text,
        userId: userId, cancelToken: cancelToken);
  }

  Future<LocalQuiz> generateQuiz({
    required String text,
    required String userId,
    int questionCount = 10,
    void Function(String)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    onProgress?.call('Generating quiz...');
    return _generatorService.generateQuiz(text,
        userId: userId, questionCount: questionCount, cancelToken: cancelToken);
  }

  Future<LocalFlashcardSet> generateFlashcards({
    required String text,
    required String userId,
    int cardCount = 15,
    void Function(String)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    onProgress?.call('Generating flashcards...');
    return _generatorService.generateFlashcards(text,
        userId: userId, cardCount: cardCount, cancelToken: cancelToken);
  }

  Future<LocalQuiz> generateExam({
    required String text,
    required String title,
    required String subject,
    required String level,
    required int questionCount,
    required List<String> questionTypes,
    required double difficultyMix,
    required String userId,
    void Function(String)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    await _checkUsageLimits(userId);
    onProgress?.call('Generating formal exam paper...');
    return _generatorService.generateExam(
      text: text,
      title: title,
      subject: subject,
      level: level,
      questionCount: questionCount,
      questionTypes: questionTypes,
      difficultyMix: difficultyMix,
      userId: userId,
      cancelToken: cancelToken,
    );
  }

  Future<Result<ExtractionResult>> analyzeContentFromUrl({
    required String url,
    required String mimeType,
    String? customPrompt,
    required String userId,
    CancellationToken? cancelToken,
  }) async {
    developer.log(
        'analyzeContentFromUrl called with URL: $url, mimeType: $mimeType',
        name: 'EnhancedAIService');
    try {
      await _checkUsageLimits(userId);
      try {
        cancelToken?.throwIfCancelled();
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));

        cancelToken?.throwIfCancelled();

        if (response.statusCode != 200) {
          developer.log(
              'Failed to download file. Status: ${response.statusCode}',
              name: 'EnhancedAIService');
          return Result.error(EnhancedAIServiceException(
              'Failed to download file. Status: ${response.statusCode}'));
        }
        return analyzeContentFromBytes(
          bytes: response.bodyBytes,
          mimeType: mimeType,
          userId: userId,
          customPrompt: customPrompt,
          cancelToken: cancelToken,
        );
      } catch (e, stack) {
        if (e is CancelledException) {
          developer.log('Content analysis cancelled by user',
              name: 'EnhancedAIService');
          return Result.error(EnhancedAIServiceException(
              'Extraction cancelled by user.',
              code: 'CANCELLED'));
        }
        developer.log('Error in analyzeContentFromUrl',
            name: 'EnhancedAIService', error: e, stackTrace: stack);
        return Result.error(EnhancedAIServiceException(
            'Failed to analyze content from URL: $e'));
      }
    } catch (e, stack) {
      developer.log('Critical error in analyzeContentFromUrl',
          name: 'EnhancedAIService', error: e, stackTrace: stack);
      return Result.error(
          EnhancedAIServiceException('Critical error analyzing content: $e'));
    }
  }

  Future<Result<ExtractionResult>> analyzeContentFromBytes({
    required Uint8List bytes,
    required String mimeType,
    String? customPrompt,
    required String userId,
    CancellationToken? cancelToken,
  }) async {
    developer.log(
        'analyzeContentFromBytes called with mimeType: $mimeType, bytes length: ${bytes.length}',
        name: 'EnhancedAIService');
    try {
      await _checkUsageLimits(userId);
      await initialize();

      try {
        cancelToken?.throwIfCancelled();
        if (bytes.isEmpty) {
          developer.log('File data is empty', name: 'EnhancedAIService');
          return Result.error(EnhancedAIServiceException('File data is empty.',
              code: 'EMPTY_FILE'));
        }

        String prompt = customPrompt ??
            (mimeType.startsWith('audio/')
                ? 'Accurately transcribe and extract all educational content from this audio file.'
                : 'Extract all educational and informational content from this file.');

        // Pass actual bytes to Gemini using the new generateWithData method
        final response = await _generatorService.generateWithData(
          prompt,
          bytes,
          mimeType,
          cancelToken: cancelToken,
          generationConfig: AIConfig.extractionGenerationConfig,
        );

        return Result.ok(ExtractionResult(
          text: response,
          suggestedTitle: 'Extracted Content',
        ));
      } catch (e, stack) {
        developer.log('Analysis failed in inner try',
            name: 'EnhancedAIService', error: e, stackTrace: stack);
        return Result.error(EnhancedAIServiceException('Analysis failed: $e',
            originalError: e));
      }
    } catch (e, stack) {
      developer.log('Critical error in analyzeContentFromBytes',
          name: 'EnhancedAIService', error: e, stackTrace: stack);
      return Result.error(EnhancedAIServiceException(
          'Critical error analyzing content: $e',
          originalError: e));
    }
  }

  Future<String> generateAndStoreOutputs({
    required String text,
    required String title,
    required List<String> requestedOutputs,
    required String userId,
    required LocalDatabaseService localDb,
    required void Function(String message) onProgress,
    CancellationToken? cancelToken,
  }) async {
    developer.log(
        'EnhancedAIService.generateAndStoreOutputs called with title: $title, userId: $userId, outputs: $requestedOutputs',
        name: 'EnhancedAIService');
    developer.log('Text length: ${text.length} chars',
        name: 'EnhancedAIService');

    // Ensure all services are initialized
    await initialize();

    onProgress('Creating folder...');
    cancelToken?.throwIfCancelled();
    final folderId = const Uuid().v4();
    final folder = Folder(
      id: folderId,
      name: title,
      userId: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await localDb.saveFolder(folder);

    final srsService =
        SpacedRepetitionService(localDb.getSpacedRepetitionBox());

    int completed = 0;
    final total = requestedOutputs.length;
    final failures = <String>[];

    try {
      for (String outputType in requestedOutputs) {
        onProgress(
            'Generating ${outputType.capitalize()} (${completed + 1}/$total)...');

        try {
          // Check if text is valid before processing
          if (text.trim().isEmpty) {
            developer.log('No content provided for generation',
                name: 'EnhancedAIService');
            throw EnhancedAIServiceException(
                'No content provided. Please provide text to generate content.',
                code: 'NO_CONTENT_PROVIDED');
          }

          developer.log('Starting generation of $outputType',
              name: 'EnhancedAIService');

          switch (outputType) {
            case 'summary':
              final summary = await _generatorService.generateSummary(text,
                  userId: userId, cancelToken: cancelToken);
              if (summary.id.isEmpty) {
                summary.id = const Uuid().v4();
              }
              await localDb.saveSummary(summary, folderId);
              break;

            case 'quiz':
              final quiz = await _generatorService.generateQuiz(text,
                  userId: userId, cancelToken: cancelToken);
              if (quiz.id.isEmpty) {
                quiz.id = const Uuid().v4();
              }
              await localDb.saveQuiz(quiz, folderId);
              break;

            case 'flashcards':
              final set = await _generatorService.generateFlashcards(text,
                  userId: userId, cancelToken: cancelToken);
              if (set.id.isEmpty) {
                set.id = const Uuid().v4();
              }
              await localDb.saveFlashcardSet(set, folderId);
              for (final card in set.flashcards) {
                await srsService.scheduleReview(card.id, userId);
              }
              break;
          }

          completed++;
          onProgress('${outputType.capitalize()} complete! ✓');
        } catch (e, stack) {
          developer.log('Failed to generate $outputType: $e',
              name: 'EnhancedAIService', error: e, stackTrace: stack);
          failures.add(outputType);
          onProgress('${outputType.capitalize()} failed - continuing...');
        }
      }

      if (completed == 0) {
        developer.log('All generation failed, cleaning up folder',
            name: 'EnhancedAIService');
        await localDb.deleteFolder(folderId);
        throw EnhancedAIServiceException(
            'Failed to generate any content. Please try again.',
            code: 'ALL_GENERATION_FAILED');
      }

      if (failures.isNotEmpty) {
        onProgress(
            'Done! ${failures.length} item(s) failed: ${failures.join(", ")}');
      } else {
        onProgress('All done! 🎉');
      }

      // Trigger sync in background
      SyncService(localDb).syncAllData();

      developer.log(
          'Generation completed successfully, returning folderId: $folderId',
          name: 'EnhancedAIService');

      return folderId;
    } catch (e, stack) {
      developer.log('Critical error in generateAndStoreOutputs',
          name: 'EnhancedAIService', error: e, stackTrace: stack);
      onProgress('Error occurred: $e. Cleaning up...');
      await localDb.deleteFolder(folderId).catchError((_) => null);
      rethrow;
    }
  }

  Future<String> generateFromTopic({
    required String topic,
    required String userId,
    required LocalDatabaseService localDb,
    String depth = 'intermediate',
    int cardCount = 15,
    void Function(String)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    await _checkUsageLimits(userId);
    onProgress?.call('Generating comprehensive study materials...');

    String? folderId;

    try {
      cancelToken?.throwIfCancelled();
      final data = await _generatorService.generateFromTopic(
        topic: topic,
        depth: depth,
        cardCount: cardCount,
        cancelToken: cancelToken,
      );

      final title = data['title']?.toString() ?? 'Study Deck';
      onProgress?.call('Creating study deck...');
      cancelToken?.throwIfCancelled();

      final folder = Folder(
        id: const Uuid().v4(),
        name: title,
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      folderId = folder.id;
      await localDb.saveFolder(folder);

      // Save Summary
      onProgress?.call('Saving summary...');
      cancelToken?.throwIfCancelled();
      final summaryData = data['summary'];
      final summaryText =
          summaryData is Map ? summaryData['content']?.toString() ?? '' : '';

      final List<String> summaryTags = [];
      if (summaryData is Map) {
        final rawTags = summaryData['tags'];
        if (rawTags is List) {
          for (final e in rawTags) {
            summaryTags.add(e.toString());
          }
        }
      }

      final summary = LocalSummary(
        id: const Uuid().v4(),
        userId: userId,
        title: title,
        content: summaryText,
        timestamp: DateTime.now(),
        tags: summaryTags,
      );
      await localDb.saveSummary(summary, folderId);

      // Save Quiz
      onProgress?.call('Saving quiz...');
      cancelToken?.throwIfCancelled();
      final quizData = data['quiz'];
      final List<LocalQuizQuestion> questions = [];
      if (quizData is List) {
        for (final q in quizData) {
          if (q is Map) {
            final rawOptions = q['options'];
            final List<String> options = [];
            if (rawOptions is List) {
              for (final o in rawOptions) {
                options.add(o.toString());
              }
            }

            final correctIndex =
                int.tryParse(q['correctIndex']?.toString() ?? '0') ?? 0;
            final correctAnswer =
                (correctIndex >= 0 && correctIndex < options.length)
                    ? options[correctIndex]
                    : (options.isNotEmpty ? options[0] : '');

            questions.add(LocalQuizQuestion(
              question: q['question']?.toString() ?? '...',
              options: options,
              correctAnswer: correctAnswer,
              explanation: q['explanation']?.toString(),
            ));
          }
        }
      }

      final quiz = LocalQuiz(
        id: const Uuid().v4(),
        userId: userId,
        title: title,
        questions: questions,
        timestamp: DateTime.now(),
      );
      await localDb.saveQuiz(quiz, folderId);

      // Save Flashcards
      onProgress?.call('Saving flashcards...');
      cancelToken?.throwIfCancelled();
      final flashcardsData = data['flashcards'];
      final List<LocalFlashcard> flashcards = [];
      if (flashcardsData is List) {
        for (final f in flashcardsData) {
          if (f is Map) {
            flashcards.add(LocalFlashcard(
              question: f['question']?.toString() ?? '...',
              answer: f['answer']?.toString() ?? '...',
            ));
          }
        }
      }

      final flashcardSet = LocalFlashcardSet(
        id: const Uuid().v4(),
        userId: userId,
        title: title,
        flashcards: flashcards,
        timestamp: DateTime.now(),
      );
      await localDb.saveFlashcardSet(flashcardSet, folderId);

      // Schedule SRS
      final srsService =
          SpacedRepetitionService(localDb.getSpacedRepetitionBox());
      for (final card in flashcards) {
        await srsService.scheduleReview(card.id, userId);
      }

      onProgress?.call('Study deck ready!');
      SyncService(localDb).syncAllData();
      return folderId;
    } catch (e) {
      developer.log('Topic generation error',
          name: 'EnhancedAIService', error: e);

      if (folderId != null) {
        onProgress?.call('Cleaning up...');
        await localDb.deleteFolder(folderId).catchError((_) => null);
      }

      if (e is CancelledException) {
        throw EnhancedAIServiceException('Generation cancelled by user.',
            code: 'CANCELLED');
      }

      throw EnhancedAIServiceException('Failed to generate study materials.',
          code: 'GENERATION_FAILED', originalError: e);
    }
  }

  Future<Map<String, dynamic>> verifyEssayAnswer({
    required String question,
    required String studentAnswer,
    required String referenceAnswer,
    CancellationToken? cancelToken,
  }) async {
    return _generatorService.verifyEssayAnswer(
      question: question,
      studentAnswer: studentAnswer,
      referenceAnswer: referenceAnswer,
      cancelToken: cancelToken,
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

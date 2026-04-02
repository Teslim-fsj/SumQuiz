import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/local_flashcard.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:uuid/uuid.dart';
import 'ai_config.dart';
import 'ai_base_service.dart';

import 'dart:developer' as developer;

class GeneratorAIService extends AIBaseService {
  Future<LocalSummary> generateSummary(String text,
      {String? userId,
      String difficulty = 'intermediate',
      CancellationToken? cancelToken}) async {
    developer.log(
        'Generating $difficulty summary for text length: ${text.length}',
        name: 'GeneratorAIService');
    final config = GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'title': Schema.string(description: 'Clear, topic-focused title'),
          'content': Schema.string(
              description: 'Detailed study guide in Markdown format'),
          'tags': Schema.array(
              items: Schema.string(), description: '3-5 relevant keywords'),
        },
        requiredProperties: ['title', 'content', 'tags'],
      ),
    );

    final prompt =
        '''Create a comprehensive, EXAM-FOCUSED study guide from the provided text.
TARGET DIFFICULTY: $difficulty (Scale your depth and terminology complexity accordingly).

OUTPUT REQUIREMENTS:
1. **Title**: A professional, topic-focused title.
2. **Content**: Use Markdown formatting for a structured study guide:
   - Use # for the main title, ## for sections, ### for sub-sections.
   - Use bold (**text**) for key terms and definitions.
   - Use bullet points (*) for lists of facts/details.
   - include equations/formulas in blocks if applicable.
3. **Structure**:
   - Start with an "Overview" section.
   - Group information into logical "Key Concepts".
   - Include a "Quick Review" or "Summary Points" section at the end.
   - Add Memory Aids/Mnemonics where helpful.
4. **Tone**: Academic, clear, and informative.

Text: $text''';

    try {
      final response = await generateWithRetry(prompt,
          customModel: educatorModel,
          generationConfig: config,
          cancelToken: cancelToken);
      developer.log('AI Response received for summary',
          name: 'GeneratorAIService');
      final jsonStr = extractJson(response);
      final data = safeJsonDecode(jsonStr);

      if (data['content'] == null || data['content'].toString().isEmpty) {
        developer.log(
            'CRITICAL: AI response missing "content" field! JSON: $jsonStr',
            name: 'GeneratorAIService',
            level: 1000);
      }

      final List<String> tags = [];
      final rawTags = data['tags'];
      if (rawTags is List) {
        for (final e in rawTags) {
          tags.add(e.toString());
        }
      }

      return LocalSummary(
        id: const Uuid().v4(),
        userId: userId ?? '',
        title: data['title']?.toString() ?? 'Study Guide',
        content: data['content']?.toString() ?? '',
        timestamp: DateTime.now(),
        tags: tags,
      );
    } catch (e, stack) {
      developer.log('Summary generation failed',
          name: 'GeneratorAIService', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<LocalQuiz> generateQuiz(String text,
      {String? userId,
      int questionCount = 10,
      String difficulty = 'intermediate',
      CancellationToken? cancelToken}) async {
    developer.log(
        'Generating $difficulty quiz ($questionCount questions) for text length: ${text.length}',
        name: 'GeneratorAIService');
    final config = GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'title': Schema.string(),
          'questions': Schema.array(
            items: Schema.object(
              properties: {
                'question': Schema.string(description: 'Exam-style question'),
                'options': Schema.array(
                    items: Schema.string(), description: '4 distinct options'),
                'correctAnswer': Schema.string(
                    description: 'The exact matching correct option'),
                'explanation': Schema.string(
                    description: 'Detailed explanation of the correct answer'),
              },
              requiredProperties: [
                'question',
                'options',
                'correctAnswer',
                'explanation'
              ],
            ),
          ),
        },
        requiredProperties: ['title', 'questions'],
      ),
    );

    final prompt =
        '''Generate a challenging $questionCount-question multiple-choice quiz based on this text.
TARGET DIFFICULTY: $difficulty

QUIZ RULES:
1. Questions must require understanding/application, not just simple name/date recall.
2. Options must be plausible distractors related to the topic.
3. Do NOT use "All of the above" or "None of the above" more than once.
4. Explanations must be thorough, explaining WHY the answer is correct and briefly why others are incorrect if applicable.

Text: $text''';

    try {
      final response = await generateWithRetry(prompt,
          customModel: educatorModel,
          generationConfig: config,
          cancelToken: cancelToken);
      developer.log('AI Response received for quiz',
          name: 'GeneratorAIService');
      final jsonStr = extractJson(response);
      final data = safeJsonDecode(jsonStr);

      final questionsData = data['questions'];
      final List<LocalQuizQuestion> questions = [];
      if (questionsData is List) {
        for (final q in questionsData) {
          if (q is Map) {
            final List<String> options = [];
            final rawOptions = q['options'];
            if (rawOptions is List) {
              for (final o in rawOptions) {
                options.add(o.toString());
              }
            }

            questions.add(LocalQuizQuestion(
              question: q['question']?.toString() ?? 'Unknown Question',
              options: options,
              correctAnswer: q['correctAnswer']?.toString() ?? '',
              explanation: q['explanation']?.toString(),
              questionType: 'Multiple Choice',
            ));
          }
        }
      }

      return LocalQuiz(
        id: const Uuid().v4(),
        userId: userId ?? '',
        title: data['title']?.toString() ?? 'Quick Quiz',
        questions: questions,
        timestamp: DateTime.now(),
      );
    } catch (e, stack) {
      developer.log('Quiz generation failed',
          name: 'GeneratorAIService', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<LocalFlashcardSet> generateFlashcards(String text,
      {String? userId,
      int cardCount = 15,
      String difficulty = 'intermediate',
      CancellationToken? cancelToken}) async {
    developer.log(
        'Generating $difficulty flashcards ($cardCount) for text length: ${text.length}',
        name: 'GeneratorAIService');
    final config = GenerationConfig(
      // ... (rest of config)
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'title': Schema.string(),
          'flashcards': Schema.array(
            items: Schema.object(
              properties: {
                'question':
                    Schema.string(description: 'Concise question or concept'),
                'answer':
                    Schema.string(description: 'Precise answer or definition'),
              },
              requiredProperties: ['question', 'answer'],
            ),
          ),
        },
        requiredProperties: ['title', 'flashcards'],
      ),
    );

    final prompt = '''Create $cardCount active-recall flashcards from the text.
TARGET DIFFICULTY: $difficulty

FLASHCARD PRINCIPLES:
- **Atomic Principle**: One question = one idea. Keep answers concise.
- **Clarity**: Use clear, unambiguous language.
- **Focus**: Target high-yield facts, crucial definitions, and pivotal concepts.
- **Variety**: Use a mix of "What is...", "How does...", and "Identify the..." style questions.

Text: $text''';

    try {
      final response = await generateWithRetry(prompt,
          customModel: educatorModel,
          generationConfig: config,
          cancelToken: cancelToken);
      developer.log('AI Response received for flashcards',
          name: 'GeneratorAIService');
      final jsonStr = extractJson(response);
      final data = safeJsonDecode(jsonStr);

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

      return LocalFlashcardSet(
        id: const Uuid().v4(),
        userId: userId ?? '',
        title: data['title']?.toString() ?? 'Flashcards',
        flashcards: flashcards,
        timestamp: DateTime.now(),
      );
    } catch (e, stack) {
      developer.log('Flashcard generation failed',
          name: 'GeneratorAIService', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<String> refineContent(String rawText,
      {CancellationToken? cancelToken}) async {
    developer.log('Refining content for text length: ${rawText.length}',
        name: 'GeneratorAIService');
    final prompt =
        '''EXTRACT and CLEAN the core factual content from the text below.
    
    CRITICAL: 
    - REMOVE: Advertisements, promotional content, menus, intros/outros, and tangents.
    - FIX: OCR errors, broken sentences, and formatting issues.
    - PRESERVE: ALL factual information, definitions, examples, formulas, and procedures verbatim.
    - ORGANIZE: Use markdown headers for logical flow.

    Text: $rawText''';

    try {
      final response = await generateWithRetry(
        prompt,
        customModel: extractorModel,
        cancelToken: cancelToken,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              'cleanedText': Schema.string(
                  description: 'The extracted and cleaned content'),
            },
            requiredProperties: ['cleanedText'],
          ),
        ),
      );
      final jsonBlock = extractJson(response);
      final data = safeJsonDecode(jsonBlock);
      return data['cleanedText']?.toString() ?? response;
    } catch (e) {
      developer.log('RefineContent error',
          name: 'GeneratorAIService', error: e);
      return rawText;
    }
  }

  Future<Map<String, dynamic>> generateFromTopic({
    required String topic,
    String depth = 'intermediate',
    int cardCount = 15,
    CancellationToken? cancelToken,
  }) async {
    developer.log(
        'Generating from topic: $topic (depth: $depth, cards: $cardCount)',
        name: 'GeneratorAIService');
    final depthInstruction = switch (depth) {
      'beginner' =>
        'Target audience: Complete beginners. Use simple language, avoid jargon.',
      'advanced' =>
        'Target audience: Advanced learners. Include nuanced details and expert-level insights.',
      _ =>
        'Target audience: Intermediate learners. Balance theory with practical examples.'
    };

    final prompt = '''Create comprehensive study materials for the topic.
    TOPIC: $topic
    LEVEL: $depthInstruction

    GENERATE:
    1. **TITLE**: Engaging title.
    2. **SUMMARY**: Structured sections with bullet points.
    3. **QUIZ**: 15 mcqs with 4 options, correctAnswer (exact string), and explanation.
    4. **FLASHCARDS**: $cardCount question-answer pairs.''';

    try {
      final response = await generateWithRetry(prompt,
          customModel: educatorModel,
          cancelToken: cancelToken,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: Schema.object(
              properties: {
                'title': Schema.string(),
                'summary': Schema.object(
                  properties: {
                    'content': Schema.string(),
                    'tags': Schema.array(items: Schema.string()),
                  },
                  requiredProperties: ['content', 'tags'],
                ),
                'quiz': Schema.array(
                  items: Schema.object(
                    properties: {
                      'question': Schema.string(),
                      'options': Schema.array(items: Schema.string()),
                      'correctAnswer': Schema.string(),
                      'explanation': Schema.string(),
                    },
                    requiredProperties: [
                      'question',
                      'options',
                      'correctAnswer',
                      'explanation'
                    ],
                  ),
                ),
                'flashcards': Schema.array(
                  items: Schema.object(
                    properties: {
                      'question': Schema.string(),
                      'answer': Schema.string(),
                    },
                    requiredProperties: ['question', 'answer'],
                  ),
                ),
              },
              requiredProperties: ['title', 'summary', 'quiz', 'flashcards'],
            ),
          ));
      final jsonStr = extractJson(response);
      final data = safeJsonDecode(jsonStr);
      if (data.containsKey('title')) {
        return data;
      }
      throw AIServiceException('Malformed AI response for topic generation',
          code: 'MALFORMED_RESPONSE');
    } catch (e) {
      developer.log('Topic generation failed',
          name: 'GeneratorAIService', error: e);
      rethrow;
    }
  }

  Future<LocalQuiz> generateExam({
    required String text,
    required String title,
    required String subject,
    required String level,
    required int questionCount,
    required List<String> questionTypes,
    required double difficultyMix,
    bool evenTopicCoverage = true,
    bool focusWeakAreas = false,
    String? userId,
    CancellationToken? cancelToken,
  }) async {
    final config = AIConfig.thinkingGenerationConfig;
    final difficultyDesc =
        difficultyMix < 0.4 ? 'Easy' : (difficultyMix > 0.6 ? 'Hard' : 'Mixed');

    final prompt =
        '''Create a formal exam paper named "$title" for $subject ($level).
    
    PARAMETERS:
    - Total Questions: $questionCount
    - Allowed Types: ${questionTypes.join(', ')}
    - Target Difficulty Mix: $difficultyDesc
    - Even Topic Coverage: $evenTopicCoverage
    - Focus Weak Areas: $focusWeakAreas

    GENERATE a full set of high-quality exam questions using the provided source text.
    For each question, provide:
    1. The question text.
    2. The type.
    3. Options (if MC/TF).
    4. The correct answer.
    5. A thorough explanation/marking scheme.
    6. Difficulty level.

    SOURCE TEXT:
    $text

    OUTPUT FORMAT: JSON only.''';

    try {
      final response = await generateWithRetry(
        prompt,
        customModel: educatorModel,
        generationConfig: config,
        cancelToken: cancelToken,
      );

      final jsonStr = extractJson(response);
      final data = safeJsonDecode(jsonStr);

      final questionsData = data['questions'];
      final List<LocalQuizQuestion> questions = [];
      if (questionsData is List) {
        for (final q in questionsData) {
          if (q is Map) {
            final List<String> options = [];
            final rawOptions = q['options'];
            if (rawOptions is List) {
              for (final o in rawOptions) {
                options.add(o.toString());
              }
            }

            questions.add(LocalQuizQuestion(
              question: q['question']?.toString() ?? '...',
              options: options,
              correctAnswer: q['correctAnswer']?.toString() ?? '',
              explanation: q['explanation']?.toString(),
            ));
          }
        }
      }

      return LocalQuiz(
        id: const Uuid().v4(),
        userId: userId ?? '',
        title: title,
        questions: questions,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  // --- VERIFICATION API ---

  Future<Map<String, dynamic>> verifyEssayAnswer({
    required String question,
    required String studentAnswer,
    required String referenceAnswer,
    CancellationToken? cancelToken,
  }) async {
    developer.log('Verifying essay answer for question: $question',
        name: 'GeneratorAIService');

    final config = GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'score': Schema.integer(description: 'Score from 0 to 100'),
          'feedback': Schema.string(description: 'Detailed tutoring feedback'),
          'isCorrect': Schema.boolean(
              description: 'Whether the answer is fundamentally correct'),
        },
        requiredProperties: ['score', 'feedback', 'isCorrect'],
      ),
    );

    final prompt = '''As an AI Tutor, verify the student's answer to this study question.
    
    QUESTION: $question
    REFERENCE ANSWER / KEY POINTS: $referenceAnswer
    STUDENT'S ANSWER: $studentAnswer
    
    TASK:
    - Compare the student's answer with the reference answer.
    - Provide a score from 0-100%.
    - Provide constructive feedback (what was good, what was missing).
    - Be encouraging but maintain academic standards.
    - Set isCorrect to true if the score is 40% or higher.
    ''';

    try {
      final response = await generateWithRetry(prompt,
          customModel: educatorModel,
          generationConfig: config,
          cancelToken: cancelToken);

      final jsonStr = extractJson(response);
      return safeJsonDecode(jsonStr);
    } catch (e, stack) {
      developer.log('Essay verification failed',
          name: 'GeneratorAIService', error: e, stackTrace: stack);
      return {
        'score': 0,
        'feedback': 'Error during AI verification: $e',
        'isCorrect': false,
      };
    }
  }
}

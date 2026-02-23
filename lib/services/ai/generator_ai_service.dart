import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/local_flashcard.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'ai_base_service.dart';
import 'dart:developer' as developer;

class GeneratorAIService extends AIBaseService {
  Future<LocalSummary> generateSummary(String text,
      {String? userId, CancellationToken? cancelToken}) async {
    developer.log('Generating summary for text length: ${text.length}',
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
          generationConfig: config, cancelToken: cancelToken);
      developer.log('AI Response received for summary',
          name: 'GeneratorAIService');
      final jsonStr = extractJson(response);
      final dynamic decoded = json.decode(jsonStr);
      final Map<String, dynamic> data =
          decoded is Map<String, dynamic> ? decoded : {};

      return LocalSummary(
        id: '', // To be set by caller
        userId: userId ?? '',
        title: data['title']?.toString() ?? 'Study Guide',
        content: data['content']?.toString() ?? '',
        timestamp: DateTime.now(),
        tags: data['tags'] is List
            ? (data['tags'] as List).map((e) => e.toString()).toList()
            : [],
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
      CancellationToken? cancelToken}) async {
    developer.log(
        'Generating quiz ($questionCount questions) for text length: ${text.length}',
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

QUIZ RULES:
1. Questions must require understanding/application, not just simple name/date recall.
2. Options must be plausible distractors related to the topic.
3. Do NOT use "All of the above" or "None of the above" more than once.
4. Explanations must be thorough, explaining WHY the answer is correct and briefly why others are incorrect if applicable.

Text: $text''';

    try {
      final response = await generateWithRetry(prompt,
          customModel: proModel,
          generationConfig: config,
          cancelToken: cancelToken);
      developer.log('AI Response received for quiz',
          name: 'GeneratorAIService');
      final jsonStr = extractJson(response);
      final dynamic decoded = json.decode(jsonStr);
      final Map<String, dynamic> data =
          decoded is Map<String, dynamic> ? decoded : {};

      final questionsData = data['questions'];
      final List<LocalQuizQuestion> questions = [];
      if (questionsData is List) {
        for (final q in questionsData) {
          if (q is Map) {
            questions.add(LocalQuizQuestion(
              question: q['question']?.toString() ?? 'Unknown Question',
              options: q['options'] is List
                  ? (q['options'] as List).map((e) => e.toString()).toList()
                  : [],
              correctAnswer: q['correctAnswer']?.toString() ?? '',
              explanation: q['explanation']?.toString(),
            ));
          }
        }
      }

      return LocalQuiz(
        id: '',
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
      CancellationToken? cancelToken}) async {
    developer.log(
        'Generating flashcards ($cardCount) for text length: ${text.length}',
        name: 'GeneratorAIService');
    final config = GenerationConfig(
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

FLASHCARD PRINCIPLES:
- **Atomic Principle**: One question = one idea. Keep answers concise.
- **Clarity**: Use clear, unambiguous language.
- **Focus**: Target high-yield facts, crucial definitions, and pivotal concepts.
- **Variety**: Use a mix of "What is...", "How does...", and "Identify the..." style questions.

Text: $text''';

    try {
      final response = await generateWithRetry(prompt,
          customModel: proModel,
          generationConfig: config,
          cancelToken: cancelToken);
      developer.log('AI Response received for flashcards',
          name: 'GeneratorAIService');
      final jsonStr = extractJson(response);
      final dynamic decoded = json.decode(jsonStr);
      final Map<String, dynamic> data =
          decoded is Map<String, dynamic> ? decoded : {};

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
        id: '',
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
        '''You are an expert content extractor preparing raw text for exam studying.

CRITICAL: Your task is to EXTRACT and CLEAN the content, NOT to summarize or condense it.

WHAT TO DO:
1. REMOVE completely:
   - Advertisements, promotional content, menus, headers, footers
   - "Like and subscribe" calls, sponsor messages
   - Unrelated tangents or boilerplate text
2. FIX and CLEAN:
   - Broken sentences, formatting issues, OCR errors
3. ORGANIZE:
   - Structure content into logical sections with clear headers
4. PRESERVE (keep everything):
   - ALL factual information, data points, statistics
   - ALL key concepts, definitions, and explanations
   - ALL examples, case studies, formulas, equations
   - ALL step-by-step procedures

Return ONLY valid JSON:
{
  "cleanedText": "The extracted, cleaned, and organized content..."
}

Text: $rawText''';
    try {
      final response =
          await generateWithRetry(prompt, cancelToken: cancelToken);
      final jsonStr = extractJson(response);
      final dynamic decoded = json.decode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded['cleanedText']?.toString() ?? response;
      }
      return response;
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

    final prompt =
        '''You are an expert educator creating comprehensive study materials.
    TOPIC: $topic
    LEVEL: $depthInstruction

    GENERATE:
    1. **TITLE**: Engaging title.
    2. **SUMMARY**: 500-800 words, organized sections, bullet points.
    3. **QUIZ**: 10 multiple-choice questions with 4 options and correctIndex (0-3).
    4. **FLASHCARDS**: $cardCount question-answer pairs.

    Return ONLY valid JSON format:
    {
      "title": "Title",
      "summary": {
        "content": "...",
        "tags": ["tag1", "tag2"]
      },
      "quiz": [
        {
          "question": "...",
          "options": ["A", "B", "C", "D"],
          "correctIndex": 0,
          "explanation": "..."
        }
      ],
      "flashcards": [
        {"question": "...", "answer": "..."}
      ]
    }''';

    final response = await generateWithRetry(prompt,
        customModel: proModel, cancelToken: cancelToken);
    final jsonStr = extractJson(response);
    final dynamic decoded = json.decode(jsonStr);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw AIServiceException('Malformed AI response for topic generation',
        code: 'MALFORMED_RESPONSE');
  }

  Future<LocalQuiz> generateExam({
    required String text,
    required String title,
    required String subject,
    required String level,
    required int questionCount,
    required List<String> questionTypes,
    required double difficultyMix,
    String? userId,
    CancellationToken? cancelToken,
  }) async {
    final config = GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'questions': Schema.array(
            items: Schema.object(
              properties: {
                'question':
                    Schema.string(description: 'The exam question text'),
                'type': Schema.string(
                    description: 'Type of question from the requested list'),
                'options': Schema.array(
                    items: Schema.string(),
                    description:
                        'Required for Multiple Choice or True/False. Null otherwise.'),
                'correctAnswer': Schema.string(
                    description:
                        'The correct answer or ideal key points for theory'),
                'explanation': Schema.string(
                    description:
                        'Why this is the answer / Marking scheme guide'),
                'difficulty':
                    Schema.string(description: 'Easy, Medium, or Hard'),
              },
              requiredProperties: ['question', 'type', 'correctAnswer'],
            ),
          ),
        },
        requiredProperties: ['questions'],
      ),
    );

    final difficultyDesc =
        difficultyMix < 0.4 ? 'Easy' : (difficultyMix > 0.6 ? 'Hard' : 'Mixed');

    final prompt =
        '''Create a formal exam paper named "$title" for $subject ($level).
    
    PARAMETERS:
    - Total Questions: $questionCount
    - Allowed Types: ${questionTypes.join(', ')}
    - Overall Difficulty: $difficultyDesc
    - Source Material: $text

    REQUIREMENTS:
    1. Distribute questions across the allowed types fairly.
    2. Ensure questions align with the $level academic standard.
    3. Multiple Choice must have EXACTLY 4 options.
    4. True/False must have EXACTLY 2 options (True, False).
    5. Theory/Short Answer should provide a detailed marking guide in the "correctAnswer" field.
    6. Ensure high academic rigor and clarity.

    Source: $text''';

    final response = await generateWithRetry(prompt,
        customModel: proModel,
        generationConfig: config,
        cancelToken: cancelToken);
    developer.log('AI Response received for exam generation',
        name: 'GeneratorAIService');
    final jsonStr = extractJson(response);
    final dynamic decoded = json.decode(jsonStr);
    final Map<String, dynamic> data =
        decoded is Map<String, dynamic> ? decoded : {};

    final questionsData = data['questions'];
    final List<LocalQuizQuestion> questions = [];
    if (questionsData is List) {
      for (final q in questionsData) {
        if (q is Map) {
          questions.add(LocalQuizQuestion(
            question: q['question']?.toString() ?? 'Unknown Question',
            options: q['options'] is List
                ? (q['options'] as List).map((e) => e.toString()).toList()
                : [],
            correctAnswer: q['correctAnswer']?.toString() ?? '',
            explanation: q['explanation']?.toString(),
          ));
        }
      }
    }

    return LocalQuiz(
      id: '',
      userId: userId ?? '',
      title: title,
      questions: questions,
      timestamp: DateTime.now(),
    );
  }
}

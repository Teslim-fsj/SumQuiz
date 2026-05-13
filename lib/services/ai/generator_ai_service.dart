import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/local_flashcard.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:uuid/uuid.dart';
import 'ai_base_service.dart';
import 'package:sumquiz/providers/create_content_provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'ai_config.dart';

class GeneratorAIService extends AIBaseService {
  Future<LocalSummary> generateSummary(String text,
      {String? userId,
      String difficulty = 'intermediate',
      StudyArchetype archetype = StudyArchetype.architect,
      bool isPro = false,
      CancellationToken? cancelToken}) async {
    developer.log(
        'Generating $difficulty summary for text length: ${text.length}',
        name: 'GeneratorAIService');
    // Model-level config already has responseMimeType, temperature, and maxOutputTokens

    final prompt =
        '''Create a comprehensive, EXAM-FOCUSED study guide from the provided text.
TARGET DIFFICULTY: $difficulty (Scale your depth and terminology complexity accordingly).
STUDY ARCHETYPE: ${archetype == StudyArchetype.sprinter ? "The Sprinter (High-intensity, condensed, rapid review style)" : "The Architect (Structural mastery, core concepts, deep mental models)"}.

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

OUTPUT EXACTLY IN THIS JSON FORMAT:
{
  "title": "Topic-focused title",
  "content": "# Overview\\n\\nMarkdown formatted content...",
  "tags": ["keyword1", "keyword2", "keyword3"],
  "topics": ["Biology > Cell Division", "Cell Biology"]
}

Text: $text''';

    try {
      final response = await generateWithRetry(prompt,
          customModel: educatorModel, isPro: isPro, cancelToken: cancelToken);
      developer.log('AI Response received for summary',
          name: 'GeneratorAIService');
      final jsonStr = extractJson(response);
      final data = safeJsonDecode(jsonStr, requiredKeys: ['content']);

      if (data['content'].toString().trim().isEmpty) {
        throw AIServiceException('AI generated an empty summary. Neural circuits might be fatigued.', code: 'EMPTY_SUMMARY');
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
        topicNames: List<String>.from(data['topics'] ?? []),
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
      List<String>? questionTypes,
      bool isPro = false,
      CancellationToken? cancelToken}) async {
    final types = questionTypes ?? ['Multiple Choice'];
    final typesStr = types.join(', ');
    developer.log(
        'Generating $difficulty quiz ($questionCount questions) for text length: ${text.length}',
        name: 'GeneratorAIService');
    // Model-level config already has responseMimeType, temperature, and maxOutputTokens

    final prompt =
        '''Generate a professional $questionCount-question quiz using these formats: ($typesStr).
TARGET DIFFICULTY: $difficulty

QUIZ RULES:
1. Variety: Use the requested question types correctly.
2. EXACT COUNT: You MUST generate EXACTLY $questionCount questions. No more, no less.
3. Quality: Questions must require understanding/application, not just simple name/date recall.
4. For Multiple Choice / True-False: Options must be plausible distractors related to the topic.
5. For Short Answer: Ensure the correctAnswer is concise (1-5 words).
6. Explanations must be thorough, explaining WHY the answer is correct and briefly why others are incorrect if applicable.

OUTPUT EXACTLY IN THIS JSON FORMAT:
{
  "title": "Quiz Title",
  "topics": ["Physics > Kinematics", "Motion"],
  "questions": [
    {
      "question": "Sample text?",
      "options": ["A", "B", "C", "D"],
      "correctAnswer": "A",
      "correctIndex": 0,
      "explanation": "Why this is right.",
      "questionType": "Multiple Choice"
    }
  ]
}

Text: $text''';

    try {
      final response = await generateWithRetry(prompt,
          customModel: educatorModel, isPro: isPro, cancelToken: cancelToken);
      developer.log('AI Response received for quiz',
          name: 'GeneratorAIService');
      final jsonStr = extractJson(response);
      final data = safeJsonDecode(jsonStr, requiredKeys: ['questions']);

      final questionsData = data['questions'];
      final List<LocalQuizQuestion> questions = [];
      if (questionsData is List) {
        for (final q in questionsData) {
          if (q is Map) {
            questions.add(parseQuizQuestion(q));
          }
        }
      }

      if (questions.isEmpty) {
        throw AIServiceException('AI generated an empty quiz. Neural pathways might be fluctuating.', code: 'EMPTY_QUIZ');
      }

      return LocalQuiz(
        id: const Uuid().v4(),
        userId: userId ?? '',
        title: data['title']?.toString() ?? 'Quick Quiz',
        questions: questions,
        timestamp: DateTime.now(),
        topicNames: List<String>.from(data['topics'] ?? []),
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
      bool isPro = false,
      CancellationToken? cancelToken}) async {
    developer.log(
        'Generating $difficulty flashcards ($cardCount) for text length: ${text.length}',
        name: 'GeneratorAIService');
    // Model-level config already has responseMimeType, temperature, and maxOutputTokens

    final prompt = '''Create $cardCount active-recall flashcards from the text.
TARGET DIFFICULTY: $difficulty

FLASHCARD PRINCIPLES:
- **Atomic Principle**: One question = one idea. Keep answers concise.
- **EXACT COUNT**: You MUST generate EXACTLY $cardCount flashcards.
- **Clarity**: Use clear, unambiguous language.
- **Focus**: Target high-yield facts, crucial definitions, and pivotal concepts.
- **Variety**: Use a mix of "What is...", "How does...", and "Identify the..." style questions.

OUTPUT EXACTLY IN THIS JSON FORMAT:
{
  "title": "Deck Title",
  "topics": ["Math > Trigonometry", "Geometry"],
  "flashcards": [
    {
      "question": "Front of card",
      "answer": "Back of card"
    }
  ]
}

Text: $text''';

    try {
      final response = await generateWithRetry(prompt,
          customModel: educatorModel, cancelToken: cancelToken);
      developer.log('AI Response received for flashcards',
          name: 'GeneratorAIService');
      final jsonStr = extractJson(response);
      final data = safeJsonDecode(jsonStr, requiredKeys: ['flashcards']);

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

      if (flashcards.isEmpty) {
        throw AIServiceException('AI generated an empty flashcard set.', code: 'EMPTY_FLASHCARDS');
      }

      return LocalFlashcardSet(
        id: const Uuid().v4(),
        userId: userId ?? '',
        title: data['title']?.toString() ?? 'Flashcards',
        flashcards: flashcards,
        timestamp: DateTime.now(),
        topicNames: List<String>.from(data['topics'] ?? []),
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
    StudyArchetype archetype = StudyArchetype.architect,
    int quizCount = 10,
    int cardCount = 15,
    List<String>? questionTypes,
    bool isPro = false,
    CancellationToken? cancelToken,
  }) async {
    developer.log(
        'Generating from topic: $topic (depth: $depth, quiz: $quizCount, cards: $cardCount)',
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
    STUDY ARCHETYPE: ${archetype == StudyArchetype.sprinter ? "The Sprinter (High-intensity, condensed, rapid review style)" : "The Architect (Structural mastery, core concepts, deep mental models)"}
    
    REQUIREMENTS:
    - QUIZ: Generate EXACTLY $quizCount questions.
    - FLASHCARDS: Generate EXACTLY $cardCount cards.
    - TYPES: ${questionTypes?.join(', ') ?? 'Multiple Choice'}

    GENERATE IN THIS EXACT JSON FORMAT:
    {
      "title": "Clear Engaging Title",
      "summary": {
        "content": "# Overview\\n\\nMarkdown formatted content here...",
        "tags": ["keyword1", "keyword2"]
      },
      "quiz": [
        {
          "question": "Sample question text",
          "options": ["Option A", "Option B", "Option C", "Option D"],
          "correctAnswer": "Option A",
          "correctIndex": 0,
          "explanation": "Why this is correct.",
          "questionType": "Multiple Choice"
        }
      ],
      "flashcards": [
        {
          "question": "Front of card",
          "answer": "Back of card"
        }
      ]
    }''';

    try {
      final response = await generateWithRetry(prompt,
          customModel: educatorModel, isPro: isPro, cancelToken: cancelToken);
      final jsonStr = extractJson(response);
      var data = safeJsonDecode(jsonStr, requiredKeys: ['summary', 'quiz', 'flashcards']);

      // If safeJsonDecode failed, it returned an empty map
      if (data.isEmpty) {
        // Did the model return a list? Let's check manually
        try {
          final rawDecode = json.decode(jsonStr);
          if (rawDecode is List &&
              rawDecode.isNotEmpty &&
              rawDecode.first is Map) {
            data = Map<String, dynamic>.from(rawDecode.first);
          }
        } catch (_) {}
      }

      if (data.containsKey('title')) {
        // Validation: Ensure we have at least some content
        if (data['quiz'] is! List || (data['quiz'] as List).isEmpty) {
          developer.log('Topic generation returned empty quiz', name: 'GeneratorAIService', level: 900);
        }
        return data;
      }

      // Secondary robustness check for nested wrappers
      if (data.containsKey('topic') && data['topic'] is Map) {
        return Map<String, dynamic>.from(data['topic']);
      }
      if (data.containsKey('data') && data['data'] is Map) {
        return Map<String, dynamic>.from(data['data']);
      }

      throw AIServiceException(
          'Malformed AI response for topic generation. Raw: ${jsonStr.length > 200 ? jsonStr.substring(0, 200) : jsonStr}',
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
    required int easyCount,
    required int mediumCount,
    required int hardCount,
    required List<String> questionTypes,
    bool evenTopicCoverage = true,
    bool focusWeakAreas = false,
    String? userId,
    CancellationToken? cancelToken,
  }) async {
    // Model-level config already has responseMimeType, temperature, and maxOutputTokens

    final prompt =
        '''Create a formal exam paper named "$title" for $subject ($level).
    
    PARAMETERS:
    - Total Questions: $questionCount
    - DIFFICULTY DISTRIBUTION: $easyCount Easy, $mediumCount Medium, $hardCount Hard.
    - Allowed Types: ${questionTypes.join(', ')}
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

    OUTPUT EXACTLY IN THIS JSON FORMAT:
    {
      "questions": [
        {
          "question": "Question text here?",
          "options": ["Option A", "Option B", "Option C", "Option D"],
          "correctAnswer": "Option A",
          "correctIndex": 0,
          "explanation": "Why this is correct.",
          "questionType": "Multiple Choice"
        }
      ]
    }''';

    try {
      final response = await generateWithRetry(
        prompt,
        customModel: educatorModel,
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
              questionType: q['questionType']?.toString() ??
                  q['type']?.toString() ??
                  'Theory',
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

  Future<LocalQuizQuestion> regenerateQuestion({
    required String sourceText,
    required String subject,
    required String level,
    required LocalQuizQuestion oldQuestion,
    CancellationToken? cancelToken,
  }) async {
    final type = oldQuestion.questionType;
    final prompt =
        '''You are an expert examiner. Regenerate this $type question for a $level $subject exam.
    The new question must be based on the source text but different from the previous one.
    
    OLD QUESTION: ${oldQuestion.question}
    
    SOURCE TEXT:
    $sourceText
    
    OUTPUT FORMAT: JSON with 'question', 'options' (if MC/TF), 'correctAnswer', 'explanation', 'questionType'.''';

    // Model-level config already has responseMimeType, temperature, and maxOutputTokens

    final response = await generateWithRetry(
      prompt,
      customModel: educatorModel,
      cancelToken: cancelToken,
    );

    final jsonStr = extractJson(response);
    final data = safeJsonDecode(jsonStr);

    final List<String> options = [];
    final rawOptions = data['options'];
    if (rawOptions is List) {
      for (final o in rawOptions) {
        options.add(o.toString());
      }
    }

    return LocalQuizQuestion(
      question: data['question']?.toString() ?? '...',
      options: options,
      correctAnswer: data['correctAnswer']?.toString() ?? '',
      explanation: data['explanation']?.toString(),
      questionType: data['questionType']?.toString() ?? type,
    );
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

    // Model-level config already has responseMimeType, temperature, and maxOutputTokens

    final prompt =
        '''As an AI Tutor, verify the student's answer to this study question.
    
    QUESTION: $question
    REFERENCE ANSWER / KEY POINTS: $referenceAnswer
    STUDENT'S ANSWER: $studentAnswer
    
    TASK:
    - Compare the student's answer with the reference answer.
    - Provide a score from 0-100%.
    - Provide constructive feedback (what was good, what was missing).
    - Be encouraging but maintain academic standards.
    - Set isCorrect to true if the score is 40% or higher.

    OUTPUT EXACTLY IN THIS JSON FORMAT:
    {
      "score": 85,
      "feedback": "Your answer covered the main points but missed X...",
      "isCorrect": true
    }''';

    try {
      final response = await generateWithRetry(prompt,
          customModel: educatorModel, cancelToken: cancelToken);

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

  Future<Map<String, dynamic>> generateDiagramLabeledQuiz({
    required Uint8List imageBytes,
    required String userId,
    CancellationToken? cancelToken,
  }) async {
    developer.log('Generating Label the Image quiz from diagram',
        name: 'GeneratorAIService');

    final prompt =
        '''You are an educational AI. Analyze the provided image (diagram/whiteboard). 
    1. Identify all key parts, labels, or processes shown.
    2. Extract any handwritten or printed text accurately.
    3. Create a "Label the Image" quiz. Identify 5-8 specific areas or labels and describe them.
    4. Also provide a summary of what the diagram represents.

    OUTPUT EXACTLY IN THIS JSON FORMAT:
    {
      "title": "Diagram Title",
      "summary": "Educational explanation of the diagram...",
      "questions": [
        {
          "label": "Part Name",
          "description": "What this part does or represents",
          "clue": "A hint for the student"
        }
      ]
    }''';

    final response = await generateWithData(
      prompt,
      imageBytes,
      'image/png',
      cancelToken: cancelToken,
    );

    final jsonStr = extractJson(response);
    return safeJsonDecode(jsonStr);
  }

  Stream<String> getTutorResponseStream({
    required String prompt,
    String? context,
    String? userName,
    CancellationToken? cancelToken,
  }) {
    final systemPrompt = '''You are Sumi, a brilliant and empathetic AI tutor for SumQuiz.
    Your goal is to help ${userName ?? 'the student'} master their subjects through active recall and Socratic questioning.
    
    CURRENT CONTEXT: ${context ?? 'General study session.'}
    
    GUIDELINES:
    - Ground your answers in the provided context if available.
    - Be concise and exam-focused.
    - Use Markdown for structure.
    - Use emojis sparingly to maintain a friendly personality.
    - If you don't know something based on the context, say so and suggest related study topics.
    ''';

    final fullPrompt = '$systemPrompt\n\nStudent: $prompt\nSumi:';

    return generateStream(
      fullPrompt,
      customModel: educatorModel,
      generationConfig: AIConfig.conversationalGenerationConfig,
      cancelToken: cancelToken,
    );
  }

  Future<String> getConversationalResponse({
    required String prompt,
    String? context,
    String? userName,
    CancellationToken? cancelToken,
  }) async {
    final systemPrompt = '''You are Sumi, a brilliant and empathetic AI tutor for SumQuiz.
    Your goal is to help ${userName ?? 'the student'} master their subjects through active recall and Socratic questioning.
    
    CURRENT CONTEXT: ${context ?? 'General study session.'}
    
    GUIDELINES:
    - Ground your answers in the provided context if available.
    - Be extremely concise (1-3 sentences).
    - Use Markdown for structure.
    - If you don't know something based on the context, say so and suggest related study topics.
    ''';

    final fullPrompt = '$systemPrompt\n\nStudent: $prompt\nSumi:';

    return generateConversational(
      fullPrompt,
      customModel: educatorModel,
      cancelToken: cancelToken,
    );
  }

  Future<String> getConversationalResponseWithAudio({
    required String prompt,
    required Uint8List audioBytes,
    String mimeType = 'audio/m4a',
    String? context,
    String? userName,
    CancellationToken? cancelToken,
  }) async {
    final systemPrompt = '''You are Sumi, a brilliant and empathetic AI tutor for SumQuiz.
    Your goal is to help ${userName ?? 'the student'} master their subjects through active recall and Socratic questioning.
    
    CURRENT CONTEXT: ${context ?? 'General study session.'}
    
    GUIDELINES:
    - Ground your answers in the provided context if available.
    - Be extremely concise (1-3 sentences).
    - Use Markdown for structure.
    - If you don't know something based on the context, say so and suggest related study topics.
    ''';

    final fullPrompt = '$systemPrompt\n\nStudent: $prompt\nSumi:';

    return generateConversationalWithData(
      fullPrompt,
      audioBytes,
      mimeType,
      customModel: educatorModel,
      cancelToken: cancelToken,
    );
  }

  LocalQuizQuestion parseQuizQuestion(Map q) {
    final List<String> options = [];
    final rawOptions = q['options'];
    if (rawOptions is List) {
      for (final o in rawOptions) {
        options.add(o.toString());
      }
    }

    // Normalization: Extract correct answer by text or index
    String correctAnswer = q['correctAnswer']?.toString() ?? '';
    final dynamic correctIndex = q['correctIndex'];

    if (correctAnswer.isEmpty && correctIndex != null) {
      final idx = int.tryParse(correctIndex.toString());
      if (idx != null && idx >= 0 && idx < options.length) {
        correctAnswer = options[idx];
      }
    }

    return LocalQuizQuestion(
      question: q['question']?.toString() ?? 'Unknown Question',
      options: options,
      correctAnswer: correctAnswer,
      explanation: q['explanation']?.toString() ?? 'No explanation provided.',
      questionType: q['questionType']?.toString() ?? 'Multiple Choice',
    );
  }
}

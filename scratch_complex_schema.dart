import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

void main() async {
  print('Starting complex schema test...');
  final apiKey = 'AIzaSyDWEUCZ9lfq7yspgl6fMt84jIUOAN9mItI';
  final modelStr = 'gemini-3.1-flash-lite-preview';

  final config = GenerationConfig(
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
              'questionType': Schema.string(),
            },
            requiredProperties: [
              'question',
              'correctAnswer',
              'explanation',
              'questionType'
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
  );

  final model = GenerativeModel(
    model: modelStr,
    apiKey: apiKey,
    generationConfig: config,
  );

  try {
    print('Sending complex prompt...');
    final response = await model.generateContent([
      Content.text(
          'Generate a short study guide on Photosynthesis. Include 1 quiz question and 1 flashcard.')
    ]);
    print('Response received! Length: \${response.text?.length}');
    print(response.text);

    // Test the parsing
    String cleaned = response.text!.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceAll(RegExp(r'^```(?:json|JSON)?\s*\n?'), '');
      cleaned = cleaned.replaceAll(RegExp(r'\n?```\$'), '');
    }
    print('Cleaned json length: \${cleaned.length}');
    final map = json.decode(cleaned);
    print('Decode successful. Contains title: \${map.containsKey("title")}');
  } catch (e) {
    print('ERROR: \$e');
    print('STACKTRACE: \$st');
  }
}

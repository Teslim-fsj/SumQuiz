import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  print('Starting standalone API test...');
  // API Key loaded from build arguments via --dart-define=API_KEY
  const apiKey = String.fromEnvironment('API_KEY');
  final modelStr = 'gemini-3.1-flash-lite-preview';
  
  print('Initializing model \$modelStr...');
  final model = GenerativeModel(
    model: modelStr,
    apiKey: apiKey,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'title': Schema.string(),
          'content': Schema.string(),
        },
        requiredProperties: ['title', 'content'],
      ),
    ),
  );

  try {
    print('Sending prompt...');
    final response = await model.generateContent([
      Content.text('Generate a short test summary in JSON format.')
    ]);
    print('Response received!');
    print(response.text);
  } catch (e) {
    print('ERROR: \$e');
    print('STACKTRACE: \$st');
  }
}

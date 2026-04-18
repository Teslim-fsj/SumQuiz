import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  print('Testing AI with key and model directly...');
  const String apiKey = 'AIzaSyDWEUCZ9lfq7yspgl6fMt84jIUOAN9mItI';
  
  try {
    final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
           responseMimeType: 'application/json',
           responseSchema: Schema.object(
             properties: {
               'status': Schema.string(),
             },
           )
        )
    );
    print('Sending request...');
    final response = await model.generateContent([Content.text('Say {"status": "ok"}')]);
    print('Success! Response: ${response.text}');
  } catch (e) {
    print('Error caught: $e');
  }
}

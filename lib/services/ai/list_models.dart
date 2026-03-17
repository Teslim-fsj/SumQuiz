import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  const String apiKey = 'AIzaSyDWEUCZ9lfq7yspgl6fMt84jIUOAN9mItI';

  try {
    // This is a placeholder since the official Dart SDK doesn't have listModels directly in many versions
    // but the REST API does. I'll attempt a REST call if the SDK doesn't provide it.
    print('Attempting to list models...');
    // For now, let's try some common variations based on typical release cycles
    final modelsToTry = [
      'gemini-2.0-flash',
      'gemini-2.0-pro-exp',
      'gemini-exp-1206',
      'gemini-2.0-flash-exp',
      'gemini-1.5-flash-latest',
      'gemini-1.5-pro-latest'
    ];

    for (final m in modelsToTry) {
      try {
        final model = GenerativeModel(model: m, apiKey: apiKey);
        await model.generateContent([Content.text('test')]).timeout(
            Duration(seconds: 5));
        print('FOUND & ACCESSIBLE: $m');
      } catch (e) {
        if (e.toString().contains('404')) {
          print('NOT FOUND: $m');
        } else {
          print('FOUND but error (Quota/etc): $m - $e');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

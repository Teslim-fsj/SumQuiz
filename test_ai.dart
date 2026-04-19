import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  print('Starting test...');
  try {
    const apiKey = 'AIzaSyDWEUCZ9lfq7yspgl6fMt84jIUOAN9mItI';
    final model = GenerativeModel(
      model: 'gemini-3.1-flash-lite',
      apiKey: apiKey,
    );
    final response = await model.generateContent([Content.text('Hello')]);
    print('Response: \${response.text}');
  } catch (e) {
    print('Error caught: \$e');
  }
}

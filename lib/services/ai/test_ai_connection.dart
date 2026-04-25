import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sumquiz/services/ai/ai_config.dart';
import 'dart:io';

void main() async {
  print('--- AI Connection Diagnostic (2026 Edition) ---');

  const String apiKey = String.fromEnvironment('API_KEY');
  final String modelName = AIConfig.primaryModel;

  if (apiKey.isEmpty || apiKey.startsWith('YOUR_API_KEY')) {
    print('ERROR: API Key is not set or is a placeholder.');
    exit(1);
  }

  print('Testing connectivity with model: $modelName');

  try {
    final model = GenerativeModel(model: modelName, apiKey: apiKey);
    final content = [
      Content.text('Hello, respond with "AI OK" if you can hear me.')
    ];

    final response = await model
        .generateContent(content)
        .timeout(const Duration(seconds: 15));

    print('SUCCESS! Response: ${response.text}');
    if (response.text?.contains('AI OK') ?? false) {
      print('Status: Service is fully operational.');
    } else {
      print('Status: Service returned unexpected content.');
    }
  } catch (e) {
    print('FAILURE: Could not connect to Gemini API.');
    print('Error Detail: $e');

    if (e.toString().contains('403') ||
        e.toString().contains('PERMISSION_DENIED')) {
      print(
          'Advice: Your API Key might be invalid, restricted, or billing might be disabled.');
    } else if (e.toString().contains('404')) {
      print(
          'Advice: Model "$modelName" not found. Check if this model is available in your region.');
    } else if (e.toString().contains('SocketException')) {
      print(
          'Advice: Network error. Check your internet connection and proxy settings.');
    }
  }
}

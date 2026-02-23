import 'package:google_generative_ai/google_generative_ai.dart';

class AIConfig {
  // Stable 2026 Model Names
  static const String primaryModel = 'gemini-3-flash-preview';
  static const String proModel = 'gemini-3.1-pro-preview';
  static const String fallbackModel = 'gemini-3-flash-preview';
  static const String visionModel =
      'gemini-3-flash-preview'; // High-speed vision
  static const String youtubeModel =
      'gemini-3.1-pro-preview'; // Deep multimodal video analysis

  // Retry configuration with exponential backoff
  static const int maxRetries = 5;
  static const int initialRetryDelayMs = 1000;
  static const int maxRetryDelayMs = 60000;
  static const int requestTimeoutSeconds = 180;

  // YouTube/video-specific timeouts
  static const int youtubeTimeoutSeconds = 180;
  static const int transcriptTimeoutSeconds = 30;
  static const int webpageTimeoutSeconds = 30;

  // Master extraction timeout — wraps the entire extraction operation
  static const int masterExtractionTimeoutSeconds = 200;

  // Input/output limits
  static const int maxInputLength = 30000;
  static const int maxPdfSize = 15 * 1024 * 1024; // 15MB
  static const int maxOutputTokens = 8192;

  // Model parameters
  static const double defaultTemperature = 0.3;
  static const double fallbackTemperature = 0.4;
  static const double creativeTemperature = 0.7;

  static GenerationConfig get defaultGenerationConfig => GenerationConfig(
        temperature: defaultTemperature,
        maxOutputTokens: maxOutputTokens,
        responseMimeType: 'application/json',
      );

  static GenerationConfig get proGenerationConfig => GenerationConfig(
        temperature: defaultTemperature,
        maxOutputTokens: maxOutputTokens * 2,
        responseMimeType: 'application/json',
      );
}

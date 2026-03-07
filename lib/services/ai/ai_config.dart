import 'package:google_generative_ai/google_generative_ai.dart';

class AIConfig {
  // Stable 2026 Model Names
  static const String primaryModel = 'gemini-1.5-flash';
  static const String proModel = 'gemini-1.5-pro';
  static const String fallbackModel = 'gemini-1.5-flash';
  static const String visionModel = 'gemini-1.5-flash';
  static const String youtubeModel = 'gemini-1.5-pro';

  // Retry configuration with exponential backoff
  static const int maxRetries = 5;
  static const int initialRetryDelayMs = 1000;
  static const int maxRetryDelayMs = 60000;
  static const int requestTimeoutSeconds = 180;

  // YouTube/video-specific timeouts
  static const int youtubeTimeoutSeconds = 180;
  static const int transcriptTimeoutSeconds = 45;
  static const int webpageTimeoutSeconds = 30;

  // Master extraction timeout — wraps the entire extraction operation
  static const int masterExtractionTimeoutSeconds = 200;

  // YouTube Multimodal threshold (duration < 10 mins)
  static const int youtubeMultimodalThresholdSeconds = 600;

  // Input/output limits
  static const int maxInputLength = 100000; // Increased from 15k for large PDFs
  static const int maxPdfSize = 20 * 1024 * 1024; // 20MB limit
  static const int maxOutputTokens = 16384; // Increased from 8k

  // Model parameters
  static const double defaultTemperature = 0.3;
  static const double fallbackTemperature = 0.4;
  static const double creativeTemperature = 0.7;

  static GenerationConfig get defaultGenerationConfig => GenerationConfig(
        temperature: defaultTemperature,
        maxOutputTokens: 8192,
        responseMimeType: 'application/json',
      );

  static GenerationConfig get extractionGenerationConfig => GenerationConfig(
        temperature: 0.1, // Low temperature for high accuracy
        maxOutputTokens: maxOutputTokens,
        responseMimeType: 'text/plain',
      );

  static GenerationConfig get proGenerationConfig => GenerationConfig(
        temperature: defaultTemperature,
        maxOutputTokens: maxOutputTokens * 2,
        responseMimeType: 'application/json',
      );
}

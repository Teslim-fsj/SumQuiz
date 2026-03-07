import 'package:google_generative_ai/google_generative_ai.dart';

class AIConfig {
  // Retry configuration with exponential backoff
  static const int maxRetries = 5;
  static const int initialRetryDelayMs = 1000;
  static const int maxRetryDelayMs = 60000;
  static const int requestTimeoutSeconds = 180;

  // YouTube/video-specific timeouts
  static const int youtubeTimeoutSeconds = 180;
  static const int transcriptTimeoutSeconds = 45;
  static const int webpageTimeoutSeconds = 30;

  // Stable 2026 Model Names
  static const String primaryModel = 'gemini-2.0-flash';
  static const String proModel = 'gemini-1.5-pro';
  static const String fallbackModel = 'gemini-1.5-flash';
  static const String visionModel = 'gemini-2.0-flash';
  static const String youtubeModel = 'gemini-2.0-flash';

  // Master extraction timeout — wraps the entire extraction operation
  static const int masterExtractionTimeoutSeconds = 200;

  // YouTube Multimodal threshold (duration < 10 mins)
  static const int youtubeMultimodalThresholdSeconds = 600;

  // Input/output limits
  static const int maxInputLength =
      200000; // Increased from 100k for Gemini 2.0
  static const int maxPdfSize = 20 * 1024 * 1024; // 20MB limit
  static const int maxOutputTokens = 16384; // Increased from 8k

  // Model parameters
  static const double defaultTemperature = 0.3;
  static const double fallbackTemperature = 0.4;
  static const double creativeTemperature = 0.7;

  // --- System Instruction Templates ---
  static Content get educatorSystemInstruction => Content.system(
        'You are an expert academic educator and study assistant. '
        'Your goal is to transform complex information into clear, structured, and exam-focused study materials. '
        'Always maintain an encouraging but professional academic tone. '
        'Focus on high-yield concepts and factual accuracy.',
      );

  static Content get extractorSystemInstruction => Content.system(
        'You are a precise content extraction specialist. '
        'Your task is to identify and extract the core factual content from raw text, '
        'removing noise (ads, boilerplate, tangents) while preserving ALL educational data points, '
        'definitions, and examples verbatim.',
      );

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

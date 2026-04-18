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

  // Gemini Series (Optimized for 2026 Production)
  static const String primaryModel = 'gemini-3.1-flash-lite';
  static const String secondaryModel = 'gemini-2.5-flash-lite';
  static const String fallbackModel = 'gemini-3-flash';
  static const String proModel = 'gemini-3.1-flash'; // Using Flash as Pro is restricted
  static const String visionModel = 'gemini-3.1-flash-lite';
  static const String youtubeModel = 'gemini-3.1-flash-lite';

  // Master extraction timeout — wraps the entire extraction operation
  static const int masterExtractionTimeoutSeconds = 300;

  // YouTube Multimodal threshold (duration < 15 mins for Gemini 3.1)
  static const int youtubeMultimodalThresholdSeconds = 900;

  // Input/output limits (Gemini 3.1 Expanded Context)
  static const int maxInputLength =
      1000000; // 1M characters/tokens for full document analysis
  static const int maxPdfSize = 50 * 1024 * 1024; // 50MB limit
  static const int maxOutputTokens =
      32768; // Increased for long-form generation

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

  static GenerationConfig get thinkingGenerationConfig => GenerationConfig(
        temperature: 0.7, // Higher temp for broader reasoning
        maxOutputTokens: 16384,
        // thinkingBudget: 4000, // Valid for Gemini 2.0 Flash Thinking
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

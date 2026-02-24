import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;
import 'ai_config.dart';
import '../../utils/cancellation_token.dart';

// --- EXCEPTIONS ---
class AIServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AIServiceException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => code != null ? '[$code] $message' : message;

  bool get isRateLimitError =>
      code == 'RESOURCE_EXHAUSTED' ||
      code == '429' ||
      message.contains('rate limit') ||
      message.contains('quota');

  bool get isNetworkError =>
      code == 'NETWORK_ERROR' || originalError is TimeoutException;
}

abstract class AIBaseService {
  GenerativeModel? _model;
  GenerativeModel? _proModel;
  GenerativeModel? _fallbackModel;
  GenerativeModel? _visionModel;
  GenerativeModel? _youtubeModel;

  bool _initialized = false;
  String? _initializationError;

  AIBaseService() {
    _initializeModelsAsync();
  }

  Future<void> _initializeModelsAsync() async {
    try {
      // API Key hardcoded for production/GitHub builds as requested by user
      const String hardcodedApiKey = 'AIzaSyDWEUCZ9lfq7yspgl6fMt84jIUOAN9mItI';
      final envKey = dotenv.env['API_KEY'];
      final apiKey =
          (envKey != null && envKey.isNotEmpty) ? envKey : hardcodedApiKey;

      if (apiKey.isEmpty) {
        _initializationError = 'API key is not configured.';
        return;
      }

      _model = GenerativeModel(
        model: AIConfig.primaryModel,
        apiKey: apiKey,
        generationConfig: AIConfig.defaultGenerationConfig,
      );

      _proModel = GenerativeModel(
        model: AIConfig.proModel,
        apiKey: apiKey,
        generationConfig: AIConfig.proGenerationConfig,
      );

      _fallbackModel = GenerativeModel(
        model: AIConfig.fallbackModel,
        apiKey: apiKey,
        generationConfig: AIConfig.defaultGenerationConfig,
      );

      _visionModel = GenerativeModel(
        model: AIConfig.visionModel,
        apiKey: apiKey,
        generationConfig: AIConfig.defaultGenerationConfig,
      );

      _youtubeModel = GenerativeModel(
        model: AIConfig.youtubeModel,
        apiKey: apiKey,
        generationConfig: AIConfig.proGenerationConfig,
      );

      _initialized = true;
    } catch (e) {
      _initializationError = 'Failed to initialize AI models: $e';
    }
  }

  Future<bool> ensureInitialized([int timeoutSeconds = 15]) async {
    if (_initialized) return true;

    final stopwatch = Stopwatch()..start();
    while (!_initialized && stopwatch.elapsed.inSeconds < timeoutSeconds) {
      if (_initializationError != null) return false;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return _initialized;
  }

  Future<bool> isServiceHealthy() async {
    try {
      if (!await ensureInitialized(10)) return false;
      // Simple health check message with more aggressive timeout
      final response = await _model!.generateContent(
          [Content.text('Say "ok"')]).timeout(const Duration(seconds: 5));

      final healthy =
          response.text != null && response.text!.toLowerCase().contains('ok');
      if (!healthy) {
        developer.log('AI Health Check failed: Unexpected response',
            name: 'AIBaseService');
      }
      return healthy;
    } catch (e) {
      developer.log('API health check failed: $e', name: 'AIBaseService');
      return false;
    }
  }

  String _sanitizeInput(String input) {
    input = input
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();

    if (input.length <= AIConfig.maxInputLength) return input;

    // Hard Truncation to ensure stability
    developer.log(
        'AI Input truncated from ${input.length} to ${AIConfig.maxInputLength}',
        name: 'AIBaseService',
        level: 500);

    return input.substring(0, AIConfig.maxInputLength).trim();
  }

  GenerativeModel get model => _model!;
  GenerativeModel get proModel => _proModel!;
  GenerativeModel get fallbackModel => _fallbackModel!;
  GenerativeModel get visionModel => _visionModel!;
  GenerativeModel get youtubeModel => _youtubeModel!;

  Future<String> generateWithRetry(String prompt,
      {GenerativeModel? customModel,
      GenerationConfig? generationConfig,
      CancellationToken? cancelToken}) async {
    return generateMultimodal([TextPart(prompt)],
        customModel: customModel,
        generationConfig: generationConfig,
        cancelToken: cancelToken);
  }

  Future<String> generateMultimodal(List<Part> parts,
      {GenerativeModel? customModel,
      GenerationConfig? generationConfig,
      CancellationToken? cancelToken}) async {
    if (!await ensureInitialized()) {
      throw AIServiceException('AI Service not ready: $_initializationError',
          code: 'SERVICE_NOT_READY');
    }

    // Sanitize any TextPart in the parts
    final sanitizedParts = parts.map((part) {
      if (part is TextPart) {
        return TextPart(_sanitizeInput(part.text));
      }
      return part;
    }).toList();

    var targetModel = customModel ?? _model;
    if (targetModel == null) {
      throw AIServiceException('Model not available',
          code: 'MODEL_NOT_AVAILABLE');
    }

    // If custom config is provided, we need to re-wrap the model with it
    // Note: GenerativeModel is immutable, but we can use provide custom config per request in newer SDKs
    // but for compatibility we check if we can pass it to generateContent

    int attempt = 0;
    while (attempt < AIConfig.maxRetries) {
      cancelToken?.throwIfCancelled();

      try {
        final response = await targetModel.generateContent(
          [Content.multi(sanitizedParts)],
          generationConfig:
              generationConfig, // Supported in newer versions of the SDK
        ).timeout(const Duration(seconds: AIConfig.requestTimeoutSeconds));

        cancelToken?.throwIfCancelled();

        final text = response.text;
        if (text == null || text.trim().isEmpty) {
          throw AIServiceException('Empty or null response from AI',
              code: 'EMPTY_RESPONSE');
        }
        return text.trim();
      } catch (e) {
        attempt++;
        if (attempt >= AIConfig.maxRetries) rethrow;

        final baseDelay = AIConfig.initialRetryDelayMs * pow(2, attempt - 1);
        final jitter = Random().nextInt(1000);
        final delay = min(
          baseDelay.toInt() + jitter,
          AIConfig.maxRetryDelayMs,
        ).toInt();

        developer.log('AI Retry attempt $attempt in ${delay}ms',
            name: 'AIBaseService', error: e);
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
    throw AIServiceException('Max retries exceeded', code: 'MAX_RETRIES');
  }

  String extractJson(String response) {
    try {
      String cleaned = response.trim();
      final jsonBlockRegex =
          RegExp(r'```(?:json|JSON)?\s*\n?([\s\S]*?)\n?```', multiLine: true);
      final match = jsonBlockRegex.firstMatch(cleaned);

      if (match != null && match.group(1) != null) {
        cleaned = match.group(1)!.trim();
      }

      if (!cleaned.startsWith('{') && !cleaned.startsWith('[')) {
        final start = cleaned.indexOf(RegExp(r'[\{\[]'));
        if (start >= 0) {
          final end = cleaned.lastIndexOf(cleaned[start] == '{' ? '}' : ']');
          if (end > start) {
            cleaned = cleaned.substring(start, end + 1);
          }
        }
      }
      return cleaned;
    } catch (e) {
      developer.log('Error in extractJson', name: 'AIBaseService', error: e);
      return response.trim();
    }
  }

  /// Safely decode JSON with a fallback. Returns fallback if parsing fails.
  Map<String, dynamic> safeJsonDecode(String jsonStr,
      {Map<String, dynamic> fallback = const {}}) {
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is Map<String, dynamic>) return decoded;
      return fallback;
    } catch (e) {
      developer.log('Safe JSON decode failed', name: 'AIBaseService', error: e);
      return fallback;
    }
  }
}

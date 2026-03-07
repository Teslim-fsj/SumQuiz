import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
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
      const String apiKey = 'AIzaSyDWEUCZ9lfq7yspgl6fMt84jIUOAN9mItI';

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
    developer.log('ensureInitialized called, _initialized: $_initialized',
        name: 'AIBaseService');
    if (_initialized) {
      developer.log('Service already initialized', name: 'AIBaseService');
      return true;
    }

    final stopwatch = Stopwatch()..start();
    while (!_initialized && stopwatch.elapsed.inSeconds < timeoutSeconds) {
      if (_initializationError != null) {
        developer.log('Initialization error: $_initializationError',
            name: 'AIBaseService');
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    developer.log('Initialization complete, _initialized: $_initialized',
        name: 'AIBaseService');
    return _initialized;
  }

  Future<bool> isServiceHealthy() async {
    developer.log('AI Health Check started...', name: 'AIBaseService');
    try {
      if (!await ensureInitialized(10)) {
        developer.log(
            'AI Health Check failed: Initialization timed out or failed.',
            name: 'AIBaseService',
            level: 1000);
        return false;
      }

      if (_model == null) {
        developer.log(
            'AI Health Check failed: Primary model is null after initialization.',
            name: 'AIBaseService',
            level: 1000);
        return false;
      }

      // Simple health check message with more aggressive timeout
      developer.log('Sending test prompt to model: ${AIConfig.primaryModel}',
          name: 'AIBaseService');
      final response = await _model!.generateContent(
          [Content.text('Say "ok"')]).timeout(const Duration(seconds: 10));

      final healthy =
          response.text != null && response.text!.toLowerCase().contains('ok');

      if (!healthy) {
        developer.log(
            'AI Health Check failed: Unexpected response: ${response.text}',
            name: 'AIBaseService',
            level: 1000);
      } else {
        developer.log('AI Health Check PASSED.', name: 'AIBaseService');
      }
      return healthy;
    } catch (e) {
      developer.log('AI Health Check CRITICAL FAILURE: $e',
          name: 'AIBaseService', error: e, level: 1000);
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

  /// New method to handle multimodal data (e.g., images, PDFs, audio)
  Future<String> generateWithData(
    String prompt,
    Uint8List data,
    String mimeType, {
    GenerativeModel? customModel,
    GenerationConfig? generationConfig,
    CancellationToken? cancelToken,
  }) async {
    developer.log('generateWithData called with mimeType: $mimeType',
        name: 'AIBaseService');
    return generateMultimodal(
      [
        TextPart(_sanitizeInput(prompt)),
        DataPart(mimeType, data),
      ],
      customModel: customModel,
      generationConfig: generationConfig,
      cancelToken: cancelToken,
    );
  }

  Future<String> generateMultimodal(List<Part> parts,
      {GenerativeModel? customModel,
      GenerationConfig? generationConfig,
      CancellationToken? cancelToken}) async {
    developer.log('generateMultimodal called', name: 'AIBaseService');
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
      developer.log('Target model is null', name: 'AIBaseService');
      throw AIServiceException('Model not available',
          code: 'MODEL_NOT_AVAILABLE');
    }

    developer.log('Using target model', name: 'AIBaseService');

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
          developer.log('Empty or null response from AI',
              name: 'AIBaseService', level: 1000);
          throw AIServiceException('Empty or null response from AI',
              code: 'EMPTY_RESPONSE');
        }

        // --- NEW LOGGING ---
        developer.log(
            'RAW AI RESPONSE (first 200 chars): ${text.length > 200 ? text.substring(0, 200) : text}',
            name: 'AIBaseService');
        // -------------------

        developer.log('Successfully generated response', name: 'AIBaseService');
        return text.trim();
      } catch (e) {
        attempt++;
        if (attempt >= AIConfig.maxRetries) {
          developer.log('Max retries exceeded for generation',
              name: 'AIBaseService', error: e);
          rethrow;
        }

        final baseDelay = AIConfig.initialRetryDelayMs * pow(2, attempt - 1);
        final jitter = Random().nextInt(1000);
        final delay = min(
          baseDelay.toInt() + jitter,
          AIConfig.maxRetryDelayMs,
        ).toInt();

        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('403') ||
            errorMessage.contains('permission_denied') ||
            errorMessage.contains('api_key_invalid')) {
          developer.log(
              'CRITICAL: API Key appears to be invalid or restricted (403 Forbidden).',
              name: 'AIBaseService',
              level: 1000);
        }

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

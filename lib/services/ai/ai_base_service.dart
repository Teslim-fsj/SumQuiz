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
      message.toLowerCase().contains('rate limit') ||
      message.toLowerCase().contains('quota') ||
      message.toLowerCase().contains('full') ||
      message.toLowerCase().contains('overloaded');

  bool get isNetworkError =>
      code == 'NETWORK_ERROR' || originalError is TimeoutException;
}

abstract class AIBaseService {
  GenerativeModel? _model;
  GenerativeModel? _secondaryModel; // Tier 2 fallback
  GenerativeModel? _proModel;
  GenerativeModel? _tertiaryModel;
  GenerativeModel? _fallbackModel; // Tier 4 fallback
  GenerativeModel? _visionModel;
  GenerativeModel? _youtubeModel;
  GenerativeModel? _educatorModel;
  GenerativeModel? _extractorModel;

  bool _initialized = false;
  String? _initializationError;

  AIBaseService() {
    _initializeModelsAsync();
  }

  Future<void> _initializeModelsAsync() async {
    try {
      // API Key loaded from build arguments via --dart-define=API_KEY
      const String apiKey = String.fromEnvironment('API_KEY');

      if (apiKey.isEmpty) {
        _initializationError = 'API key is not configured.';
        return;
      }

      final defaultConfig = AIConfig.defaultGenerationConfig;
      final proConfig = AIConfig.proGenerationConfig;
      final eduInstruction = AIConfig.educatorSystemInstruction;

      _model = GenerativeModel(
        model: AIConfig.primaryModel,
        apiKey: apiKey,
        generationConfig: defaultConfig,
        systemInstruction: eduInstruction,
      );

      _secondaryModel = GenerativeModel(
        model: AIConfig.secondaryModel,
        apiKey: apiKey,
        generationConfig: defaultConfig,
        systemInstruction: eduInstruction,
      );

      _proModel = GenerativeModel(
        model: AIConfig.proModel,
        apiKey: apiKey,
        generationConfig: proConfig,
        systemInstruction: eduInstruction,
      );

      _tertiaryModel = GenerativeModel(
        model: AIConfig.tertiaryModel,
        apiKey: apiKey,
        generationConfig: defaultConfig,
        systemInstruction: eduInstruction,
      );

      _fallbackModel = GenerativeModel(
        model: AIConfig.fallbackModel,
        apiKey: apiKey,
        generationConfig: defaultConfig,
        systemInstruction: eduInstruction,
      );

      _visionModel = GenerativeModel(
        model: AIConfig.visionModel,
        apiKey: apiKey,
        generationConfig: defaultConfig,
        systemInstruction: eduInstruction,
      );

      _youtubeModel = GenerativeModel(
        model: AIConfig.youtubeModel,
        apiKey: apiKey,
        generationConfig: proConfig,
        systemInstruction: eduInstruction,
      );

      _educatorModel = GenerativeModel(
        model: AIConfig.primaryModel,
        apiKey: apiKey,
        generationConfig: defaultConfig,
        systemInstruction: eduInstruction,
      );

      _extractorModel = GenerativeModel(
        model: AIConfig.primaryModel,
        apiKey: apiKey,
        generationConfig: defaultConfig,
        systemInstruction: AIConfig.extractorSystemInstruction,
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
  GenerativeModel get educatorModel => _educatorModel!;
  GenerativeModel get extractorModel => _extractorModel!;
  String? get initializationError => _initializationError;

  Future<String> generateWithRetry(String prompt,
      {GenerativeModel? customModel,
      GenerationConfig? generationConfig,
      bool isPro = false,
      CancellationToken? cancelToken}) async {
    return generateMultimodal([TextPart(prompt)],
        customModel: customModel,
        generationConfig: generationConfig,
        isPro: isPro,
        cancelToken: cancelToken);
  }

  /// New method to handle multimodal data (e.g., images, PDFs, audio)
  Future<String> generateWithData(
    String prompt,
    Uint8List data,
    String mimeType, {
    GenerativeModel? customModel,
    GenerationConfig? generationConfig,
    bool isPro = false,
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
      isPro: isPro,
      cancelToken: cancelToken,
    );
  }

  Future<String> generateConversational(String prompt,
      {GenerativeModel? customModel, bool isPro = false, CancellationToken? cancelToken}) async {
    return generateMultimodal([TextPart(prompt)],
        customModel: customModel,
        generationConfig: AIConfig.conversationalGenerationConfig,
        isPro: isPro,
        cancelToken: cancelToken);
  }

  Future<String> generateConversationalWithData(String prompt, Uint8List data, String mimeType,
      {GenerativeModel? customModel, bool isPro = false, CancellationToken? cancelToken}) async {
    return generateMultimodal(
      [
        TextPart(_sanitizeInput(prompt)),
        DataPart(mimeType, data),
      ],
      customModel: customModel,
      generationConfig: AIConfig.conversationalGenerationConfig,
      isPro: isPro,
      cancelToken: cancelToken,
    );
  }

  Future<String> generateMultimodal(List<Part> parts,
      {GenerativeModel? customModel,
      GenerationConfig? generationConfig,
      bool isPro = false,
      CancellationToken? cancelToken}) async {
    developer.log('generateMultimodal called (isPro: $isPro)',
        name: 'AIBaseService');
    if (!await ensureInitialized()) {
      throw AIServiceException('AI Service not ready: $_initializationError',
          code: 'SERVICE_NOT_READY');
    }

    // --- 2026 Anomaly Guardrail ---
    if (AIConfig.isCriticalAnomaly) {
      developer.log(
          'CRITICAL: Blocking request due to high anomaly score (${AIConfig.anomalyScore})',
          name: 'AIBaseService',
          level: 1000);
      throw AIServiceException(
          'Learning circuits are currently over-saturated. Please wait a few minutes for the neural pathway to clear.',
          code: 'SYSTEM_OVERLOADED');
    }

    // Sanitize any TextPart in the parts
    final sanitizedParts = parts.map((part) {
      if (part is TextPart) {
        return TextPart(_sanitizeInput(part.text));
      }
      return part;
    }).toList();

    // --- 2026 Neural Orchestration (Invisible Economy) ---
    if (AIConfig.shouldHardLimit) {
      developer.log('NEURAL CAPACITY DEPLETED: Blocking request silently.', name: 'AIBaseService', level: 1000);
      throw AIServiceException(
          'Your neural momentum is stabilizing. Sumi suggests a short focus break to integrate what you\'ve learned.',
          code: 'CAPACITY_DEPLETED');
    }

    // Model cascade (2026 Adaptive Edition)
    List<GenerativeModel> modelChain = [];
    
    if (customModel != null && !AIConfig.shouldDegradeModel) {
      modelChain.add(customModel);
    }

    // Determine the baseline config for degradation
    final baseConfig = generationConfig ?? AIConfig.defaultGenerationConfig;

    // Adaptive Selection based on Neural State
    if (AIConfig.currentNeuralState == NeuralState.highEnergy) {
      if (isPro) {
        modelChain.addAll([
          _proModel,
          _model,
          _secondaryModel,
        ].whereType<GenerativeModel>());
      } else {
        modelChain.addAll([
          _model,
          _secondaryModel,
          _tertiaryModel,
        ].whereType<GenerativeModel>());
      }
    } else if (AIConfig.currentNeuralState == NeuralState.fatigued) {
      // Fatigued: Efficiency Mode (Flash/Secondary -> Tertiary)
      modelChain.addAll([
        _secondaryModel,
        _tertiaryModel,
        _fallbackModel,
      ].whereType<GenerativeModel>());
      
      // Reduce max output but preserve MIME and Temperature
      generationConfig = GenerationConfig(
          maxOutputTokens: 2048,
          temperature: baseConfig?.temperature,
          responseMimeType: baseConfig?.responseMimeType);
    } else {
      // Exhausted: Survival Mode (Fallback Lite only)
      modelChain.addAll([
        _tertiaryModel,
        _fallbackModel,
      ].whereType<GenerativeModel>());
      
      // Strict truncation but preserve MIME and Temperature
      generationConfig = GenerationConfig(
          maxOutputTokens: 512,
          temperature: baseConfig?.temperature,
          responseMimeType: baseConfig?.responseMimeType);
    }

    if (modelChain.isEmpty) {
      throw AIServiceException('Neural pathways saturated.', code: 'MODEL_NOT_AVAILABLE');
    }

    developer.log('Adaptive Model Chain: ${modelChain.length} model(s) in state ${AIConfig.currentNeuralState}',
        name: 'AIBaseService');

    // 2026 Stability Update: Allowing cascade for all users.
    // Fallback models are essential when the primary hits its 15 RPM free tier limit.

    developer.log('Model cascade chain: ${modelChain.length} model(s)',
        name: 'AIBaseService');

    // --- Adaptive Throttling (Power-User Abuse Protection) ---
    if (AIConfig.isCriticalAnomaly) {
      developer.log('CRITICAL ANOMALY: Hard-stopping cascade chain',
          name: 'AIBaseService');
      modelChain = [modelChain.first]; // Force single attempt only
    } else if (AIConfig.isAnomalyDetected) {
      developer.log('ANOMALY DETECTED: Throttling cascade chain length',
          name: 'AIBaseService');
      if (modelChain.length > 2) modelChain = modelChain.sublist(0, 2);
    }

    int attempt = 0;
    int currentModelIndex = 0;

    while (attempt < AIConfig.maxRetries) {
      try {
        cancelToken?.throwIfCancelled();

        // Pick the model from the chain based on the current cascade level
        final targetModel = modelChain[currentModelIndex % modelChain.length];

        developer.log(
            'AI CALL: Attempting model (ModelIndex: $currentModelIndex, Attempt: $attempt)',
            name: 'AIBaseService');

        final response = await targetModel.generateContent(
          [Content.multi(sanitizedParts)],
          generationConfig: generationConfig,
        ).timeout(const Duration(seconds: AIConfig.requestTimeoutSeconds));

        // Record for anomaly detector (Survival system)
        AIConfig.recordAction(attempt * 10 + 5);

        cancelToken?.throwIfCancelled();

        final text = response.text;
        if (text == null || text.trim().isEmpty) {
          developer.log('Empty or null response from AI',
              name: 'AIBaseService', level: 1000);
          throw AIServiceException('Empty or null response from AI',
              code: 'EMPTY_RESPONSE');
        }

        developer.log(
            'RAW AI RESPONSE (first 200 chars): ${text.length > 200 ? text.substring(0, 200) : text}',
            name: 'AIBaseService');

        developer.log('Successfully generated response', name: 'AIBaseService');
        return text.trim();
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        final isQuotaError = errorMsg.contains('quota') ||
            errorMsg.contains('rate limit') ||
            errorMsg.contains('429') ||
            errorMsg.contains('resource_exhausted') ||
            errorMsg.contains('full') ||
            errorMsg.contains('overloaded');
        final isServerIssue = errorMsg.contains('500') ||
            errorMsg.contains('503') ||
            errorMsg.contains('504') ||
            errorMsg.contains('server error') ||
            errorMsg.contains('unavailable');
        final isTimeout = e is TimeoutException;

        // --- 2026 Anomaly Reporting ---
        if (isQuotaError || isServerIssue) {
          AIConfig.recordAction(
              isQuotaError ? 15 : 40); // Server issues carry higher weight
          developer.log(
              'ANOMALY: Updated score to ${AIConfig.anomalyScore} due to $e',
              name: 'AIBaseService');
        }

        // --- Model Cascade Logic ---
        // If we hit a quota or server error, and we have more models in the chain,
        // move immediately to the next model and reset the attempt counter for that model.
        if ((isQuotaError || isServerIssue || isTimeout) &&
            currentModelIndex < modelChain.length - 1) {
          currentModelIndex++;
          attempt = 0; // Reset retries to give the new model a fair chance
          developer.log(
              'RETRY: Cascading to model at index $currentModelIndex due to error: $e',
              name: 'AIBaseService');
          continue;
        }

        // --- Standard Retry Logic (Same Model) ---
        attempt++;
        if (attempt >= AIConfig.maxRetries) {
          developer.log('Max retries exceeded for current model pipeline',
              name: 'AIBaseService', error: e);
          rethrow;
        }

        final baseDelay = AIConfig.initialRetryDelayMs * pow(2, attempt - 1);
        final jitter = Random().nextInt(1000);
        final delay = min(
          baseDelay.toInt() + jitter,
          AIConfig.maxRetryDelayMs,
        ).toInt();

        if (errorMsg.contains('403') ||
            errorMsg.contains('permission_denied') ||
            errorMsg.contains('api_key_invalid')) {
          developer.log(
              'CRITICAL: API Key appears to be invalid or restricted (403 Forbidden).',
              name: 'AIBaseService',
              level: 1000);
          rethrow; // Don't retry on auth errors
        }

        developer.log(
            'AI Retry attempt $attempt in ${delay}ms on current model',
            name: 'AIBaseService',
            error: e);
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
    throw AIServiceException('Max retries exceeded', code: 'MAX_RETRIES');
  }

  Stream<String> generateStream(String prompt,
      {GenerativeModel? customModel,
      GenerationConfig? generationConfig,
      bool isPro = false,
      CancellationToken? cancelToken}) async* {
    if (!await ensureInitialized()) {
      throw AIServiceException('AI Service not ready', code: 'NOT_READY');
    }

    final sanitizedPrompt = _sanitizeInput(prompt);

    // Model cascade for streaming
    List<GenerativeModel> modelChain = [];
    if (customModel != null && !AIConfig.shouldDegradeModel) {
      modelChain.add(customModel);
    }

    if (AIConfig.currentNeuralState == NeuralState.highEnergy) {
      if (isPro) {
        modelChain.addAll([_proModel, _model, _secondaryModel].whereType<GenerativeModel>());
      } else {
        modelChain.addAll([_model, _secondaryModel, _tertiaryModel].whereType<GenerativeModel>());
      }
    } else {
      modelChain.addAll([_secondaryModel, _tertiaryModel, _fallbackModel].whereType<GenerativeModel>());
    }

    if (modelChain.isEmpty) modelChain = [_model!];

    int currentModelIndex = 0;
    bool success = false;

    while (currentModelIndex < modelChain.length && !success) {
      final targetModel = modelChain[currentModelIndex];
      try {
        final responseStream = targetModel.generateContentStream(
          [Content.text(sanitizedPrompt)],
          generationConfig: generationConfig,
        );

        await for (final chunk in responseStream) {
          cancelToken?.throwIfCancelled();
          final text = chunk.text;
          if (text != null) yield text;
        }
        success = true;
      } catch (e) {
        developer.log('Streaming failed on model $currentModelIndex: $e', name: 'AIBaseService');
        currentModelIndex++;
        if (currentModelIndex >= modelChain.length) {
          rethrow;
        }
        developer.log('Cascading streaming to next model...', name: 'AIBaseService');
      }
    }
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

  /// Safely decode JSON with optional key validation.
  Map<String, dynamic> safeJsonDecode(String jsonStr,
      {List<String>? requiredKeys, Map<String, dynamic> fallback = const {}}) {
    if (jsonStr.isEmpty) return fallback;
    
    try {
      final decoded = json.decode(jsonStr);
      Map<String, dynamic> data;

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      } else if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        // Handle cases where the model returns a list containing the object
        data = Map<String, dynamic>.from(decoded.first);
      } else {
        developer.log(
            'JSON decoded but unexpected type: ${decoded.runtimeType}. First 200 chars: ${jsonStr.length > 200 ? jsonStr.substring(0, 200) : jsonStr}',
            name: 'AIBaseService',
            level: 900);
        return fallback;
      }

      // Validate required keys
      if (requiredKeys != null) {
        final missingKeys =
            requiredKeys.where((key) => !data.containsKey(key)).toList();
        if (missingKeys.isNotEmpty) {
          developer.log('Missing required JSON keys: $missingKeys',
              name: 'AIBaseService', level: 1000);
          
          // Attempt to find keys in nested structures if they are missing at top level
          bool foundAllInNested = true;
          for (final key in missingKeys) {
            bool found = false;
            for (final value in data.values) {
              if (value is Map && value.containsKey(key)) {
                data[key] = value[key];
                found = true;
                break;
              }
            }
            if (!found) {
              foundAllInNested = false;
              break;
            }
          }

          if (!foundAllInNested) {
            throw AIServiceException(
                'Malformed AI response: missing keys $missingKeys',
                code: 'MALFORMED_JSON');
          }
        }
      }

      return data;
    } catch (e) {
      if (e is AIServiceException) rethrow;
      developer.log(
          'JSON decode FAILED: $e\nRaw input (first 500 chars): ${jsonStr.length > 500 ? jsonStr.substring(0, 500) : jsonStr}',
          name: 'AIBaseService',
          level: 1000,
          error: e);
      return fallback;
    }
  }
}

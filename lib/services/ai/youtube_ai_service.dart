import 'dart:async';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'ai_base_service.dart';
import 'ai_config.dart';
import 'dart:developer' as developer;

/// YouTube content extraction service with a 3-tier fallback strategy:
///
/// 1. **Tier 1 — Native Gemini Video Analysis**: Send the YouTube URL directly
///    to Gemini's multimodal model. It natively "watches" the video via its
///    URL context / Browse Tool capability (Gemini 2.5+).
///
/// 2. **Tier 2 — Transcript Extraction + AI Refinement**: Fall back to
///    `youtube_explode_dart` to grab closed captions, then pass raw transcript
///    through Gemini for cleaning and structuring.
///
/// 3. **Tier 3 — Graceful Error**: Return a clear, user-friendly error.
class YouTubeAIService extends AIBaseService {
  /// Analyze a YouTube video URL and extract educational content.
  ///
  /// Uses a 3-tier fallback strategy for maximum reliability.
  /// Pass an optional [cancelToken] to support user-initiated cancellation.
  Future<Result<ExtractionResult>> analyzeVideo(
    String videoUrl, {
    CancellationToken? cancelToken,
  }) async {
    if (!_isValidYouTubeUrl(videoUrl)) {
      return Result.error(EnhancedAIServiceException(
        'Invalid YouTube URL format. Use: https://youtube.com/watch?v=VIDEO_ID',
        code: 'INVALID_URL',
      ));
    }

    // ── Tier 1: Native Gemini Video Analysis ──
    developer.log('Tier 1: Attempting native Gemini video analysis...',
        name: 'YouTubeAIService');
    try {
      cancelToken?.throwIfCancelled();
      final result = await _analyzeWithGeminiNative(videoUrl)
          .timeout(Duration(seconds: AIConfig.youtubeTimeoutSeconds));

      if (result != null && result.text.trim().length >= 100) {
        developer.log('Tier 1 succeeded: ${result.text.length} chars extracted',
            name: 'YouTubeAIService');
        return Result.ok(result);
      }
      developer.log(
          'Tier 1 returned sparse content (${result?.text.length ?? 0} chars), falling to Tier 2',
          name: 'YouTubeAIService');
    } on CancelledException {
      return Result.error(EnhancedAIServiceException(
          'Extraction cancelled by user.',
          code: 'CANCELLED'));
    } on TimeoutException {
      developer.log(
          'Tier 1 timed out after ${AIConfig.youtubeTimeoutSeconds}s, falling to Tier 2',
          name: 'YouTubeAIService');
    } catch (e) {
      developer.log('Tier 1 failed: $e', name: 'YouTubeAIService', error: e);
    }

    // ── Tier 2: Transcript Extraction + AI Refinement ──
    developer.log('Tier 2: Attempting transcript extraction...',
        name: 'YouTubeAIService');
    try {
      cancelToken?.throwIfCancelled();
      final result = await _extractViaTranscript(videoUrl).timeout(Duration(
          seconds:
              AIConfig.transcriptTimeoutSeconds + 30)); // 30s fetch + 30s AI

      if (result != null && result.text.trim().isNotEmpty) {
        developer.log('Tier 2 succeeded: ${result.text.length} chars extracted',
            name: 'YouTubeAIService');
        return Result.ok(result);
      }
      developer.log('Tier 2 returned empty content, falling to Tier 3 (error)',
          name: 'YouTubeAIService');
    } on CancelledException {
      return Result.error(EnhancedAIServiceException(
          'Extraction cancelled by user.',
          code: 'CANCELLED'));
    } on TimeoutException {
      developer.log('Tier 2 timed out, falling to Tier 3 (error)',
          name: 'YouTubeAIService');
    } catch (e) {
      developer.log('Tier 2 failed: $e', name: 'YouTubeAIService', error: e);
    }

    // ── Tier 3: Graceful Error ──
    developer.log('Tier 3: All extraction strategies failed',
        name: 'YouTubeAIService');
    return Result.error(EnhancedAIServiceException(
      'Could not extract content from this video. '
      'The video may be private, age-restricted, too long, or lack captions. '
      'Try a different public YouTube video.',
      code: 'EXTRACTION_FAILED',
    ));
  }

  /// Tier 1: Send the YouTube URL directly to Gemini for native multimodal analysis.
  Future<ExtractionResult?> _analyzeWithGeminiNative(String videoUrl) async {
    if (!await ensureInitialized()) return null;

    final config = GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'title':
              Schema.string(description: 'A high-quality study session title'),
          'content': Schema.string(
              description: 'All the extracted educational text from the video'),
        },
        requiredProperties: ['title', 'content'],
      ),
    );

    // Use "Browse Tool" naming per Google's best practice for URL context
    final prompt =
        '''Analyze this YouTube video and extract ALL educational content for study purposes.

TASK: Use your native YouTube indexing and multimodal understanding (Browse Tool) to "watch" and "listen" to the video content from this URL. Provide a suggested title and all educational content.

CRITICAL INSTRUCTIONS:
1. EXTRACT all instructional content (do NOT summarize)
2. Capture EVERYTHING the instructor teaches:
   - All concepts, definitions, explanations (word-for-word when important)
   - Visual content (slides, diagrams, demonstrations shown in video)
   - Examples, case studies, practice problems
   - Formulas, equations, code, technical details
   - Step-by-step procedures
   - Key timestamps [MM:SS] for important sections

EXCLUDE: intros, promos, sponsor messages, and filler content.

URL: $videoUrl

OUTPUT FORMAT (JSON):
{
  "title": "A high-quality study session title",
  "content": "All the extracted educational text..."
}''';

    final response = await generateWithRetry(
      prompt,
      customModel: youtubeModel,
      generationConfig: config,
    );
    final jsonStr = extractJson(response);
    final data = json.decode(jsonStr);

    final content = data['content'] ?? '';
    final title = data['title'] ?? 'YouTube Video';

    if (content.toString().trim().isEmpty) return null;

    return ExtractionResult(
      text: content,
      suggestedTitle: title,
      sourceUrl: videoUrl,
    );
  }

  /// Tier 2: Extract transcript via youtube_explode_dart, then optionally refine with AI.
  Future<ExtractionResult?> _extractViaTranscript(String videoUrl) async {
    final yt = YoutubeExplode();
    try {
      final videoId = _extractVideoId(videoUrl);
      if (videoId == null) return null;

      final video = await yt.videos
          .get(videoId)
          .timeout(Duration(seconds: AIConfig.transcriptTimeoutSeconds));

      final manifest = await yt.videos.closedCaptions
          .getManifest(videoId)
          .timeout(Duration(seconds: AIConfig.transcriptTimeoutSeconds));

      if (manifest.tracks.isEmpty) {
        developer.log('No captions available for video: $videoId',
            name: 'YouTubeAIService');
        return null;
      }

      final track = manifest.tracks.first;
      final captions = await yt.videos.closedCaptions
          .get(track)
          .timeout(Duration(seconds: AIConfig.transcriptTimeoutSeconds));

      final transcript = captions.captions.map((c) => c.text).join(' ');

      if (transcript.trim().isEmpty) return null;

      return ExtractionResult(
        text: transcript,
        suggestedTitle: video.title,
        sourceUrl: videoUrl,
      );
    } finally {
      // Always close the YoutubeExplode instance to free resources
      yt.close();
    }
  }

  /// Validate that the URL is a valid YouTube URL.
  bool _isValidYouTubeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final validDomains = [
        'youtube.com',
        'www.youtube.com',
        'youtu.be',
        'm.youtube.com'
      ];
      if (!validDomains.contains(uri.host)) return false;
      return uri.path.contains('/watch') ||
          uri.path.contains('/shorts') ||
          uri.path.contains('/live') ||
          uri.host.contains('youtu.be');
    } catch (_) {
      return false;
    }
  }

  /// Extract the video ID from a YouTube URL.
  String? _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }
      if (uri.path.contains('/shorts/')) {
        final segments = uri.pathSegments;
        final index = segments.indexOf('shorts');
        if (index != -1 && index + 1 < segments.length)
          return segments[index + 1];
      }
      if (uri.path.contains('/live/')) {
        final segments = uri.pathSegments;
        final index = segments.indexOf('live');
        if (index != -1 && index + 1 < segments.length)
          return segments[index + 1];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Note: No more instance-level YoutubeExplode — it's created per-call in
  // _extractViaTranscript and closed in its finally block. This avoids
  // resource leaks if dispose() is never called.
}

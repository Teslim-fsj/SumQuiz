import 'dart:async';
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
        'Invalid YouTube URL format.',
        code: 'INVALID_URL',
      ));
    }

    final yt = YoutubeExplode();
    try {
      final videoId = _extractVideoId(videoUrl);
      if (videoId == null) throw Exception('Could not extract video ID.');

      developer.log('Fetching video metadata for $videoId',
          name: 'YouTubeAIService');
      final video = await yt.videos
          .get(videoId)
          .timeout(Duration(seconds: AIConfig.transcriptTimeoutSeconds));

      final duration = video.duration ?? Duration.zero;
      final isShort =
          duration.inSeconds < AIConfig.youtubeMultimodalThresholdSeconds;

      // ── MODE A: Native Multimodal (< 10 min) ──
      if (isShort) {
        developer.log(
            'Mode A: Short video (${duration.inSeconds}s). Using native multimodal.',
            name: 'YouTubeAIService');
        try {
          cancelToken?.throwIfCancelled();
          final result =
              await _analyzeWithGeminiModeA(videoUrl, cancelToken: cancelToken)
                  .timeout(Duration(seconds: AIConfig.youtubeTimeoutSeconds));

          if (result != null && result.text.trim().length >= 100) {
            return Result.ok(result);
          }
          developer.log('Mode A sparse, falling to Mode B/C.',
              name: 'YouTubeAIService');
        } catch (e) {
          developer.log('Mode A failed: $e. Falling to Mode B/C.',
              name: 'YouTubeAIService');
        }
      }

      // ── MODE B/C: Transcript Pipeline (> 10 min or Mode A fail) ──
      developer.log('Using Transcript Pipeline (Mode B/C)...',
          name: 'YouTubeAIService');
      cancelToken?.throwIfCancelled();

      final transcriptData = await _getRawTranscript(yt, videoId);
      if (transcriptData == null || transcriptData.trim().isEmpty) {
        return Result.error(EnhancedAIServiceException(
            'Could not find captions for this video. Use shorter videos or those with available transcripts.',
            code: 'NO_CAPTIONS'));
      }

      // Hard truncation for stability before AI refinement
      final cappedTranscript = transcriptData.length > AIConfig.maxInputLength
          ? transcriptData.substring(0, AIConfig.maxInputLength)
          : transcriptData;

      // Mode C: Transcript refinement
      final refinedResult = await _analyzeWithGeminiModeC(
          cappedTranscript, video.title, videoUrl,
          cancelToken: cancelToken);

      if (refinedResult != null) {
        return Result.ok(refinedResult);
      }

      // Mode B: Fallback to raw transcript if AI refinement fails
      return Result.ok(ExtractionResult(
        text: cappedTranscript,
        suggestedTitle: video.title,
        sourceUrl: videoUrl,
      ));
    } on CancelledException {
      return Result.error(
          EnhancedAIServiceException('Cancelled by user.', code: 'CANCELLED'));
    } catch (e) {
      developer.log('YouTube analysis failed: $e',
          name: 'YouTubeAIService', error: e);
      return Result.error(EnhancedAIServiceException(
          'YouTube extraction failed. The video may be restricted or too long.',
          code: 'EXTRACTION_FAILED'));
    } finally {
      yt.close();
    }
  }

  Future<String?> _getRawTranscript(YoutubeExplode yt, String videoId) async {
    try {
      final manifest = await yt.videos.closedCaptions
          .getManifest(videoId)
          .timeout(Duration(seconds: AIConfig.transcriptTimeoutSeconds));

      if (manifest.tracks.isEmpty) return null;

      final track = manifest.tracks.first;
      final captions = await yt.videos.closedCaptions
          .get(track)
          .timeout(Duration(seconds: AIConfig.transcriptTimeoutSeconds));

      return captions.captions.map((c) => c.text).join(' ');
    } catch (e) {
      return null;
    }
  }

  Future<ExtractionResult?> _analyzeWithGeminiModeA(String videoUrl,
      {CancellationToken? cancelToken}) async {
    if (!await ensureInitialized()) return null;

    final prompt = '''You are a YouTube educational content specialist. 
Your goal is to extract ALL informational, educational, and factual content from this video.

VIDEO URL: $videoUrl

INSTRUCTIONS:
1. Provide a clear, descriptive suggested title.
2. EXTRACT all key facts, concepts, definitions, and explanations.
3. Organize into logical sections with markdown headers.
4. REMOVE intros, outros, ads, and sponsorship segments.
5. If the video is a lecture or tutorial, preserve the logical flow of information.

Output MUST be valid JSON:
{
  "title": "Clean suggested title",
  "text": "The extracted content..."
}''';

    final response = await generateWithRetry(
      prompt,
      customModel: proModel, // Use pro for better video understanding
      cancelToken: cancelToken,
    );

    final data = safeJsonDecode(extractJson(response));
    final content =
        data['text']?.toString() ?? ''; // Changed from 'content' to 'text'
    if (content.isEmpty) return null;

    return ExtractionResult(
      text: content,
      suggestedTitle: data['title']?.toString() ?? 'YouTube Analysis',
      sourceUrl: videoUrl,
    );
  }

  Future<ExtractionResult?> _analyzeWithGeminiModeC(
      String transcript, String title, String videoUrl,
      {CancellationToken? cancelToken}) async {
    if (!await ensureInitialized()) return null;

    final prompt =
        '''Refine and structure this YouTube transcript into a high-quality study guide.
VIDEO TITLE: $title

TRANSCRIPT:
$transcript

TASK: 
1. Fix broken sentences and OCR/speech-to-text glitches.
2. Organize into logical section headings.
3. EXTRACT all educational facts, definitions, and formulas.
4. Maintain an academic, exam-focused tone.

OUTPUT FORMAT (JSON):
{
  "title": "Professional title",
  "content": "Structured Markdown guide..."
}''';

    final response = await generateWithRetry(
      prompt,
      customModel: proModel,
      cancelToken: cancelToken,
    );

    final data = safeJsonDecode(extractJson(response));
    final content = data['content']?.toString() ?? '';
    if (content.isEmpty) return null;

    return ExtractionResult(
      text: content,
      suggestedTitle: data['title']?.toString() ?? title,
      sourceUrl: videoUrl,
    );
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
        if (index != -1 && index + 1 < segments.length) {
          return segments[index + 1];
        }
      }
      if (uri.path.contains('/live/')) {
        final segments = uri.pathSegments;
        final index = segments.indexOf('live');
        if (index != -1 && index + 1 < segments.length) {
          return segments[index + 1];
        }
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

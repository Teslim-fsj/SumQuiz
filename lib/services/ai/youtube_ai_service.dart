import 'dart:async';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'ai_base_service.dart';
import 'ai_config.dart';
import 'dart:developer' as developer;

/// YouTube extraction with a 3-tier strategy:
///
/// Tier 1 — Transcript + Gemini Refinement: fastest for most videos
///   • Fetches closed captions (english preferred, auto-generated OK)
///   • If transcript is long enough, refines it with Gemini into a study guide
///
/// Tier 2 — Raw Transcript Fallback: if Gemini refinement times out
///   • Returns the raw, clean transcript text directly without AI refining
///   • The downstream generator will still produce quiz/flashcard/summary
///
/// Tier 3 — Audio Multimodal: for short videos (<15 min) with NO captions
///   • Downloads audio stream and sends to Gemini vision model
///   • Only used when no transcript is available at all
class YouTubeAIService extends AIBaseService {
  Future<Result<ExtractionResult>> analyzeVideo(
    String videoUrl, {
    CancellationToken? cancelToken,
  }) async {
    if (!_isValidYouTubeUrl(videoUrl)) {
      return Result.error(EnhancedAIServiceException(
        'Invalid YouTube URL format. Please paste a valid youtube.com or youtu.be link.',
        code: 'INVALID_URL',
      ));
    }

    final yt = YoutubeExplode();
    try {
      final videoId = _extractVideoId(videoUrl);
      if (videoId == null) {
        return Result.error(EnhancedAIServiceException(
          'Could not find video ID in the URL.',
          code: 'INVALID_URL',
        ));
      }

      developer.log('Fetching video metadata for $videoId',
          name: 'YouTubeAIService');

      // --- Fetch metadata with a tight timeout ---
      late Video video;
      try {
        video =
            await yt.videos.get(videoId).timeout(const Duration(seconds: 20));
      } on TimeoutException {
        return Result.error(EnhancedAIServiceException(
          'Timed out fetching video info. Check your internet connection.',
          code: 'METADATA_TIMEOUT',
        ));
      }

      cancelToken?.throwIfCancelled();

      final duration = video.duration ?? Duration.zero;
      developer.log('Video: "${video.title}", duration: ${duration.inSeconds}s',
          name: 'YouTubeAIService');

      // ── TIER 1 & 2: Try transcript first (fast, works for most videos) ──
      final transcriptData = await _getRawTranscript(yt, videoId);

      if (transcriptData != null && transcriptData.trim().length >= 200) {
        developer.log(
            'Transcript found: ${transcriptData.length} chars. Attempting Gemini refinement...',
            name: 'YouTubeAIService');

        cancelToken?.throwIfCancelled();

        // Tier 1: Try to refine with Gemini (with a strict timeout)
        try {
          final refined = await _refineTranscriptWithGemini(
            transcript: transcriptData,
            title: video.title,
            videoUrl: videoUrl,
            cancelToken: cancelToken,
          ).timeout(const Duration(seconds: 60));

          if (refined != null && refined.text.trim().length >= 100) {
            developer.log('Tier 1 succeeded: Gemini refinement complete.',
                name: 'YouTubeAIService');
            return Result.ok(refined);
          }
        } on TimeoutException {
          developer.log(
              'Tier 1: Gemini refinement timed out. Falling back to raw transcript.',
              name: 'YouTubeAIService');
        } catch (e) {
          developer.log(
              'Tier 1: Gemini refinement failed: $e. Using raw transcript.',
              name: 'YouTubeAIService');
        }

        // Tier 2: Return raw transcript — still fully usable by the generator
        developer.log('Tier 2: Returning raw transcript as extraction result.',
            name: 'YouTubeAIService');
        final cappedTranscript = transcriptData.length > AIConfig.maxInputLength
            ? transcriptData.substring(0, AIConfig.maxInputLength)
            : transcriptData;

        return Result.ok(ExtractionResult(
          text: cappedTranscript,
          suggestedTitle: video.title,
          sourceUrl: videoUrl,
        ));
      }

      developer.log(
          'No usable transcript (got ${transcriptData?.length ?? 0} chars). Checking video length for Mode A...',
          name: 'YouTubeAIService');

      // ── TIER 3: Audio multimodal (only for short videos without captions) ──
      final isShort = duration.inSeconds > 0 &&
          duration.inSeconds < AIConfig.youtubeMultimodalThresholdSeconds;

      if (isShort) {
        developer.log(
            'Tier 3: Short video (${duration.inSeconds}s), no captions. Attempting audio multimodal...',
            name: 'YouTubeAIService');

        try {
          cancelToken?.throwIfCancelled();
          final result = await _analyzeWithAudioMultimodal(
            yt,
            videoId,
            videoUrl,
            video.title,
            cancelToken: cancelToken,
          ).timeout(Duration(seconds: AIConfig.youtubeTimeoutSeconds));

          if (result != null && result.text.trim().length >= 100) {
            developer.log('Tier 3 audio multimodal succeeded.',
                name: 'YouTubeAIService');
            return Result.ok(result);
          }
        } on TimeoutException {
          developer.log('Tier 3 audio multimodal timed out.',
              name: 'YouTubeAIService');
        } catch (e) {
          developer.log('Tier 3 audio multimodal failed: $e',
              name: 'YouTubeAIService');
        }
      }

      // All tiers failed
      final durationMsg = duration.inSeconds == 0
          ? 'live or upcoming video'
          : duration.inSeconds >= AIConfig.youtubeMultimodalThresholdSeconds
              ? 'video is too long (>${AIConfig.youtubeMultimodalThresholdSeconds ~/ 60} min) and has no captions'
              : 'video has no captions and audio extraction failed';

      return Result.error(EnhancedAIServiceException(
        'Could not extract content from this video: $durationMsg. '
        'Try a video that has captions/subtitles enabled, or is under 15 minutes long.',
        code: 'NO_CONTENT',
      ));
    } on CancelledException {
      return Result.error(
          EnhancedAIServiceException('Cancelled by user.', code: 'CANCELLED'));
    } catch (e) {
      developer.log('YouTube analysis failed: $e',
          name: 'YouTubeAIService', error: e);
      return Result.error(EnhancedAIServiceException(
        'YouTube extraction failed. The video may be private, restricted, or unavailable in your region.',
        code: 'EXTRACTION_FAILED',
      ));
    } finally {
      yt.close();
    }
  }

  /// Fetch captions/transcript from YouTube.
  /// Preference order:
  ///   1. English manual captions
  ///   2. Any manual captions
  ///   3. English auto-generated
  ///   4. Any auto-generated
  ///   5. Any track available
  Future<String?> _getRawTranscript(YoutubeExplode yt, String videoId) async {
    try {
      final manifest = await yt.videos.closedCaptions
          .getManifest(videoId)
          .timeout(Duration(seconds: AIConfig.transcriptTimeoutSeconds));

      if (manifest.tracks.isEmpty) {
        developer.log('No caption tracks found for $videoId',
            name: 'YouTubeAIService');
        return null;
      }

      developer.log(
          'Available caption tracks: ${manifest.tracks.map((t) => "${t.language.code}${t.isAutoGenerated ? "(auto)" : ""}").join(", ")}',
          name: 'YouTubeAIService');

      // Select the best track
      ClosedCaptionTrackInfo? trackInfo;

      // 1. English manual
      trackInfo =
          _findTrack(manifest.tracks, langPrefix: 'en', autoGenerated: false);
      // 2. Any manual
      trackInfo ??= _findTrack(manifest.tracks, autoGenerated: false);
      // 3. English auto
      trackInfo ??=
          _findTrack(manifest.tracks, langPrefix: 'en', autoGenerated: true);
      // 4. Any auto
      trackInfo ??= _findTrack(manifest.tracks, autoGenerated: true);
      // 5. First available
      trackInfo ??= manifest.tracks.first;

      developer.log(
          'Selected caption track: ${trackInfo.language.code} (auto: ${trackInfo.isAutoGenerated})',
          name: 'YouTubeAIService');

      final captions = await yt.videos.closedCaptions
          .get(trackInfo)
          .timeout(Duration(seconds: AIConfig.transcriptTimeoutSeconds));

      // Join captions into clean readable text
      final text = captions.captions
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .join(' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();

      developer.log('Transcript fetched: ${text.length} chars',
          name: 'YouTubeAIService');
      return text.isEmpty ? null : text;
    } on TimeoutException {
      developer.log('Transcript fetch timed out', name: 'YouTubeAIService');
      return null;
    } catch (e) {
      developer.log('Transcript fetch failed: $e', name: 'YouTubeAIService');
      return null;
    }
  }

  ClosedCaptionTrackInfo? _findTrack(
    List<ClosedCaptionTrackInfo> tracks, {
    String? langPrefix,
    required bool autoGenerated,
  }) {
    try {
      return tracks.firstWhere((t) {
        final langMatch =
            langPrefix == null || t.language.code.startsWith(langPrefix);
        return langMatch && t.isAutoGenerated == autoGenerated;
      });
    } catch (_) {
      return null;
    }
  }

  /// Refine a raw transcript into a structured study guide using Gemini.
  Future<ExtractionResult?> _refineTranscriptWithGemini({
    required String transcript,
    required String title,
    required String videoUrl,
    CancellationToken? cancelToken,
  }) async {
    if (!await ensureInitialized()) return null;

    final cappedTranscript =
        transcript.length > 80000 ? transcript.substring(0, 80000) : transcript;

    final prompt =
        '''You are a study guide creator. Transform this YouTube video transcript into a high-quality, structured study guide.

VIDEO TITLE: $title

TRANSCRIPT:
$cappedTranscript

INSTRUCTIONS:
- Identify the main topic and key concepts
- Organize content logically with clear headings
- Extract definitions, facts, formulas, and examples
- Remove filler words, repetition, and off-topic tangents
- Use proper Markdown formatting (##, ###, -, **)
- Be comprehensive — include all educational content''';

    final response = await generateWithRetry(
      prompt,
      customModel: extractorModel,
      cancelToken: cancelToken,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'suggestedTitle': Schema.string(
                description: 'A clean, professional title for the study guide'),
            'content': Schema.string(
                description: 'The full structured study guide in Markdown'),
          },
          requiredProperties: ['suggestedTitle', 'content'],
        ),
      ),
    );

    final jsonStr = extractJson(response);
    final data = safeJsonDecode(jsonStr);
    final content = data['content']?.toString() ?? '';
    if (content.isEmpty) return null;

    return ExtractionResult(
      text: content,
      suggestedTitle: data['suggestedTitle']?.toString() ?? title,
      sourceUrl: videoUrl,
    );
  }

  /// Tier 3: Download audio and send to Gemini multimodal (for short videos with no captions).
  Future<ExtractionResult?> _analyzeWithAudioMultimodal(
    YoutubeExplode yt,
    String videoId,
    String videoUrl,
    String title, {
    CancellationToken? cancelToken,
  }) async {
    if (!await ensureInitialized()) return null;

    final manifest = await yt.videos.streamsClient
        .getManifest(videoId)
        .timeout(const Duration(seconds: 20));

    final audioStreamInfo = manifest.audioOnly.withHighestBitrate();

    final List<int> bytes = [];
    final stream = yt.videos.streamsClient.get(audioStreamInfo);
    await for (final chunk in stream) {
      cancelToken?.throwIfCancelled();
      bytes.addAll(chunk);
    }
    final audioData = Uint8List.fromList(bytes);
    final mimeType = 'audio/${audioStreamInfo.container.name}';

    developer.log(
        'Audio downloaded: ${audioData.length} bytes, MIME: $mimeType',
        name: 'YouTubeAIService');

    final prompt =
        '''Extract all educational content from this YouTube video audio.

VIDEO TITLE: $title
VIDEO URL: $videoUrl

REQUIREMENTS:
- Listen carefully to the entire audio
- Extract ALL key concepts, facts, definitions, and examples
- Organize into a structured Markdown study guide
- Remove filler/non-educational content''';

    final response = await generateWithData(
      prompt,
      audioData,
      mimeType,
      customModel: youtubeModel,
      cancelToken: cancelToken,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'suggestedTitle': Schema.string(),
            'content': Schema.string(),
          },
          requiredProperties: ['suggestedTitle', 'content'],
        ),
      ),
    );

    final jsonStr = extractJson(response);
    final data = safeJsonDecode(jsonStr);
    final content = data['content']?.toString() ?? '';
    if (content.isEmpty) return null;

    return ExtractionResult(
      text: content,
      suggestedTitle: data['suggestedTitle']?.toString() ?? title,
      sourceUrl: videoUrl,
    );
  }

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
}

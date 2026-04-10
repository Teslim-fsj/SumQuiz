import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeService {
  /// Extracts the video ID from various YouTube URL formats.
  String? extractVideoId(String url) {
    if (url.isEmpty) return null;

    // Standard URL: https://www.youtube.com/watch?v=VIDEO_ID
    // Short URL: https://youtu.be/VIDEO_ID
    // Shorts: https://www.youtube.com/shorts/VIDEO_ID
    // Mobile: https://m.youtube.com/watch?v=VIDEO_ID
    
    final RegExp regExp = RegExp(
      r'^(?:https?:\/\/)?(?:www\.|m\.)?(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/))([\w-]{11})(?:\S+)?$',
      caseSensitive: false,
      multiLine: false,
    );

    final Match? match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    return null;
  }

  /// Fetches the transcript for a given YouTube URL.
  Future<String> getTranscript(String url) async {
    final videoId = extractVideoId(url);
    if (videoId == null) {
      throw Exception('Invalid YouTube URL');
    }

    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.closedCaptions.getManifest(videoId);
      if (manifest.tracks.isEmpty) {
        throw Exception('No transcript/captions found for this video.');
      }

      // Prioritize English
      final track = manifest.tracks.firstWhere(
        (t) => t.language.code == 'en',
        orElse: () => manifest.tracks.first,
      );

      final captions = await yt.videos.closedCaptions.get(track);
      
      final buffer = StringBuffer();
      for (var segment in captions.captions) {
        buffer.write('${segment.text} ');
      }
      
      return buffer.toString().trim();
    } catch (e) {
      debugPrint('Error fetching YouTube transcript: $e');
      throw Exception('Could not retrieve transcript. The video might be private or have captions disabled.');
    } finally {
      yt.close();
    }
  }

  /// Fetches metadata for a YouTube video (simplified for 2026 performance).
  Future<Map<String, String>> getVideoMetadata(String url) async {
    final videoId = extractVideoId(url);
    if (videoId == null) return {};

    // In a real 2026 production app, we would use YouTube Data API v3 or a scraper
    // here to get Title and Thumbnail. For this implementation, we return basics.
    return {
      'id': videoId,
      'thumbnail': 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
      'url': url,
    };
  }
}

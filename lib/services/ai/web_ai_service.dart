import 'dart:async';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html;
import 'package:http/http.dart' as http;
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'ai_base_service.dart';
import 'ai_config.dart';
import 'ai_types.dart';
import 'dart:developer' as developer;

/// Webpage content extraction service with a 2-tier strategy:
///
/// 1. **Tier 1 — HTML Parsing**: Fetch + parse HTML directly (fast, no AI cost)
/// 2. **Tier 2 — Gemini URL Analysis**: If HTML parsing yields sparse content,
///    send the URL directly to Gemini's URL Context / Browse Tool for
///    AI-powered extraction (handles JS-rendered pages, paywalled previews, etc.)
class WebAIService extends AIBaseService {
  /// Extract content from a webpage URL.
  ///
  /// Pass an optional [cancelToken] to support user-initiated cancellation.
  Future<Result<ExtractionResult>> extractWebpage(
    String url, {
    CancellationToken? cancelToken,
  }) async {
    // ── Tier 1: Direct HTML Parsing (fast, no AI cost) ──
    developer.log('Tier 1: Attempting direct HTML parsing...',
        name: 'WebAIService');
    try {
      cancelToken?.throwIfCancelled();

      final response = await http
          .get(Uri.parse(url))
          .timeout(Duration(seconds: AIConfig.webpageTimeoutSeconds));

      if (response.statusCode != 200) {
        developer.log('HTTP ${response.statusCode} — falling to Tier 2',
            name: 'WebAIService');
      } else {
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.toLowerCase().contains('text/html')) {
          final document = html_parser.parse(response.body);
          final cleanText = _extractMainContent(document);
          final title = _extractTitle(document);

          if (cleanText.trim().length >= 100) {
            developer.log(
                'Tier 1 succeeded: ${cleanText.length} chars extracted',
                name: 'WebAIService');
            return Result.ok(ExtractionResult(
              text: cleanText,
              suggestedTitle: title,
              sourceUrl: url,
            ));
          }
          developer.log(
              'Tier 1 returned sparse content (${cleanText.length} chars), falling to Tier 2',
              name: 'WebAIService');
        } else {
          developer.log(
              'Non-HTML content type: $contentType — falling to Tier 2',
              name: 'WebAIService');
        }
      }
    } on CancelledException {
      return Result.error(EnhancedAIServiceException(
          'Extraction cancelled by user.',
          code: 'CANCELLED'));
    } on TimeoutException {
      developer.log('Tier 1 timed out, falling to Tier 2',
          name: 'WebAIService');
    } on FormatException {
      return Result.error(EnhancedAIServiceException(
          'Invalid URL format. Please check the URL and try again.'));
    } on SocketException {
      return Result.error(EnhancedAIServiceException(
          'Network error. Please check your internet connection.'));
    } catch (e) {
      developer.log('Tier 1 failed: $e', name: 'WebAIService', error: e);
    }

    // ── Tier 2: Gemini URL Analysis (handles JS-heavy, sparse, or non-HTML pages) ──
    developer.log('Tier 2: Attempting Gemini URL analysis...',
        name: 'WebAIService');
    try {
      cancelToken?.throwIfCancelled();
      final result = await _analyzeWithGemini(url, cancelToken: cancelToken)
          .timeout(Duration(seconds: AIConfig.youtubeTimeoutSeconds));

      if (result != null && result.text.trim().length >= 50) {
        developer.log('Tier 2 succeeded: ${result.text.length} chars extracted',
            name: 'WebAIService');
        return Result.ok(result);
      }
      developer.log('Tier 2 returned sparse content', name: 'WebAIService');
    } on CancelledException {
      return Result.error(EnhancedAIServiceException(
          'Extraction cancelled by user.',
          code: 'CANCELLED'));
    } on TimeoutException {
      developer.log('Tier 2 timed out', name: 'WebAIService');
    } catch (e) {
      developer.log('Tier 2 failed: $e', name: 'WebAIService', error: e);
    }

    return Result.error(EnhancedAIServiceException(
      'No readable content found on this page. '
      'The page may require login, be behind a paywall, or have minimal text content.',
      code: 'NO_CONTENT',
    ));
  }

  /// Tier 2: Send the URL to Gemini for AI-powered content extraction.
  Future<ExtractionResult?> _analyzeWithGemini(String url,
      {CancellationToken? cancelToken}) async {
    if (!await ensureInitialized()) return null;

    final config = GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'title': Schema.string(
              description: 'A clear, descriptive title for this content'),
          'content': Schema.string(
              description: 'All educational/informational text from the page'),
        },
        requiredProperties: ['title', 'content'],
      ),
    );

    final prompt =
        '''Extract ALL educational and informational content from this webpage URL.

TASK: Use your Browse Tool / URL context capability to access and read the content at this URL.

INSTRUCTIONS:
1. EXTRACT (not summarize) all text content from the page
2. Include: headings, paragraphs, lists, definitions, examples, code, data
3. EXCLUDE: navigation menus, ads, footers, cookie banners, promotional content
4. Organize the output with clear section headings
5. Preserve the original structure and hierarchy

URL: $url

OUTPUT FORMAT (JSON):
{
  "title": "Descriptive title for the page content",
  "content": "All extracted text..."
}''';

    final response = await generateWithRetry(
      prompt,
      customModel: model,
      generationConfig: config,
      cancelToken: cancelToken,
    );
    final jsonStr = extractJson(response);
    final data = safeJsonDecode(jsonStr);

    final content = data['content']?.toString() ?? '';
    final title = data['title']?.toString() ?? 'Web Page';

    if (content.trim().isEmpty) return null;

    return ExtractionResult(
      text: content,
      suggestedTitle: title,
      sourceUrl: url,
    );
  }

  /// Extract main content from HTML document, removing boilerplate
  String _extractMainContent(html.Document document) {
    // Remove unwanted elements that pollute content
    final unwantedSelectors = [
      'script',
      'style',
      'nav',
      'footer',
      'header',
      'aside',
      'iframe',
      'noscript',
      'form',
      '.advertisement',
      '.ad',
      '.social-share',
      '.comments',
      '.related-posts'
    ];

    for (var selector in unwantedSelectors) {
      document.querySelectorAll(selector).forEach((e) => e.remove());
    }

    // Try to find main content area (in order of preference)
    final mainContent = document.querySelector('article') ??
        document.querySelector('main') ??
        document.querySelector('[role="main"]') ??
        document.querySelector('.article-content') ??
        document.querySelector('.post-content') ??
        document.querySelector('.entry-content') ??
        document.querySelector('.content') ??
        document.querySelector('#content') ??
        document.body;

    if (mainContent == null) return '';

    // Extract text
    String text = mainContent.text;

    // Clean up whitespace and formatting
    text = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');

    return text;
  }

  /// Extract title from HTML document using multiple sources
  String _extractTitle(html.Document document) {
    // Try Open Graph title first (most reliable for articles)
    final ogTitle = document
        .querySelector('meta[property="og:title"]')
        ?.attributes['content'];
    if (ogTitle != null && ogTitle.isNotEmpty) return ogTitle.trim();

    // Try Twitter card title
    final twitterTitle = document
        .querySelector('meta[name="twitter:title"]')
        ?.attributes['content'];
    if (twitterTitle != null && twitterTitle.isNotEmpty) {
      return twitterTitle.trim();
    }

    // Try H1 heading
    final h1 = document.querySelector('h1')?.text;
    if (h1 != null && h1.trim().isNotEmpty) return h1.trim();

    // Fallback to page title
    final pageTitle = document.head?.querySelector('title')?.text;
    if (pageTitle != null && pageTitle.isNotEmpty) return pageTitle.trim();

    return 'Web Page';
  }
}

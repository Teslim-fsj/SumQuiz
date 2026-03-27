import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'ai_base_service.dart';
import 'ai_config.dart';
import 'ai_types.dart';
import 'dart:developer' as developer;

/// Webpage content extraction service with a 2-tier strategy:
///
/// 1. **Tier 1 — Native Gemini Grounding**: Gemini 3.1 uses internal tools to fetch/read live pages.
/// 2. **Tier 2 — Direct HTML Parsing**: Fallback to manual HTTP fetch and local parsing.
class WebAIService extends AIBaseService {
  /// Extract content from a webpage URL.
  Future<Result<ExtractionResult>> extractWebpage(
    String url, {
    CancellationToken? cancelToken,
  }) async {
    if (!_isValidUrl(url)) {
      return Result.error(EnhancedAIServiceException('Invalid URL format',
          code: 'INVALID_URL'));
    }

    // ── Tier 1: Native Gemini Grounding (The "2026" way) ──
    developer.log('Tier 1: Attempting native Gemini grounding for $url',
        name: 'WebAIService');
    try {
      final geminiResult = await _analyzeWithGemini(url, cancelToken: cancelToken)
          .timeout(const Duration(seconds: AIConfig.webpageTimeoutSeconds + 30));
      
      if (geminiResult != null && geminiResult.text.length > 500) {
        developer.log('Tier 1 succeeded with grounding.', name: 'WebAIService');
        return Result.ok(geminiResult);
      }
      developer.log('Tier 1 result sparse, attempting Tier 2 (HTML parsing)', name: 'WebAIService');
    } on CancelledException {
      return Result.error(EnhancedAIServiceException(
          'Extraction cancelled by user.',
          code: 'CANCELLED'));
    } on TimeoutException {
      developer.log('Tier 1 (Gemini grounding) timed out for $url. Falling back to Tier 2.', name: 'WebAIService');
    } catch (e) {
      developer.log('Tier 1 (Gemini grounding) failed for $url: $e. Falling back to Tier 2.', name: 'WebAIService', error: e);
    }

    // ── Tier 2: Traditional HTML Parsing fallback ──
    developer.log('Tier 2: Attempting traditional HTML parsing for $url', name: 'WebAIService');
    try {
      final doc = await _fetchDocument(url);
      if (doc == null) {
        return Result.error(EnhancedAIServiceException('Failed to fetch webpage or non-HTML content',
            code: 'FETCH_FAILED'));
      }

      final title = _extractTitle(doc);
      final mainContent = _extractMainContent(doc);

      if (mainContent.trim().length < 100) {
        return Result.error(EnhancedAIServiceException(
          'No readable content found on this page via HTML parsing. '
          'The page may require login, be behind a paywall, or have minimal text content.',
          code: 'NO_CONTENT',
        ));
      }

      developer.log('Tier 2 succeeded with HTML parsing.', name: 'WebAIService');
      return Result.ok(ExtractionResult(
        text: mainContent,
        suggestedTitle: title,
        sourceUrl: url,
      ));
    } on CancelledException {
      return Result.error(EnhancedAIServiceException(
          'Extraction cancelled by user.',
          code: 'CANCELLED'));
    } catch (e) {
      developer.log('Tier 2 failed: $e', name: 'WebAIService', error: e);
      return Result.error(EnhancedAIServiceException('Web extraction failed: $e'));
    }
  }

  /// Tier 1 helper: Send the URL to Gemini for AI-powered content extraction.
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
        '''Analyze and extract ALL educational and informational content from this webpage URL.

TASK:
1. USE your Google Search / Browse Tool to access and read the LIVE version of this URL.
2. EXTRACT (do not just summarize) all core text, definitions, examples, and data.
3. Organize the output into clear section headings as a study guide.

INSTRUCTIONS:
- Include: headings, paragraphs, lists, code, and tables.
- Exclude: ads, footers, navigation menus, and non-educational boilerplate.
- Ensure the extraction is high-fidelity to the source.

URL: $url

OUTPUT (JSON):
{
  "title": "Descriptive title for the page content",
  "content": "All extracted structured text in Markdown..."
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

  /// Private helper to fetch and parse HTML document
  Future<html.Document?> _fetchDocument(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          })
          .timeout(Duration(seconds: AIConfig.webpageTimeoutSeconds));

      if (response.statusCode != 200) return null;
      
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('text/html')) return null;

      return html_parser.parse(response.body);
    } catch (e) {
      developer.log('Error fetching document: $e', name: 'WebAIService');
      return null;
    }
  }

  /// Extract main content from HTML document, removing boilerplate
  String _extractMainContent(html.Document document) {
    // Remove unwanted elements
    final unwantedSelectors = [
      'script', 'style', 'nav', 'footer', 'header', 'aside', 'iframe', 
      'noscript', 'form', '.advertisement', '.ad', '.social-share', 
      '.comments', '.related-posts'
    ];

    for (var selector in unwantedSelectors) {
      document.querySelectorAll(selector).forEach((e) => e.remove());
    }

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

    String text = mainContent.text;
    text = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');

    return text;
  }

  /// Extract title from HTML document
  String _extractTitle(html.Document document) {
    final ogTitle = document
        .querySelector('meta[property="og:title"]')
        ?.attributes['content'];
    if (ogTitle != null && ogTitle.isNotEmpty) return ogTitle.trim();

    final twitterTitle = document
        .querySelector('meta[name="twitter:title"]')
        ?.attributes['content'];
    if (twitterTitle != null && twitterTitle.isNotEmpty) {
      return twitterTitle.trim();
    }

    final h1 = document.querySelector('h1')?.text;
    if (h1 != null && h1.trim().isNotEmpty) return h1.trim();

    final pageTitle = document.head?.querySelector('title')?.text;
    if (pageTitle != null && pageTitle.isNotEmpty) return pageTitle.trim();

    return 'Web Page';
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }
}

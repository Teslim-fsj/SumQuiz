import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'ai_base_service.dart';
import 'ai_config.dart';
import 'ai_types.dart';

/// PDF content extraction and understanding service.
///
/// Uses a 2-tier strategy:
///   1. **Tier 1 — Native Gemini PDF Understanding**: Send PDF bytes inline as a
///      `DataPart` so Gemini can read the full layout, tables, and figures natively.
///   2. **Tier 2 — Text fallback**: Caller provides pre-extracted text as fallback
///      if Tier 1 fails (e.g., due to file size limits or quota).
class PdfAIService extends AIBaseService {
  /// Extract content from a PDF file provided as raw bytes.
  ///
  /// [pdfBytes] — Raw bytes of the PDF document.
  /// [filename] — Optional display name for logging.
  /// [fallbackText] — Pre-extracted text to use if native PDF processing fails.
  Future<Result<ExtractionResult>> extractPdf(
    Uint8List pdfBytes, {
    String filename = 'document.pdf',
    String? fallbackText,
    CancellationToken? cancelToken,
  }) async {
    developer.log(
        'PDF extraction started for "$filename" (${(pdfBytes.length / 1024).toStringAsFixed(0)} KB)',
        name: 'PdfAIService');

    // Enforce 100MB limit (Gemini File API inline limit as of Jan 2026)
    if (pdfBytes.length > AIConfig.maxPdfSize) {
      developer.log(
          'PDF too large (${pdfBytes.length} bytes > ${AIConfig.maxPdfSize}). Using text fallback.',
          name: 'PdfAIService');
      return _fallbackToText(fallbackText, filename);
    }

    // ── Tier 1: Native Gemini PDF Understanding ──
    developer.log('Tier 1: Attempting native Gemini PDF understanding...',
        name: 'PdfAIService');
    try {
      cancelToken?.throwIfCancelled();

      final result = await _analyzeWithGemini(
        pdfBytes,
        filename: filename,
        cancelToken: cancelToken,
      ).timeout(const Duration(seconds: AIConfig.masterExtractionTimeoutSeconds));

      if (result != null && result.text.trim().length >= 100) {
        developer.log('Tier 1 succeeded: ${result.text.length} chars extracted',
            name: 'PdfAIService');
        return Result.ok(result);
      }

      developer.log('Tier 1 returned sparse content, trying fallback',
          name: 'PdfAIService');
    } on CancelledException {
      return Result.error(
          EnhancedAIServiceException('Extraction cancelled by user.',
              code: 'CANCELLED'));
    } on TimeoutException {
      developer.log('Tier 1 timed out, falling to text fallback',
          name: 'PdfAIService');
    } catch (e) {
      developer.log('Tier 1 failed: $e', name: 'PdfAIService', error: e);
    }

    // ── Tier 2: Text Fallback ──
    return _fallbackToText(fallbackText, filename);
  }

  /// Analyze multimodal media file (audio or video) and extract educational content.
  ///
  /// Supports: `audio/*` and `video/*`
  /// Gemini 2.5+ can process up to 8.4 hours of media per prompt.
  Future<Result<ExtractionResult>> extractMultimodalMedia(
    Uint8List mediaBytes,
    String mimeType, {
    String filename = 'media',
    CancellationToken? cancelToken,
  }) async {
    developer.log(
        'Media extraction started for "$filename" (${(mediaBytes.length / 1024).toStringAsFixed(0)} KB, $mimeType)',
        name: 'PdfAIService');

    if (!await ensureInitialized()) {
      return Result.error(
          EnhancedAIServiceException('AI service not ready.', code: 'NOT_READY'));
    }

    try {
      cancelToken?.throwIfCancelled();

      final config = GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'title': Schema.string(description: 'Topic-focused title'),
            'content': Schema.string(
                description:
                    'Full transcript and/or structured educational content'),
            'language': Schema.string(description: 'Detected language code'),
          },
          requiredProperties: ['title', 'content'],
        ),
      );

      final prompt = '''You are analyzing a ${mimeType.startsWith('video') ? 'video' : 'audio'} recording (lecture, lesson, or talk).

TASK:
1. ${mimeType.startsWith('video') ? 'Watch and listen to' : 'Listen to'} the media content deeply
2. Extract all educational concepts, facts, definitions, and examples
3. Structure the output as a coherent study document in Markdown
4. If it's a video, describe any key visual aids (slides, whiteboard drawings) that are crucial for understanding.

OUTPUT (JSON):
{
  "title": "Clear, descriptive title of the topic covered",
  "content": "Full structured educational content — organized with headings, key points, and examples",
  "language": "en"
}''';

      final response = await generateMultimodal(
        [TextPart(prompt), DataPart(mimeType, mediaBytes)],
        customModel: mimeType.startsWith('video') ? visionModel : educatorModel,
        generationConfig: config,
        cancelToken: cancelToken,
      ).timeout(Duration(seconds: AIConfig.masterExtractionTimeoutSeconds));

      final data = safeJsonDecode(extractJson(response));
      final content = data['content']?.toString() ?? '';
      final title = data['title']?.toString() ?? 'Media Recording';

      if (content.trim().isEmpty) {
        return Result.error(EnhancedAIServiceException(
            'No content could be extracted from the media.',
            code: 'NO_CONTENT'));
      }

      return Result.ok(ExtractionResult(
        text: content,
        suggestedTitle: title,
        sourceUrl: 'media:$filename',
      ));
    } on CancelledException {
      return Result.error(
          EnhancedAIServiceException('Extraction cancelled.', code: 'CANCELLED'));
    } on TimeoutException {
      return Result.error(
          EnhancedAIServiceException('Media processing timed out. Try a shorter file.',
              code: 'TIMEOUT'));
    } catch (e) {
      developer.log('Media extraction failed: $e',
          name: 'PdfAIService', error: e);
      return Result.error(
          EnhancedAIServiceException('Media extraction failed: $e'));
    }
  }

  Future<ExtractionResult?> _analyzeWithGemini(
    Uint8List pdfBytes, {
    required String filename,
    CancellationToken? cancelToken,
  }) async {
    if (!await ensureInitialized()) return null;

    final config = GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'title': Schema.string(
              description: 'Main topic or document title'),
          'content': Schema.string(
              description:
                  'All educational content: headings, definitions, examples, tables, equations'),
        },
        requiredProperties: ['title', 'content'],
      ),
    );

    const prompt = '''You are analyzing a PDF document.

TASK:
1. READ the entire document — all pages, text, tables, and visible diagrams
2. EXTRACT all educational/informational content
3. PRESERVE the document's structure: headings, sub-headings, bullet lists, tables
4. INCLUDE formulas, equations, code snippets, and data verbatim
5. EXCLUDE: headers/footers, page numbers, watermarks, table of contents page entries

OUTPUT (JSON):
{
  "title": "Document title or main topic",
  "content": "Complete structured content in Markdown format..."
}''';

    final response = await generateMultimodal(
      [TextPart(prompt), DataPart('application/pdf', pdfBytes)],
      customModel: educatorModel,
      generationConfig: config,
      cancelToken: cancelToken,
    );

    final data = safeJsonDecode(extractJson(response));
    final content = data['content']?.toString() ?? '';
    final title = data['title']?.toString() ?? filename;

    if (content.trim().isEmpty) return null;

    return ExtractionResult(
      text: content,
      suggestedTitle: title,
      sourceUrl: 'pdf:$filename',
    );
  }

  /// Analyze image content (textbook pages, diagrams, screenshots).
  Future<Result<ExtractionResult>> extractImage(
    Uint8List imageBytes,
    String mimeType, {
    String filename = 'image.jpg',
    CancellationToken? cancelToken,
  }) async {
    developer.log(
        'Image extraction started for "$filename" (${(imageBytes.length / 1024).toStringAsFixed(0)} KB, $mimeType)',
        name: 'PdfAIService');

    if (!await ensureInitialized()) {
      return Result.error(
          EnhancedAIServiceException('AI service not ready.', code: 'NOT_READY'));
    }

    try {
      cancelToken?.throwIfCancelled();

      final config = GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'title': Schema.string(description: 'Descriptive title'),
            'content': Schema.string(
                description: 'Full extracted text, including descriptions of tables/diagrams if relevant'),
          },
          requiredProperties: ['title', 'content'],
        ),
      );

      const prompt = '''You are analyzing an image (textbook page, slide, or handwritten notes).

TASK:
1. READ and EXTRACT all educational text from the image
2. DESCRIBE any relevant diagrams, charts, or tables in Markdown
3. PRESERVE the logical flow and hierarchy of the information

OUTPUT (JSON):
{
  "title": "Clear title of the topic in the image",
  "content": "All extracted structured text and visual descriptions in Markdown..."
}''';

      final response = await generateMultimodal(
        [TextPart(prompt), DataPart(mimeType, imageBytes)],
        customModel: visionModel,
        generationConfig: config,
        cancelToken: cancelToken,
      ).timeout(const Duration(seconds: AIConfig.masterExtractionTimeoutSeconds));

      final data = safeJsonDecode(extractJson(response));
      final content = data['content']?.toString() ?? '';
      final title = data['title']?.toString() ?? 'Scanned Image';

      if (content.trim().isEmpty) {
        return Result.error(EnhancedAIServiceException(
            'No content could be extracted from the image.',
            code: 'NO_CONTENT'));
      }

      return Result.ok(ExtractionResult(
        text: content,
        suggestedTitle: title,
        sourceUrl: 'image:$filename',
      ));
    } on CancelledException {
      return Result.error(
          EnhancedAIServiceException('Extraction cancelled.', code: 'CANCELLED'));
    } on TimeoutException {
      return Result.error(
          EnhancedAIServiceException('Image analysis timed out.', code: 'TIMEOUT'));
    } catch (e) {
      developer.log('Image extraction failed: $e',
          name: 'PdfAIService', error: e);
      return Result.error(
          EnhancedAIServiceException('Image analysis failed: $e'));
    }
  }

  Result<ExtractionResult> _fallbackToText(String? text, String filename) {
    if (text != null && text.trim().length >= 50) {
      developer.log('Tier 2 fallback succeeded using provided text',
          name: 'PdfAIService');
      return Result.ok(ExtractionResult(
        text: text,
        suggestedTitle: filename.replaceAll('.pdf', '').trim(),
        sourceUrl: 'pdf:$filename',
      ));
    }
    return Result.error(EnhancedAIServiceException(
        'Could not extract content from this PDF. '
        'Try pasting the text directly or uploading a text-based PDF.',
        code: 'NO_CONTENT'));
  }
}

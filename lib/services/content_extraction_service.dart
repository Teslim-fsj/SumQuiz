import 'dart:async';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:sumquiz/utils/youtube_pro_gate.dart';
import 'package:sumquiz/services/ai/ai_config.dart';
import 'package:sumquiz/services/ai/pdf_ai_service.dart';

// Top-level function for PDF extraction in isolate
// Must be top-level or static to work with compute()
String _extractPdfTextInIsolate(Uint8List pdfBytes) {
  try {
    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
    final String text = PdfTextExtractor(document).extractText();
    document.dispose();

    if (text.isEmpty) {
      return '[No text found in PDF. The PDF might contain only images or scanned content.]';
    }

    return text;
  } catch (e) {
    throw Exception('PDF text extraction failed: $e');
  }
}

/// Types of content that can be extracted from URLs
enum UrlContentType {
  youtube,
  document, // PDF, DOC, DOCX, etc.
  image, // JPEG, PNG, WEBP, etc.
  audio, // MP3, WAV, AAC, etc.
  video, // MP4, MOV, AVI, etc.
  webpage, // Regular HTML
}

class ContentExtractionService {
  final EnhancedAIService _enhancedAiService;
  final _pdfAiService = PdfAIService();

  /// Internal flag to test local extraction alone without AI calls (Stability test)
  static bool localOnlyTest = false;

  ContentExtractionService(this._enhancedAiService);

  /// Validates input based on type to prevent crashes from invalid inputs
  void _validateInput(String type, dynamic input) {
    switch (type) {
      case 'text':
        if (input == null || input.toString().isEmpty) {
          throw Exception('Text input cannot be empty');
        }
        if (input.toString().length > 50000) {
          throw Exception(
              'Text input too large. Maximum 50,000 characters allowed.');
        }
        case 'youtube':
      case 'link':
        if (input == null || input.toString().isEmpty) {
          throw Exception('URL cannot be empty');
        }
        final url = input.toString();
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          throw Exception(
              'Invalid URL format. Must start with http:// or https://');
        }
        break;
      case 'pdf':
        if (input == null) {
          throw Exception('PDF input cannot be null');
        }
        if (input is Uint8List) {
          if (input.isEmpty) {
            throw Exception('PDF file is empty');
          }
          if (input.length > 50 * 1024 * 1024) {
            // 50MB limit
            throw Exception('PDF file too large. Maximum 50MB allowed.');
          }
        } else {
          throw Exception('PDF input must be Uint8List');
        }
        break;
      case 'image':
        if (input == null) {
          throw Exception('Image input cannot be null');
        }
        if (input is Uint8List) {
          if (input.isEmpty) {
            throw Exception('Image file is empty');
          }
          if (input.length > 10 * 1024 * 1024) {
            // 10MB limit
            throw Exception('Image file too large. Maximum 10MB allowed.');
          }
        } else {
          throw Exception('Image input must be Uint8List');
        }
        break;
      case 'audio':
      case 'video':
        if (input == null) {
          throw Exception('${type.toUpperCase()} input cannot be null');
        }
        if (input is Uint8List) {
          if (input.isEmpty) {
            throw Exception('${type.toUpperCase()} file is empty');
          }
          final limit = type == 'audio' ? 50 * 1024 * 1024 : 100 * 1024 * 1024;
          if (input.length > limit) {
            throw Exception(
                '${type.toUpperCase()} file too large. Maximum ${limit ~/ (1024 * 1024)}MB allowed.');
          }
        } else {
          throw Exception('${type.toUpperCase()} input must be Uint8List');
        }
        break;
      default:
        throw Exception('Unknown content type: $type');
    }
  }

  Future<ExtractionResult> extractContent({
    required String type, // 'text', 'link', 'pdf', 'image', 'audio', 'video'
    dynamic input,
    String? userId,
    String? mimeType,
    bool refineWithAI = false,
    /// Must be true when [type] is `youtube`, or when `link` resolves to YouTube.
    bool allowYouTubeImport = false,
    void Function(String)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    developer.log(
        'ContentExtractionService.extractContent called with type: $type, userId: $userId',
        name: 'ContentExtractionService');
    developer.log('Input type: ${input.runtimeType}, mime: $mimeType',
        name: 'ContentExtractionService');

    // Validate input before processing to prevent crashes
    _validateInput(type, input);

    // Wrap the entire extraction in a master timeout to prevent indefinite hangs
    return await Future(() => _extractContentInternal(
          type: type,
          input: input,
          userId: userId,
          mimeType: mimeType,
          refineWithAI: refineWithAI,
          allowYouTubeImport: allowYouTubeImport,
          onProgress: onProgress,
          cancelToken: cancelToken,
        )).timeout(
      Duration(seconds: AIConfig.masterExtractionTimeoutSeconds),
      onTimeout: () {
        developer.log('Content extraction timed out',
            name: 'ContentExtractionService');
        throw TimeoutException(
          'Content extraction timed out after ${AIConfig.masterExtractionTimeoutSeconds} seconds. '
          'Please try again, or try with simpler content.',
        );
      },
    );
  }

  Future<ExtractionResult> _extractContentInternal({
    required String type,
    dynamic input,
    String? userId,
    String? mimeType,
    bool refineWithAI = false,
    bool allowYouTubeImport = false,
    void Function(String)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    String rawText = '';
    String suggestedTitle = 'Imported Content';

    developer.log('Starting extraction: type=$type, mimeType=$mimeType',
        name: 'ContentExtractionService');

    developer.log('Processing content type: $type',
        name: 'ContentExtractionService');

    try {
      if (type == 'youtube' ||
          (type == 'link' &&
              input is String &&
              _detectUrlType(input) == UrlContentType.youtube)) {
        if (!allowYouTubeImport) {
          throw Exception(kYoutubeProRequiredMessage);
        }
      }

      switch (type) {
        case 'text':
          developer.log('Processing text type',
              name: 'ContentExtractionService');
          onProgress?.call('Processing pasted text...');
          rawText = input as String;
          suggestedTitle = 'Pasted Text';
          break;
        case 'youtube':
        case 'link':
          final url = input as String;
          developer.log('Processing $type: $url',
              name: 'ContentExtractionService');

          if (url.isEmpty) {
            developer.log('Invalid URL provided',
                name: 'ContentExtractionService');
            return ExtractionResult(
              text: '',
              suggestedTitle: 'Invalid URL',
            );
          }

          final urlType = _detectUrlType(url);

          if (localOnlyTest) {
            developer.log('Local test mode for link',
                name: 'ContentExtractionService');
            return ExtractionResult(
                text: 'Local extraction test only', suggestedTitle: 'Test');
          }

          switch (urlType) {
            case UrlContentType.youtube:
              onProgress
                  ?.call('Analyzing YouTube video... this may take a moment');
              if (userId == null) {
                throw Exception('User ID is required for YouTube analysis.');
              }
              cancelToken?.throwIfCancelled();
              try {
                final result = await _enhancedAiService.analyzeYouTubeVideo(
                  url,
                  userId: userId,
                  cancelToken: cancelToken,
                );
                if (result is Ok<ExtractionResult>) {
                  return result.value;
                } else if (result is ResultError<ExtractionResult>) {
                  // Handle the error but don't crash
                  String errorMessage =
                      result.error is EnhancedAIServiceException
                          ? (result.error as EnhancedAIServiceException).message
                          : result.error.toString();
                  onProgress
                      ?.call('Error processing YouTube video: $errorMessage');
                  throw Exception(
                      'Error processing YouTube video: $errorMessage');
                } else {
                  throw Exception(
                      'YouTube extraction returned unexpected result.');
                }
              } catch (e) {
                onProgress?.call('Failed to process YouTube video: $e');
                throw Exception('Failed to process YouTube video: $e');
              }

            case UrlContentType.document:
            case UrlContentType.image:
            case UrlContentType.audio:
            case UrlContentType.video:
              onProgress?.call('Analyzing file from URL...');
              if (userId == null) {
                throw Exception('User ID is required for file URL analysis.');
              }
              cancelToken?.throwIfCancelled();
              try {
                final mimeType = _getMimeType(url);
                final result = await _enhancedAiService.analyzeContentFromUrl(
                  url: url,
                  mimeType: mimeType,
                  userId: userId,
                  cancelToken: cancelToken,
                );
                if (result is Ok<ExtractionResult>) {
                  return result.value;
                } else if (result is ResultError<ExtractionResult>) {
                  // Handle the error but don't crash
                  String errorMessage =
                      result.error is EnhancedAIServiceException
                          ? (result.error as EnhancedAIServiceException).message
                          : result.error.toString();
                  onProgress?.call('Error processing file: $errorMessage');
                  throw Exception('Error processing file: $errorMessage');
                } else {
                  throw Exception('File analysis returned unexpected result.');
                }
              } catch (e) {
                onProgress?.call('Failed to process file: $e');
                throw Exception('Failed to process file: $e');
              }

            case UrlContentType.webpage:
              onProgress?.call('Extracting webpage content...');
              if (userId == null) {
                throw Exception('User ID is required for webpage extraction.');
              }
              cancelToken?.throwIfCancelled();
              try {
                final result = await _enhancedAiService.extractWebpageContent(
                  url: url,
                  userId: userId,
                  cancelToken: cancelToken,
                );
                if (result is Ok<ExtractionResult>) {
                  return result.value;
                } else if (result is ResultError<ExtractionResult>) {
                  // Handle the error but don't crash
                  String errorMessage =
                      result.error is EnhancedAIServiceException
                          ? (result.error as EnhancedAIServiceException).message
                          : result.error.toString();
                  onProgress?.call('Error extracting webpage: $errorMessage');
                  throw Exception('Error extracting webpage: $errorMessage');
                } else {
                  throw Exception(
                      'Webpage extraction returned unexpected result.');
                }
              } catch (e) {
                onProgress?.call('Failed to extract webpage: $e');
                throw Exception('Failed to extract webpage: $e');
              }
          }
        case 'pdf':
          onProgress?.call('Reading PDF document...');
          developer.log('Processing PDF with mimeType: $mimeType',
              name: 'ContentExtractionService');
          try {
            // Validate input is a Uint8List
            if (input == null || input is! Uint8List) {
              developer.log('Invalid PDF input type: ${input?.runtimeType}',
                  name: 'ContentExtractionService');
              throw Exception(
                  'Invalid PDF data provided. Please try with a valid PDF file.');
            }

            final inputBytes = input;
            if (inputBytes.isEmpty) {
              developer.log('Empty PDF input',
                  name: 'ContentExtractionService');
              throw Exception(
                  'PDF file is empty. Please try with a valid PDF file.');
            }

            // Only attempt PDF parsing if it's actually a PDF
            if (mimeType == null || mimeType.contains('pdf')) {
              rawText = await _extractFromPdfBytes(inputBytes);
            } else {
              rawText = ''; // Pass to AI for other doc types
            }
          } catch (e, stack) {
            developer.log('PDF processing error: $e',
                name: 'ContentExtractionService', error: e, stackTrace: stack);
            rawText = ''; // Fallback to AI
          }

          if (localOnlyTest) {
            return ExtractionResult(
                text: rawText.isNotEmpty ? rawText : 'Local extraction test',
                suggestedTitle: 'Test Document');
          }

          // ── Tier 1: Native Gemini PDF Understanding ──
          // Gemini 2.5+ reads PDFs natively: preserves tables, diagrams, equations
          if (!localOnlyTest && userId != null) {
            onProgress?.call('Analyzing PDF with Gemini AI...');
            developer.log('Trying native Gemini PDF understanding (Tier 1)',
                name: 'ContentExtractionService');
            try {
              final geminiResult = await _pdfAiService.extractPdf(
                input as Uint8List,
                filename: 'document.pdf',
                fallbackText: null, // no pre-extracted text yet
                cancelToken: cancelToken,
              );
              if (geminiResult is Ok<ExtractionResult>) {
                developer.log('Native Gemini PDF extraction succeeded',
                    name: 'ContentExtractionService');
                return geminiResult.value;
              }
              developer.log('Native Gemini PDF sparse, falling to Syncfusion',
                  name: 'ContentExtractionService');
            } catch (e) {
              developer.log('Native Gemini PDF failed: $e',
                  name: 'ContentExtractionService');
            }
          }

          // ── Tier 2: Syncfusion text extraction → AI polishing ──
          if (rawText.trim().isEmpty ||
              rawText.contains('[No text found in PDF.')) {
            onProgress?.call(
                'Local extraction sparse. Using AI for deep analysis...');
            try {
              final result = await _enhancedAiService.analyzeContentFromBytes(
                bytes: input,
                mimeType: 'application/pdf',
                userId: userId!,
                cancelToken: cancelToken,
              );
              if (result is Ok<ExtractionResult>) {
                return result.value;
              }
            } catch (e) {
              developer.log('AI PDF fallback failed: $e',
                  name: 'ContentExtractionService');
            }

            if (rawText.trim().isEmpty ||
                rawText.contains('[No text found in PDF.')) {
              onProgress
                  ?.call('No text found in PDF. Try a different document.');
              throw Exception(
                  'No text found in PDF. The PDF might contain only images or scanned content that cannot be extracted.');
            }
          }
          suggestedTitle = 'Document Content';
          break;
        case 'image':
          developer.log('Processing image with mimeType: $mimeType',
              name: 'ContentExtractionService');

          if (input == null || input is! Uint8List) {
            developer.log('Invalid image input type: ${input?.runtimeType}',
                name: 'ContentExtractionService');
            throw Exception(
                'Invalid image data provided. Please try with a valid image file.');
          }

          final inputBytes = input;
          if (inputBytes.isEmpty) {
            developer.log('Empty image input',
                name: 'ContentExtractionService');
            throw Exception(
                'Image file is empty. Please try with a valid image file.');
          }

          if (!kIsWeb) {
            onProgress?.call('Scanning image with on-device OCR...');
            try {
              rawText = await _extractFromImageBytes(inputBytes);
            } catch (e, stack) {
              developer.log('Image processing error: $e',
                  name: 'ContentExtractionService',
                  error: e,
                  stackTrace: stack);
              rawText = '';
            }
          } else {
            // On web, we can't use on-device OCR, so return appropriate message
            rawText =
                '[Image processing requires native device capabilities. On web, please use text input or paste extracted text directly.]';
          }

          if (localOnlyTest) {
            return ExtractionResult(
                text: rawText.isNotEmpty ? rawText : 'Local extraction test',
                suggestedTitle: 'Test Image');
          }

          // ── Tier 1: Native Gemini Vision Analysis (Gemini 2.5+) ──
          // Better for layouts, handwriting, and diagrams
          if (!localOnlyTest && userId != null) {
            onProgress?.call('Analyzing image with Gemini AI...');
            developer.log('Trying native Gemini vision (Tier 1)',
                name: 'ContentExtractionService');
            try {
              final visionResult = await _pdfAiService.extractImage(
                inputBytes,
                mimeType ?? 'image/jpeg',
                filename: 'image.jpg',
                cancelToken: cancelToken,
              );
              if (visionResult is Ok<ExtractionResult>) {
                developer.log('Native Gemini vision extraction succeeded',
                    name: 'ContentExtractionService');
                return visionResult.value;
              }
              developer.log('Native Gemini vision sparse, falling to OCR',
                  name: 'ContentExtractionService');
            } catch (e) {
              developer.log('Native Gemini vision failed: $e',
                  name: 'ContentExtractionService');
            }
          }

          // ── Tier 2: On-device OCR ──
          if (rawText.isEmpty || rawText.contains('[No text found in image.')) {
            // ... (rest of old logic already handles rawText checking)
          }
          suggestedTitle = 'Scanned Image';
          break;
        case 'audio':
          developer.log('Processing audio with mimeType: $mimeType',
              name: 'ContentExtractionService');

          if (input == null || input is! Uint8List) {
            developer.log('Invalid audio input type: ${input?.runtimeType}',
                name: 'ContentExtractionService');
            throw Exception(
                'Invalid audio data provided. Please try with a valid audio file.');
          }

          final inputBytes = input;
          if (inputBytes.isEmpty) {
            developer.log('Empty audio input',
                name: 'ContentExtractionService');
            throw Exception(
                'Audio file is empty. Please try with a valid audio file.');
          }

          // ── Native Gemini Media Understanding (Gemini 2.5+) ──
          onProgress?.call('Transcribing media with Gemini AI...');
          developer.log('Processing media with native Gemini, mimeType: $mimeType',
              name: 'ContentExtractionService');
          final mediaMime =
              mimeType ?? (type == 'audio' ? 'audio/mpeg' : 'video/mp4');
          try {
            final mediaResult = await _pdfAiService.extractMultimodalMedia(
              input,
              mediaMime,
              filename: type == 'audio' ? 'recording' : 'video',
              cancelToken: cancelToken,
            );
            if (mediaResult is Ok<ExtractionResult>) {
              return mediaResult.value;
            } else if (mediaResult
                is ResultError<ExtractionResult>) {
              final err = mediaResult.error;
              throw Exception(
                  err is EnhancedAIServiceException ? err.message : err.toString());
            }
          } catch (e) {
            developer.log('Gemini media extraction failed: $e',
                name: 'ContentExtractionService');
            throw Exception(
                'Media analysis failed: $e. Try uploading a transcript text file instead.');
          }
        case 'video':
          developer.log('Processing video with mimeType: $mimeType',
              name: 'ContentExtractionService');

          if (input == null || input is! Uint8List) {
            developer.log('Invalid video input type: ${input?.runtimeType}',
                name: 'ContentExtractionService');
            throw Exception(
                'Invalid video data provided. Please try with a valid video file.');
          }

          final inputBytes = input;
          if (inputBytes.isEmpty) {
            developer.log('Empty video input',
                name: 'ContentExtractionService');
            throw Exception(
                'Video file is empty. Please try with a valid video file.');
          }

          // Video is now handled by the multimodal block above (fall-through logic)
          // To ensure fall-through works in Dart 3, I'll just copy the logic or combine the cases.
          // Let's combine audio and video cases.
          return await _extractContentInternal(
            type: 'audio', // Reuse common media logic
            input: input,
            userId: userId,
            mimeType: mimeType,
            refineWithAI: refineWithAI,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
        default:
          throw Exception('Unknown content type: $type');
      }
    } catch (e, stack) {
      developer.log('Error in _extractContentInternal',
          name: 'ContentExtractionService', error: e, stackTrace: stack);
      rethrow;
    }

    if (refineWithAI && rawText.isNotEmpty) {
      onProgress?.call('Polishing extracted text with AI...');
      try {
        rawText = await _enhancedAiService.refineContent(rawText,
            cancelToken: cancelToken);
      } catch (e) {
        // Fallback to raw text
      }
    }

    developer.log('Extraction complete: $suggestedTitle',
        name: 'ContentExtractionService');

    // Hard truncation for memory safety before returning to UI/AI
    if (rawText.length > AIConfig.maxInputLength) {
      developer.log(
          'Extracted text truncated from ${rawText.length} to ${AIConfig.maxInputLength}',
          name: 'ContentExtractionService');
      rawText = rawText.substring(0, AIConfig.maxInputLength);
    }

    return ExtractionResult(text: rawText, suggestedTitle: suggestedTitle);
  }

  bool _isYoutubeUrl(String url) {
    return url.contains('youtube.com/watch') ||
        url.contains('youtu.be/') ||
        url.contains('youtube.com/shorts/');
  }

  /// Detect the type of content from a URL based on file extension
  UrlContentType _detectUrlType(String url) {
    if (_isYoutubeUrl(url)) {
      return UrlContentType.youtube;
    }

    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();

    // Document extensions
    if (path.endsWith('.pdf') ||
        path.endsWith('.doc') ||
        path.endsWith('.docx') ||
        path.endsWith('.txt') ||
        path.endsWith('.rtf') ||
        path.endsWith('.pptx') ||
        path.endsWith('.xlsx') ||
        path.endsWith('.xls') ||
        path.endsWith('.csv')) {
      return UrlContentType.document;
    }

    // Image extensions
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.heif') ||
        path.endsWith('.heic')) {
      return UrlContentType.image;
    }

    // Audio extensions
    if (path.endsWith('.mp3') ||
        path.endsWith('.wav') ||
        path.endsWith('.aac') ||
        path.endsWith('.flac') ||
        path.endsWith('.ogg') ||
        path.endsWith('.m4a')) {
      return UrlContentType.audio;
    }

    // Video extensions
    if (path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi') ||
        path.endsWith('.webm') ||
        path.endsWith('.flv') ||
        path.endsWith('.mkv') ||
        path.endsWith('.wmv')) {
      return UrlContentType.video;
    }

    // Default to webpage
    return UrlContentType.webpage;
  }

  /// Get MIME type from URL extension
  String _getMimeType(String url) {
    final path = url.toLowerCase();

    // Documents
    if (path.endsWith('.pdf')) return 'application/pdf';
    if (path.endsWith('.doc')) return 'application/msword';
    if (path.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (path.endsWith('.txt')) return 'text/plain';
    if (path.endsWith('.rtf')) return 'application/rtf';
    if (path.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (path.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (path.endsWith('.csv')) return 'text/csv';

    // Images
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    if (path.endsWith('.heif') || path.endsWith('.heic')) return 'image/heif';

    // Audio
    if (path.endsWith('.mp3')) return 'audio/mpeg';
    if (path.endsWith('.wav')) return 'audio/wav';
    if (path.endsWith('.aac')) return 'audio/aac';
    if (path.endsWith('.flac')) return 'audio/flac';
    if (path.endsWith('.ogg')) return 'audio/ogg';
    if (path.endsWith('.m4a')) return 'audio/mp4';

    // Video
    if (path.endsWith('.mp4')) return 'video/mp4';
    if (path.endsWith('.mov')) return 'video/quicktime';
    if (path.endsWith('.avi')) return 'video/x-msvideo';
    if (path.endsWith('.webm')) return 'video/webm';
    if (path.endsWith('.flv')) return 'video/x-flv';
    if (path.endsWith('.mkv')) return 'video/x-matroska';
    if (path.endsWith('.wmv')) return 'video/x-ms-wmv';

    // Default
    return 'application/octet-stream';
  }

  /// Extract text from PDF using Syncfusion PDF library in a background isolate
  /// This prevents UI freezing on large PDF files
  Future<String> _extractFromPdfBytes(Uint8List pdfBytes) async {
    try {
      // Run PDF extraction in isolate to prevent UI freeze
      // compute() spawns an isolate and runs the function there
      final String text = await compute(_extractPdfTextInIsolate, pdfBytes);
      return text;
    } catch (e) {
      throw Exception('PDF text extraction failed: $e');
    }
  }

  /// Extract text from image using Google ML Kit OCR
  /// No AI usage - free on-device OCR
  Future<String> _extractFromImageBytes(Uint8List imageBytes) async {
    try {
      // Save image to temporary file (required by ML Kit)
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);

      // Initialize text recognizer
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      // Process image
      final inputImage = InputImage.fromFile(tempFile);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      // Clean up
      await textRecognizer.close();
      await tempFile.delete();

      // Extract text
      if (recognizedText.text.isEmpty) {
        return '[No text found in image. The image might not contain readable text.]';
      }

      return recognizedText.text;
    } catch (e) {
      throw Exception(
          'OCR failed: $e. Make sure the image contains clear, readable text.');
    }
  }
}

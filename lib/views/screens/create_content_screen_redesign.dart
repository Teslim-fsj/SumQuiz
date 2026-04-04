import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sumquiz/views/widgets/generation_loading_overlay.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/services/extraction_result_cache.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:sumquiz/views/widgets/extraction_progress_dialog.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/theme/web_theme.dart'; // Reuse premium colors

class InputValidator {
  static bool isValidUrl(String url) {
    if (url.trim().isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  static bool isYoutubeUrl(String url) {
    return url.contains('youtube.com/watch') ||
        url.contains('youtu.be/') ||
        url.contains('youtube.com/shorts/');
  }

  static String? validateText(String text) {
    if (text.trim().isEmpty) {
      return 'Please enter some text';
    }
    if (text.trim().length < 50) {
      return 'Text is too short. Please provide at least 50 characters';
    }
    if (text.length > 50000) {
      return 'Text is too long. Maximum 50,000 characters';
    }
    return null; // Valid
  }

  static String? validateUrl(String url) {
    if (url.trim().isEmpty) {
      return 'Please enter a URL';
    }
    if (!isValidUrl(url)) {
      return 'Please enter a valid URL (must start with http:// or https://)';
    }
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      if (!isYoutubeUrl(url)) {
        return 'Invalid YouTube URL. Please provide a valid video, short, or live stream link.';
      }
    }
    return null; // Valid
  }
}

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _linkController = TextEditingController();
  final _topicController = TextEditingController();
  String? _pdfName;
  Uint8List? _pdfBytes;
  String? _imageName;
  Uint8List? _imageBytes;
  String? _mimeType;
  String _errorMessage = '';

  // Topic-based learning state
  String _topicDepth = 'intermediate';
  final double _topicCardCount = 15;

  final ImagePicker _imagePicker = ImagePicker();
  String _selectedImportMethod = '';

  // Loading and state management
  bool _isLoading = false;
  bool _isProcessing = false;
  String _currentOperation = '';

  // Cancellation token for extraction operations
  CancellationToken? _cancelToken;

  // New design state
  // New design state: More options expanded
  bool _showMoreOptions = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _textController.dispose();
    _linkController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  void _resetInputs() {
    _textController.clear();
    _linkController.clear();
    _topicController.clear();
    setState(() {
      _pdfName = null;
      _pdfBytes = null;
      _imageName = null;
      _imageBytes = null;
      _mimeType = null;
      _errorMessage = '';
    });
  }



  Future<bool> _checkProAccess(String feature, {String actionType = 'text'}) async {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) return true;

    if (user.isPro) return true;

    final usageService = UsageService();
    final action = actionType == 'upload' ? 'upload' : 'generate';
    final canProceed = await usageService.canPerformAction(user.uid, action);

    if (!canProceed) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => UpgradeDialog(
            featureName: action == 'upload' ? 'Lifetime Upload Limit' : feature,
          ),
        );
      }
      return false;
    }

    // Special case for Tutor Exam which is always Pro
    if (feature == 'Tutor Exam' && !user.isPro) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => UpgradeDialog(featureName: feature),
        );
      }
      return false;
    }

    return true;
  }

  /// Check if API key is properly configured before processing
  bool _isApiKeyConfigured() {
    try {
      Provider.of<EnhancedAIService>(context, listen: false);
      // If we can access the service without error, the API key is configured
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _pickPdf() async {
    if (_isLoading || _isProcessing) return;

    if (!await _checkProAccess('PDF Upload', actionType: 'upload')) return;
    _resetInputs(); // Clear other inputs

    setState(() => _isLoading = true);

    try {
      // Determine allowed extensions based on selected method
      List<String> allowedTypes;
      String fileTypeDescription;
      int maxSizeMb;

      if (_selectedImportMethod == 'pdf' || _selectedImportMethod == 'slides') {
        allowedTypes = [
          'pdf',
          'ppt',
          'pptx',
          'odp',
          'doc',
          'docx',
          'txt',
          'jpg',
          'jpeg',
          'png'
        ];
        fileTypeDescription = 'document';
        maxSizeMb = 15;
      } else if (_selectedImportMethod == 'audio') {
        allowedTypes = ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'];
        fileTypeDescription = 'audio';
        maxSizeMb = 50; // Audio files might be larger
      } else {
        allowedTypes = ['pdf'];
        fileTypeDescription = 'PDF';
        maxSizeMb = 15;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedTypes,
        withData: true,
      );

      if (result != null) {
        if (result.files.isEmpty) {
          throw Exception('No file selected');
        }

        final file = result.files.single;

        if (file.bytes == null) {
          throw Exception('Failed to read file data');
        }

        // Validate file size
        final fileSizeMb = file.bytes!.length / (1024 * 1024);
        if (fileSizeMb > maxSizeMb) {
          throw Exception(
              '${fileTypeDescription.toUpperCase()} file is too large. Maximum size is ${maxSizeMb}MB. Selected file is ${fileSizeMb.toStringAsFixed(1)}MB');
        }

        // Validate file extension
        final fileExtension = file.extension?.toLowerCase();
        if (fileExtension == null || !allowedTypes.contains(fileExtension)) {
          throw Exception(
              'Invalid file type. Supported formats: ${allowedTypes.join(', ').toUpperCase()}');
        }

        setState(() {
          _pdfName = file.name;
          _pdfBytes = file.bytes;
          _mimeType = _getMimeType(file.name);
        });
      }
    } catch (e) {
      setState(() => _errorMessage = _getUserFriendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isLoading || _isProcessing) return;

    if (!await _checkProAccess('Image Scan', actionType: 'upload')) return;
    _resetInputs(); // Clear other inputs

    setState(() => _isLoading = true);

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxHeight: 1920,
        maxWidth: 1920,
      );

      if (image != null) {
        // Validate file size (10MB limit)
        final fileStat = await image.length();
        final fileSizeMb = fileStat / (1024 * 1024);
        if (fileSizeMb > 10) {
          throw Exception(
              'Image file is too large. Maximum size is 10MB. Selected image is ${fileSizeMb.toStringAsFixed(1)}MB');
        }

        final bytes = await image.readAsBytes();

        // Validate that we got data
        if (bytes.isEmpty) {
          throw Exception('Failed to read image data');
        }

        setState(() {
          _imageName =
              '${source == ImageSource.camera ? "camera_" : "gallery_"}${image.name}';
          _imageBytes = bytes;
          _mimeType = _getMimeType(image.name);
        });
      }
    } catch (e) {
      setState(() => _errorMessage = _getUserFriendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processAndNavigate() async {
    // Check if API key is configured
    if (!_isApiKeyConfigured()) {
      setState(() {
        _errorMessage =
            '🔑 API key is not configured. Please set up your API key in the .env file.';
      });
      return;
    }

    // Prevent multiple concurrent operations
    if (_isProcessing || _isLoading) return;

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      setState(
          () => _errorMessage = 'You must be logged in to create content.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = '';
      _currentOperation = 'Initializing...';
    });

    try {
      // Check if topic generation is selected
      if (_topicController.text.trim().isNotEmpty) {
        await _processTopicGeneration(user);
        return;
      }

      // Otherwise, process import method
      String? validationError;
      String type;
      dynamic input;

      switch (_selectedImportMethod) {
        case 'text':
          validationError = InputValidator.validateText(_textController.text);
          type = 'text';
          input = _textController.text;
          break;
        case 'link':
          if (!await _checkProAccess('Analyze Link')) {
            return;
          }
          validationError = InputValidator.validateUrl(_linkController.text);
          type = 'link';
          input = _linkController.text;
          break;
        case 'pdf':
        case 'slides':
          if (!await _checkProAccess('Document Analysis', actionType: 'upload')) {
            return;
          }
          if (_pdfBytes == null) {
            validationError = 'Please upload a document';
          } else if (_pdfBytes!.length > 15 * 1024 * 1024) {
            validationError =
                'Document file is too large. Maximum size is 15MB';
          }
          type = 'pdf';
          input = _pdfBytes;
          break;
        case 'audio':
          if (!await _checkProAccess('Audio Analysis')) {
            return;
          }
          if (_pdfBytes == null) {
            validationError = 'Please upload an audio file';
          } else if (_pdfBytes!.length > 50 * 1024 * 1024) {
            validationError = 'Audio file is too large. Maximum size is 50MB';
          }
          type = 'audio'; // Changed from 'image'
          input = _pdfBytes;
          break;
        case 'image':
          if (!await _checkProAccess('Image/Snap Scan')) {
            return;
          }
          if (_imageBytes == null) {
            validationError = 'Please capture or select an image';
          } else if (_imageBytes!.length > 10 * 1024 * 1024) {
            validationError = 'Image file is too large. Maximum size is 10MB';
          }
          type = 'image';
          input = _imageBytes;
          break;
        case 'exam':
          if (!await _checkProAccess('Tutor Exam')) {
            return;
          }
          if (mounted) {
            context.push('/exam-creation');
          }
          return;

        default:
          validationError = 'Please select an import method';
          type = '';
          input = null;
      }

      if (validationError != null) {
        setState(() => _errorMessage = validationError!);
        return;
      }

      await _processContentExtraction(type, input, user, mimeType: _mimeType);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _currentOperation = '';
        });
      }
    }
  }

  Future<void> _processContentExtraction(
      String type, dynamic input, UserModel user,
      {String? mimeType}) async {
    debugPrint(
        'CreateContentScreen._processContentExtraction called with type: $type');

    // Create a new cancellation token for this extraction operation
    _cancelToken = CancellationToken();
    final cancelToken = _cancelToken!;

    final extractionService =
        Provider.of<ContentExtractionService>(context, listen: false);

    // Track progress for the dialog
    final progressNotifier =
        ValueNotifier<String>('Preparing to extract content...');

    // Capture the navigator before showing dialog to avoid context issues
    final navigator = Navigator.of(context);

    // Show loading dialog
    if (mounted) {
      debugPrint('Showing extraction progress dialog');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          debugPrint('Dialog builder called in create content screen');
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) {
                return;
              }
              cancelToken.cancel();
            },
            child: ExtractionProgressDialog(messageNotifier: progressNotifier),
          );
        },
      );
    }

    try {
      debugPrint(
          'Calling extractionService.extractContent from create content screen');
      final ExtractionResult extractionResult =
          await extractionService.extractContent(
        type: type,
        input: input,
        userId: user.uid,
        mimeType: mimeType,
        cancelToken: cancelToken,
        onProgress: (message) {
          if (!cancelToken.isCancelled && mounted) {
            progressNotifier.value = message;
          }
        },
      );

      debugPrint(
          'Extraction completed with ${extractionResult.text.length} chars');

      if (!cancelToken.isCancelled && mounted) {
        try {
          if (navigator.canPop()) {
            navigator.pop();
          }
        } catch (e) {
          debugPrint('Error dismissing dialog: $e');
        }

        _resetInputs();

        if (type == 'pdf' || type == 'image' || type == 'audio') {
          await UsageService().recordAction(user.uid, 'upload');
        }

        if (extractionResult.text.trim().isNotEmpty &&
            !extractionResult.text.startsWith('[')) {
          // Wait for dialog dismissal to fully settle
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            ExtractionResultCache.set(extractionResult);
            await Future.delayed(const Duration(milliseconds: 100));
            if (mounted) {
              if (mounted) {
                await FirebaseCrashlytics.instance.log(
                    'Navigating to extraction-view. Type: $type. Text length: ${extractionResult.text.length}');
                if (mounted) {
                  context.push('/create/extraction-view');
                }
              }
            }
          }
        } else {
          if (mounted) {
            setState(() => _errorMessage =
                'No content was extracted. Please try with different content.');
          }
        }
      }
    } on CancelledException {
      debugPrint('Extraction cancelled in create content screen');
      // User cancelled — dismiss dialog quietly
      if (mounted) {
        try {
          navigator.pop();
        } catch (_) {}
      }
    } on Exception catch (e, stackTrace) {
      debugPrint('Error in _processContentExtraction: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!cancelToken.isCancelled && mounted) {
        // Safely close dialog
        try {
          if (navigator.canPop()) {
            navigator.pop();
            debugPrint('Dialog dismissed in error catch');
          }
        } catch (e) {
          debugPrint('Error dismissing dialog in error catch: $e');
          // Dialog already closed or context invalid, ignore
        }

        // Check if the state is still mounted before setting state
        if (mounted) {
          setState(() {
            _errorMessage = _getUserFriendlyError(e);
          });
        }
      }
    }
  }

  Future<void> _processTopicGeneration(UserModel user) async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      setState(() => _errorMessage = 'Please enter a topic to learn about.');
      return;
    }

    setState(() {
      _isLoading = true;
      _currentOperation = 'Discovery Phase...';
    });

    _cancelToken = CancellationToken();
    final cancelToken = _cancelToken!;

    try {
      final aiService = Provider.of<EnhancedAIService>(context, listen: false);
      final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
      final usageService = UsageService();

      await usageService.recordAction(user.uid, 'generate');

      final folderId = await aiService.generateFromTopic(
        topic: topic,
        userId: user.uid,
        localDb: localDb,
        depth: _topicDepth,
        cardCount: _topicCardCount.toInt(),
      );

      if (!cancelToken.isCancelled && mounted) {
        _resetInputs();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.push('/library/results-view/$folderId');
          }
        });
      }
    } catch (e) {
      if (!cancelToken.isCancelled && mounted) {
        setState(() {
          _errorMessage = _getUserFriendlyError(e);
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        _buildHeroSection(),
                        const SizedBox(height: 40),
                        _buildMaterialSection(),
                        const SizedBox(height: 16),
                        _buildQuickActionsRow(),
                        const SizedBox(height: 48),
                        _buildSeparator(),
                        const SizedBox(height: 48),
                        _buildTopicSection(),
                        const SizedBox(height: 40),
                        _buildMoreOptions(),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms),
                ),
              ],
            ),
          ),
          _buildErrorDisplay(),
          if (_isLoading || _isProcessing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: 50, duration: 5.seconds),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEC4899).withValues(alpha: 0.05),
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveX(begin: 0, end: 40, duration: 8.seconds),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const Spacer(),
          _buildProBadge(),
        ],
      ),
    );
  }

  Widget _buildProBadge() {
    final user = Provider.of<UserModel?>(context);
    if (user?.isPro == true) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: WebColors.PremiumGradient,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFACC15).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            'GO PRO',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 3.seconds, delay: 1.seconds);
  }

  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What do you want',
          style: GoogleFonts.outfit(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1.2,
            height: 1.1,
          ),
        ),
        Text(
          'to study?',
          style: GoogleFonts.outfit(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..shader = WebColors.HeroGradient.createShader(
                  const Rect.fromLTWH(0, 0, 300, 70)),
            letterSpacing: -1.2,
            height: 1.1,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildMaterialSection() {
    final bool hasFile = _pdfBytes != null || _imageBytes != null;
    final String? fileName = _pdfName ?? _imageName;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          if (hasFile)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded,
                      color: Color(0xFF6366F1), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fileName!,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _resetInputs,
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _linkController,
                    onChanged: (v) => setState(() {}),
                    style:
                        GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Paste link or material...',
                      hintStyle: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                _buildUploadIconButton(Icons.picture_as_pdf_rounded, 'pdf',
                    const Color(0xFF6366F1)),
                _buildUploadIconButton(
                    Icons.camera_alt_rounded, 'image', const Color(0xFFEC4899)),
                _buildUploadIconButton(
                    Icons.mic_none_rounded, 'audio', const Color(0xFF10B981)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadIconButton(IconData icon, String type, Color color) {
    return IconButton(
      onPressed: () {
        setState(() => _selectedImportMethod = type);
        if (type == 'image') {
          _showImagePickerOptions();
        } else {
          _pickPdf();
        }
      },
      icon: Icon(icon, color: color.withValues(alpha: 0.8), size: 22),
      tooltip: 'Upload ${type.toUpperCase()}',
    );
  }

  Widget _buildQuickActionsRow() {
    final bool hasInput = _linkController.text.trim().isNotEmpty ||
        _pdfBytes != null ||
        _imageBytes != null;

    return Row(
      children: [
        _buildActionBtn('Summary', Icons.text_snippet_rounded, hasInput,
            WebColors.HeroGradient),
        const SizedBox(width: 12),
        _buildActionBtn(
            'Quiz', Icons.quiz_rounded, hasInput, WebColors.PremiumGradient),
        const SizedBox(width: 12),
        _buildActionBtn('Flashcards', Icons.style_rounded, hasInput,
            WebColors.HeroGradient),
      ],
    );
  }

  Widget _buildActionBtn(
      String label, IconData icon, bool enabled, Gradient gradient) {
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: GestureDetector(
          onTap: enabled ? _processAndNavigate : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: enabled ? gradient : null,
              color: enabled ? null : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Or',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.3),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
      ],
    );
  }

  Widget _buildTopicSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.3), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _topicController,
              onSubmitted: (_) {
                if (_topicController.text.trim().isNotEmpty) {
                  _processAndNavigate();
                }
              },
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Type a topic...',
                hintStyle: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_topicController.text.isNotEmpty)
            IconButton(
              onPressed: () => setState(() => _topicController.clear()),
              icon: const Icon(Icons.close_rounded, color: Colors.white54),
            ),
        ],
      ),
    );
  }

  Widget _buildMoreOptions() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showMoreOptions = !_showMoreOptions),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showMoreOptions ? Icons.remove_rounded : Icons.add_rounded,
                  color: const Color(0xFF6366F1),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'More options',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF6366F1),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showMoreOptions)
          Column(
            children: [
              const SizedBox(height: 24),
              _buildDepthSelector(),
              const SizedBox(height: 24),
              _buildLaboratoryOption(),
            ],
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }

  Widget _buildDepthSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONCEPTUAL DEPTH',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildDepthChip('Beginner', 'beginner'),
            const SizedBox(width: 12),
            _buildDepthChip('Intermediate', 'intermediate'),
            const SizedBox(width: 12),
            _buildDepthChip('Advanced', 'advanced'),
          ],
        ),
      ],
    );
  }

  Widget _buildLaboratoryOption() {
    return GestureDetector(
      onTap: () async {
        if (!await _checkProAccess('Tutoring Lab', actionType: 'upload')) return;
        if (mounted) context.push('/exam-creation');
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.biotech_rounded,
                  color: Color(0xFF10B981), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Laboratory',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Strategic Tutoring & Exam Solver',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDepthChip(String label, String depth) {
    final isSelected = _topicDepth == depth;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _topicDepth = depth);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
                color: Colors.white.withValues(alpha: isSelected ? 1 : 0.1)),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? Colors.black
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorDisplay() {
    if (_errorMessage.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.3), blurRadius: 20),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _errorMessage = ''),
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    ).animate().shake().fadeOut(delay: 5.seconds);
  }

  Widget _buildLoadingOverlay() {
    return GenerationLoadingOverlay(
      message: 'Transmuting Concepts...',
      subMessage: _currentOperation.isEmpty
          ? 'Harnessing neural networks'
          : _currentOperation,
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Visual Laboratory',
                style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  _buildPickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () {
                      context.pop();
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () {
                      context.pop();
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF6366F1), size: 32),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  String _getUserFriendlyError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('rate limit')) {
      return '🚦 Neural circuits overloaded. Please wait.';
    }
    if (errorStr.contains('api') || errorStr.contains('quota')) {
      return '🔑 Intelligence access restricted temporarily.';
    }
    if (errorStr.contains('too long')) {
      return '📏 Concept too vast for single transmutation.';
    }
    if (errorStr.contains('youtube')) {
      return '🎥 Visual stream unavailable or restricted.';
    }
    if (errorStr.contains('pdf')) return '📄 Document structure unreadable.';
    if (errorStr.contains('image')) return '🖼️ Visual pattern unrecognized.';
    return '❌ Conceptual breach detected. Please retry.';
  }
}

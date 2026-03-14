import 'dart:ui';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
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
import 'package:sumquiz/views/screens/exam_creation_screen.dart';
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
  double _topicCardCount = 15;

  final ImagePicker _imagePicker = ImagePicker();
  String _selectedImportMethod = '';

  // Loading and state management
  bool _isLoading = false;
  bool _isProcessing = false;
  String _currentOperation = '';

  // Cancellation token for extraction operations
  CancellationToken? _cancelToken;

  // New design state
  String _activeCategory = 'The Processor'; // Start with a default category
  final ScrollController _scrollController = ScrollController();

  // Pillars definition
  final List<Map<String, dynamic>> _pillars = [
    {
      'name': 'The Processor',
      'icon': Icons.bolt_rounded,
      'color': const Color(0xFF6366F1),
      'subtitle': 'Text & Insights',
      'methods': [
        {
          'id': 'text',
          'label': 'Paste Text',
          'icon': Icons.text_fields_rounded
        },
        {'id': 'link', 'label': 'Web URL', 'icon': Icons.link_rounded},
      ]
    },
    {
      'name': 'The Researcher',
      'icon': Icons.auto_stories_rounded,
      'color': const Color(0xFF8B5CF6),
      'subtitle': 'Knowledge Assets',
      'methods': [
        {
          'id': 'pdf',
          'label': 'PDF File',
          'icon': Icons.picture_as_pdf_rounded
        },
        {
          'id': 'slides',
          'label': 'Slide Deck',
          'icon': Icons.slideshow_rounded
        },
      ]
    },
    {
      'name': 'The Composer',
      'icon': Icons.psychology_rounded,
      'color': const Color(0xFFEC4899),
      'subtitle': 'Media Brain',
      'methods': [
        {
          'id': 'image',
          'label': 'Visual Scan',
          'icon': Icons.camera_alt_rounded
        },
        {'id': 'audio', 'label': 'Voice/Audio', 'icon': Icons.mic_none_rounded},
      ]
    },
    {
      'name': 'The Laboratory',
      'icon': Icons.biotech_rounded,
      'color': const Color(0xFF10B981),
      'subtitle': 'Strategic Tutoring',
      'methods': [
        {
          'id': 'topic',
          'label': 'Topic Discovery',
          'icon': Icons.lightbulb_outline
        },
        {
          'id': 'exam',
          'label': 'Exam Solver',
          'icon': Icons.history_edu_rounded
        },
      ]
    },
  ];

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

  // These methods will set the active input type and clear others
  void _activateTextField() {
    if (_linkController.text.isNotEmpty ||
        _pdfBytes != null ||
        _imageBytes != null) {
      _resetInputs();
    }
  }

  void _activateLinkField() {
    if (_textController.text.isNotEmpty ||
        _pdfBytes != null ||
        _imageBytes != null) {
      _resetInputs();
    }
  }

  bool _checkProAccess(String feature, {String actionType = 'text'}) {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) return true; // Fail safe

    if (user.isPro) return true;

    bool canProceed = true;

    if (actionType == 'upload' || feature == 'Tutor Exam') {
      canProceed = false; // Strictly Pro for uploads and Tutor Exams
    } else {
      // Daily generation limits are handled in AI services or during processing
      // but we can block here if we know they are over.
      canProceed = user.dailyDecksGenerated < UsageConfig.freeDecksPerDay;
    }

    if (!canProceed) {
      // Ensure the dialog is shown only if the context is still valid
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => UpgradeDialog(
              featureName: feature,
              // We can't easily pass custom messages to UpgradeDialog unless we modify it,
              // but just showing it is better than blocking everything.
            ),
          );
        }
      });
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

    if (!_checkProAccess('PDF Upload', actionType: 'upload')) return;
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

    if (!_checkProAccess('Image Scan', actionType: 'upload')) return;
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
          if (!user.isPro) {
            _checkProAccess('Analyze Link');
            return;
          }
          validationError = InputValidator.validateUrl(_linkController.text);
          type = 'link';
          input = _linkController.text;
          break;
        case 'pdf':
        case 'slides':
          if (!user.isPro) {
            _checkProAccess('Document Analysis', actionType: 'upload');
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
          if (!user.isPro) {
            _checkProAccess('Audio Analysis');
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
          if (!user.isPro) {
            _checkProAccess('Image/Snap Scan');
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
          if (!user.isPro) {
            _checkProAccess('Tutor Exam');
            return;
          }
          context.push('/exam-creation');
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
              await FirebaseCrashlytics.instance.log(
                  'Navigating to extraction-view. Type: $type. Text length: ${extractionResult.text.length}');
              context.push('/create/extraction-view');
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

      await usageService.recordDeckGeneration(user.uid);

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
                        const SizedBox(height: 20),
                        _buildHeroSection(),
                        const SizedBox(height: 40),
                        _buildPillarSection(),
                        const SizedBox(height: 120), // Space for bottom button
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildErrorDisplay(),
          if (_isLoading || _isProcessing) _buildLoadingOverlay(),
          _buildBottomAction(),
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
          'Forge New',
          style: GoogleFonts.outfit(
            fontSize: 46,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1.5,
            height: 1.1,
          ),
        ),
        Text(
          'Knowledge',
          style: GoogleFonts.outfit(
            fontSize: 46,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..shader = WebColors.HeroGradient.createShader(
                  const Rect.fromLTWH(0, 0, 300, 70)),
            letterSpacing: -1.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Transform any source into interactive study material with AI.',
          style: GoogleFonts.outfit(
            fontSize: 17,
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 800.ms)
        .slideX(begin: -0.1, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildPillarSection() {
    return Column(
      children: _pillars.map((pillar) => _buildPillarCard(pillar)).toList(),
    );
  }

  Widget _buildPillarCard(Map<String, dynamic> pillar) {
    final bool isSelected = _activeCategory == pillar['name'];
    final Color color = pillar['color'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(
                  () => _activeCategory = isSelected ? '' : pillar['name']);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isSelected
                          ? color.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(pillar['icon'], color: color, size: 30),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pillar['name'],
                              style: GoogleFonts.outfit(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              pillar['subtitle'],
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: isSelected ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isSelected
                              ? color
                              : Colors.white.withValues(alpha: 0.3),
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ).animate(target: isSelected ? 1 : 0).scale(
                    begin: const Offset(1, 1), end: const Offset(1.02, 1.02)),
              ),
            ),
          ),
          if (isSelected)
            _buildPillarMethods(pillar['methods'], color)
                .animate()
                .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                .slideY(begin: -0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildPillarMethods(List<dynamic> methods, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 4, right: 4),
      child: Row(
        children: methods.map<Widget>((method) {
          final bool isMethodSelected = _selectedImportMethod == method['id'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final String methodId = method['id'];
                  if (methodId == 'exam') {
                    if (!_checkProAccess('Tutoring Lab', actionType: 'upload'))
                      return;
                    _resetInputs();
                    context.push('/exam-creation');
                    return;
                  }
                  if (methodId != 'text' && methodId != 'topic') {
                    if (!_checkProAccess(method['label'], actionType: 'upload'))
                      return;
                  }
                  setState(() => _selectedImportMethod = methodId);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: isMethodSelected
                        ? color
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isMethodSelected
                          ? color
                          : Colors.white.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                    boxShadow: isMethodSelected
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 6))
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(method['icon'],
                          color: isMethodSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.7),
                          size: 24),
                      const SizedBox(height: 10),
                      Text(
                        method['label'],
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: isMethodSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isMethodSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomAction() {
    if (_selectedImportMethod.isEmpty && _topicController.text.isEmpty)
      return const SizedBox.shrink();

    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 32,
      left: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInputSheet(),
          const SizedBox(height: 16),
          _buildGenerateButton(),
        ],
      ),
    );
  }

  Widget _buildInputSheet() {
    if (_selectedImportMethod.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Provide Content',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _selectedImportMethod = ''),
                    icon: Icon(Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSelectedInputWidget(),
            ],
          ),
        ),
      ),
    )
        .animate()
        .slideY(begin: 1, end: 0, curve: Curves.easeOutQuart, duration: 600.ms);
  }

  Widget _buildSelectedInputWidget() {
    switch (_selectedImportMethod) {
      case 'text':
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _textController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText:
                  'Paste your lecture notes, documents, or insights here...',
              hintStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 15),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        );
      case 'link':
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _linkController,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'https://youtube.com/watch?v=...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
              border: InputBorder.none,
              prefixIcon:
                  const Icon(Icons.link_rounded, color: Color(0xFF6366F1)),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        );
      case 'topic':
        return Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _topicController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20),
                decoration: InputDecoration(
                  hintText: 'Search any topic...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildDepthChip('Beginner', 'beginner'),
                const SizedBox(width: 8),
                _buildDepthChip('Intermediate', 'intermediate'),
                const SizedBox(width: 8),
                _buildDepthChip('Advanced', 'advanced'),
              ],
            ),
          ],
        );
      case 'pdf':
      case 'slides':
      case 'image':
      case 'audio':
        return _buildFileSelector();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFileSelector() {
    final String label = _selectedImportMethod.toUpperCase();
    final bool hasFile = _pdfBytes != null || _imageBytes != null;
    final String? fileName = _pdfName ?? _imageName;

    return GestureDetector(
      onTap: () => _selectedImportMethod == 'image'
          ? _showImagePickerOptions()
          : _pickPdf(),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasFile
              ? const Color(0xFF10B981).withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
                hasFile
                    ? Icons.check_circle_rounded
                    : Icons.cloud_upload_rounded,
                color: hasFile ? const Color(0xFF10B981) : Colors.white70,
                size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? fileName! : 'Select $label Asset',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!hasFile)
                    Text(
                      'Maximum size: 15MB',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                    ),
                ],
              ),
            ),
            const Icon(Icons.add_rounded, color: Colors.white30),
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
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.06),
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
                color:
                    isSelected ? Colors.black : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    final bool isReady = _topicController.text.isNotEmpty ||
        (_selectedImportMethod == 'text' &&
            _textController.text.length >= 50) ||
        (_selectedImportMethod == 'link' && _linkController.text.isNotEmpty) ||
        (_selectedImportMethod != 'text' &&
            _selectedImportMethod != 'link' &&
            (_pdfBytes != null || _imageBytes != null));

    return GestureDetector(
      onTap: isReady ? _processAndNavigate : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 68,
        decoration: BoxDecoration(
          gradient: isReady ? WebColors.HeroGradient : null,
          color: isReady ? null : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(22),
          boxShadow: isReady
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: isReady ? Colors.white : Colors.white.withValues(alpha: 0.2),
                  size: 22),
              const SizedBox(width: 14),
              Text(
                'ACTIVATE AI',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isReady ? Colors.white : Colors.white.withValues(alpha: 0.2),
                  letterSpacing: 2,
                ),
              ),
            ],
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
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20),
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
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    backgroundColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Transmuting Concepts...',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(duration: 2.seconds),
                const SizedBox(height: 12),
                Text(
                  _currentOperation.isEmpty
                      ? 'Harnessing neural networks'
                      : _currentOperation,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    if (errorStr.contains('rate limit'))
      return '🚦 Neural circuits overloaded. Please wait.';
    if (errorStr.contains('api') || errorStr.contains('quota'))
      return '🔑 Intelligence access restricted temporarily.';
    if (errorStr.contains('too long'))
      return '📏 Concept too vast for single transmutation.';
    if (errorStr.contains('youtube'))
      return '🎥 Visual stream unavailable or restricted.';
    if (errorStr.contains('pdf')) return '📄 Document structure unreadable.';
    if (errorStr.contains('image')) return '🖼️ Visual pattern unrecognized.';
    return '❌ Conceptual breach detected. Please retry.';
  }
}

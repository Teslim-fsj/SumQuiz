import 'dart:typed_data';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/services/extraction_result_cache.dart';
import 'dart:math' as dart_math;

class CreateContentScreenWeb extends StatefulWidget {
  const CreateContentScreenWeb({super.key});

  @override
  State<CreateContentScreenWeb> createState() => _CreateContentScreenWebState();
}

class _CreateContentScreenWebState extends State<CreateContentScreenWeb>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _textController = TextEditingController();
  final _linkController = TextEditingController();
  final _topicController = TextEditingController();
  String? _fileName;
  Uint8List? _fileBytes;
  bool _isLoading = false;
  String _errorMessage = '';
  String _extractionProgress = 'Preparing to extract content...';
  String _selectedInputType = 'topic'; // Default to topic now

  // Topic-based learning state
  String _topicDepth = 'intermediate';
  double _topicCardCount = 15;
  final ScrollController _scrollController = ScrollController();

  // Cancellation token for extraction operations
  CancellationToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    _textController.dispose();
    _linkController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  String _getMimeTypeFromName(String fileName) {
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

  void _resetInputs() {
    _textController.clear();
    _linkController.clear();
    _topicController.clear();
    setState(() {
      _fileName = null;
      _fileBytes = null;
      _errorMessage = '';
    });
  }

  bool _checkProAccess(String feature) {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user != null && !user.isPro) {
      showDialog(
        context: context,
        builder: (_) => UpgradeDialog(featureName: feature),
      );
      return false;
    }
    return true;
  }

  Future<void> _pickFile(String type) async {
    String featureName = '';
    if (type == 'pdf') {
      featureName = 'PDF Upload';
    } else if (type == 'image') {
      featureName = 'Image Scan';
    } else if (type == 'audio') {
      featureName = 'Audio/Speech Analysis';
    } else if (type == 'slides') {
      featureName = 'Slides Analysis';
    }

    if (!_checkProAccess(featureName)) return;

    try {
      List<String>? allowedExtensions;
      FileType fileType = FileType.custom;

      if (type == 'pdf') {
        allowedExtensions = ['pdf', 'doc', 'docx', 'txt'];
      } else if (type == 'image') {
        fileType = FileType.image;
      } else if (type == 'audio') {
        allowedExtensions = ['mp3', 'wav', 'm4a', 'aac'];
      } else if (type == 'slides') {
        allowedExtensions = ['ppt', 'pptx', 'odp', 'doc', 'docx', 'txt'];
      } else if (type == 'video') {
        allowedExtensions = ['mp4', 'mov', 'avi', 'webm'];
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _fileName = result.files.single.name;
          _fileBytes = result.files.single.bytes;
          _selectedInputType = type;
          _textController.clear();
          _linkController.clear();
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error picking file: $e');
    }
  }

  Future<void> _processAndNavigate() async {
    if (_isLoading) return;

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      setState(
          () => _errorMessage = 'You must be logged in to create content.');
      return;
    }

    final usageService = UsageService();
    final canGenerate = await usageService.canGenerateDeck(user.uid);

    if (!mounted) return;
    if (!canGenerate) {
      showDialog(
        context: context,
        builder: (_) => const UpgradeDialog(featureName: 'Daily Limit'),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Create a new cancellation token
    _cancelToken = CancellationToken();
    final cancelToken = _cancelToken!;

    try {
      final extractionService =
          Provider.of<ContentExtractionService>(context, listen: false);
      ExtractionResult? extractionResult;

      switch (_selectedInputType) {
        case 'topic':
          // Handle topic-based generation separately
          await _processTopicGeneration(user);
          return; // Exit early, topic handling is complete
        case 'text':
          if (_textController.text.trim().isEmpty) {
            throw Exception('Text field cannot be empty.');
          }
          extractionResult = ExtractionResult(
            text: _textController.text,
            suggestedTitle: 'Pasted Text',
          );
          break;
        case 'link':
          if (_linkController.text.trim().isEmpty) {
            throw Exception('URL field cannot be empty.');
          }
          if (!_checkProAccess('Web Link')) {
            setState(() => _isLoading = false);
            return;
          }
          extractionResult = await extractionService.extractContent(
            type: 'link',
            input: _linkController.text,
            userId: user.uid,
            cancelToken: cancelToken,
            onProgress: (message) {
              if (!cancelToken.isCancelled && mounted) {
                setState(() => _extractionProgress = message);
              }
            },
          );
          break;
        case 'pdf':
        case 'slides':
          if (_fileBytes == null) throw Exception('No file selected.');
          if (!_checkProAccess('Document Analysis')) {
            setState(() => _isLoading = false);
            return;
          }
          extractionResult = await extractionService.extractContent(
            type: 'pdf',
            input: _fileBytes!,
            userId: user.uid,
            mimeType: _getMimeTypeFromName(_fileName!),
            cancelToken: cancelToken,
            onProgress: (message) {
              if (!cancelToken.isCancelled && mounted) {
                setState(() => _extractionProgress = message);
              }
            },
          );
          break;
        case 'image':
          if (_fileBytes == null) throw Exception('No image file selected.');
          if (!_checkProAccess('Image Analysis')) {
            setState(() => _isLoading = false);
            return;
          }
          extractionResult = await extractionService.extractContent(
            type: 'image',
            input: _fileBytes!,
            userId: user.uid,
            mimeType: _getMimeTypeFromName(_fileName!),
            cancelToken: cancelToken,
            onProgress: (message) {
              if (!cancelToken.isCancelled && mounted) {
                setState(() => _extractionProgress = message);
              }
            },
          );
          break;
        case 'audio':
          if (_fileBytes == null) throw Exception('No audio file selected.');
          if (!_checkProAccess('Audio Analysis')) {
            setState(() => _isLoading = false);
            return;
          }
          extractionResult = await extractionService.extractContent(
            type: 'audio',
            input: _fileBytes!,
            userId: user.uid,
            mimeType: _getMimeTypeFromName(_fileName!),
            cancelToken: cancelToken,
            onProgress: (message) {
              if (!cancelToken.isCancelled && mounted) {
                setState(() => _extractionProgress = message);
              }
            },
          );
          break;
        case 'video':
          if (_fileBytes == null) throw Exception('No video file selected.');
          if (!_checkProAccess('Video Analysis')) {
            setState(() => _isLoading = false);
            return;
          }
          extractionResult = await extractionService.extractContent(
            type: 'video',
            input: _fileBytes!,
            userId: user.uid,
            mimeType: _getMimeTypeFromName(_fileName!),
            cancelToken: cancelToken,
            onProgress: (message) {
              if (!cancelToken.isCancelled && mounted) {
                setState(() => _extractionProgress = message);
              }
            },
          );
          break;
        default:
          throw Exception('Please provide some content first.');
      }

      if (extractionResult.text.trim().isEmpty) {
        throw Exception('Could not extract any content from the source.');
      }

      if (!cancelToken.isCancelled) {
        await usageService.recordDeckGeneration(user.uid);
        if (mounted) {
          // Use the cache to pass the result
          ExtractionResultCache.set(extractionResult);
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.pushNamed('extraction-view');
            }
          });
        }
      }
    } on CancelledException {
      // User cancelled
    } catch (e) {
      if (!cancelToken.isCancelled && mounted) {
        setState(
            () => _errorMessage = e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WebColors.background,
      body: Stack(
        children: [
          _buildDiscoveryBackground(),
          Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: _buildCanvas(),
                  ),
                ),
              ),
              _buildBottomActionBar(),
            ],
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildDiscoveryBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: WebColors.background,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -200,
            right: -200,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    WebColors.primary.withOpacity(0.08),
                    WebColors.primary.withOpacity(0),
                  ],
                ),
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: 100, duration: 10.seconds),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFC026D3).withOpacity(0.05),
                    const Color(0xFFC026D3).withOpacity(0),
                  ],
                ),
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveX(begin: 0, end: 150, duration: 15.seconds),
          CustomPaint(
            size: Size.infinite,
            painter: GridPainter(WebColors.border.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_rounded,
                    color: WebColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Back to Library',
                  style: GoogleFonts.outfit(
                    color: WebColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'CREATION LAB',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: WebColors.textTertiary,
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
    if (user?.isPro ?? false) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: WebColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: WebColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded,
                color: WebColors.primary, size: 16),
            const SizedBox(width: 8),
            Text(
              'PRO ACCOUNT',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: WebColors.primary,
              ),
            ),
          ],
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: () => context.push('/settings/subscription'),
      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
      label: const Text('UPGRADE TO PRO'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.outfit(
            fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1),
      ),
    );
  }

  Widget _buildCanvas() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCanvasHeader(),
        const SizedBox(height: 60),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            );
          },
          child: _selectedInputType == 'none'
              ? _buildIntentGrid()
              : _buildActiveWorkspace(),
        ),
      ],
    );
  }

  Widget _buildCanvasHeader() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              WebColors.HeroGradient.createShader(bounds),
          child: Text(
            _selectedInputType == 'none'
                ? 'Ignite Your Knowledge'
                : _getWorkspaceTitle(),
            style: GoogleFonts.outfit(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _selectedInputType == 'none'
              ? 'Choose a source and let AI craft your perfect study material.'
              : _getWorkspaceSubtitle(),
          style: GoogleFonts.outfit(
            fontSize: 20,
            color: WebColors.textSecondary,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  String _getWorkspaceTitle() {
    switch (_selectedInputType) {
      case 'topic':
        return 'Topic Discovery';
      case 'text':
        return 'Text Alchemist';
      case 'link':
        return 'Web Intelligence';
      case 'pdf':
        return 'Document Lab';
      case 'slides':
        return 'Presentation Lab';
      case 'image':
        return 'Visual Scanner';
      case 'audio':
        return 'Audio Studio';
      case 'video':
        return 'Video Analysis';
      case 'exam':
        return 'Tutor Master';
      default:
        return 'Workspace';
    }
  }

  String _getWorkspaceSubtitle() {
    switch (_selectedInputType) {
      case 'topic':
        return 'Transform a simple idea into an expert deck.';
      case 'text':
        return 'Synthesize your notes into structured knowledge.';
      case 'link':
        return 'Extract wisdom from any corner of the web.';
      default:
        return 'Configure your source for AI processing.';
    }
  }

  Widget _buildIntentGrid() {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      alignment: WrapAlignment.center,
      children: [
        _buildIntentCard(0, Icons.lightbulb_outline, 'TOPIC',
            'Generate from an idea', 'topic'),
        _buildIntentCard(1, Icons.edit_note_rounded, 'TEXT',
            'Paste notes or articles', 'text'),
        _buildIntentCard(
            2, Icons.link_rounded, 'WEB', 'Analyze URLs & YouTube', 'link'),
        _buildIntentCard(3, Icons.picture_as_pdf_rounded, 'PDF',
            'Extract from documents', 'pdf'),
        _buildIntentCard(4, Icons.slideshow_rounded, 'SLIDES',
            'Convert presentations', 'slides'),
        _buildIntentCard(5, Icons.image_outlined, 'IMAGE',
            'Scan charts & captures', 'image'),
        _buildIntentCard(
            6, Icons.mic_none_rounded, 'AUDIO', 'Analyze recordings', 'audio'),
        _buildIntentCard(
            7, Icons.videocam_outlined, 'VIDEO', 'Watch & summarize', 'video'),
      ],
    );
  }

  Widget _buildIntentCard(
      int index, IconData icon, String title, String subtitle, String type) {
    return _buildGlassCard(
      width: 260,
      height: 200,
      onTap: () {
        setState(() {
          _selectedInputType = type;
          _tabController.animateTo(index);
        });
      },
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: WebColors.primary, size: 32),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: WebColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: WebColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (type != 'text' && type != 'topic')
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: WebColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PRO',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: WebColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    )
        .animate(delay: (index * 50).ms)
        .fadeIn()
        .scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildActiveWorkspace() {
    return Column(
      key: ValueKey(_selectedInputType),
      children: [
        _buildGlassCard(
          width: 900,
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        setState(() => _selectedInputType = 'none'),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: WebColors.backgroundAlt,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const Spacer(),
                  _buildWorkspaceBadge(),
                ],
              ),
              const SizedBox(height: 40),
              if (_errorMessage.isNotEmpty) ...[
                _buildErrorBanner(),
                const SizedBox(height: 24),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 300),
                child: _buildWorkspaceContent(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: WebColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: WebColors.primary.withOpacity(0.1)),
      ),
      child: Text(
        _selectedInputType.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: WebColors.primary,
        ),
      ),
    );
  }

  Widget _buildWorkspaceContent() {
    switch (_selectedInputType) {
      case 'topic':
        return _buildTopicInput();
      case 'text':
        return _buildTextInput();
      case 'link':
        return _buildLinkInput();
      case 'pdf':
      case 'slides':
      case 'image':
      case 'audio':
      case 'video':
        return _buildFileUpload(_selectedInputType);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomActionBar() {
    if (_selectedInputType == 'none' || _selectedInputType == 'exam')
      return const SizedBox(height: 40);

    return Container(
      padding: const EdgeInsets.all(40),
      child: _buildGenerateButton(),
    ).animate().fadeIn().slideY(begin: 0.5, end: 0);
  }

  Widget _buildGlassCard({
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final card = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: borderRadius ?? BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(32),
        child: card,
      );
    }
    return card;
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: WebColors.background.withOpacity(0.8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Center(
            child: _buildLoadingState(),
          ),
        ),
      ),
    );
  }

  // Legacy sidebar methods removed.

  // ===========================================================
  // TOPIC-BASED LEARNING
  // ===========================================================

  Widget _buildTopicInput() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) =>
              WebColors.HeroGradient.createShader(bounds),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 80, color: Colors.white),
        )
            .animate()
            .scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 32),
        Text(
          'Master Any Topic',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: WebColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Tell us what you want to learn, and AI will build\na complete study deck for you in seconds.',
          style: GoogleFonts.outfit(
            fontSize: 18,
            color: WebColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 60),
        Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              TextField(
                controller: _topicController,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: WebColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g., "Quantum Physics", "Modern Art History"...',
                  hintStyle: GoogleFonts.outfit(
                    color: WebColors.textTertiary,
                    fontSize: 18,
                  ),
                  prefixIcon: null,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 40),
                  filled: true,
                  fillColor: WebColors.backgroundAlt.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: WebColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildSectionHeader('SELECT DIFFICULTY'),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildWebDepthChip('Beginner', 'beginner'),
                            const SizedBox(width: 12),
                            _buildWebDepthChip('Intermediate', 'intermediate'),
                            const SizedBox(width: 12),
                            _buildWebDepthChip('Advanced', 'advanced'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildSectionHeader(
                            'DECK SIZE: ${_topicCardCount.toInt()} CARDS'),
                        const SizedBox(height: 16),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 6,
                            activeTrackColor: WebColors.primary,
                            inactiveTrackColor:
                                WebColors.primary.withOpacity(0.1),
                            thumbColor: WebColors.primary,
                            overlayColor: WebColors.primary.withOpacity(0.1),
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 10),
                          ),
                          child: Slider(
                            value: _topicCardCount,
                            min: 5,
                            max: 30,
                            divisions: 5,
                            onChanged: (value) {
                              if (value > 10) {
                                final user = Provider.of<UserModel?>(context,
                                    listen: false);
                                if (user != null && !user.isPro) {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const UpgradeDialog(
                                        featureName: 'Larger Decks'),
                                  );
                                  return;
                                }
                              }
                              setState(() => _topicCardCount = value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        _buildAIDisclaimer(),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).textTheme.labelSmall?.color?.withOpacity(0.5),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildAIDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 20, color: WebColors.primary),
          const SizedBox(width: 12),
          Text(
            'AI-generated content. Verify important facts with trusted sources.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: WebColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDepthChip(String label, String value) {
    final isSelected = _topicDepth == value;
    return GestureDetector(
      onTap: () => setState(() => _topicDepth = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _processTopicGeneration(UserModel user) async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      setState(() => _errorMessage = 'Please enter a topic to learn about.');
      setState(() => _isLoading = false);
      return;
    }

    // Create token for topic generation too
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
            context.pushNamed('results-view', pathParameters: {'folderId': folderId});
          }
        });
      }
    } catch (e) {
      if (!cancelToken.isCancelled && mounted) {
        setState(
            () => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextInput() {
    return Column(
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 400),
          decoration: BoxDecoration(
            color: WebColors.backgroundAlt.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: WebColors.border.withOpacity(0.5)),
          ),
          child: TextField(
            controller: _textController,
            maxLines: null,
            style: GoogleFonts.outfit(
              color: WebColors.textPrimary,
              fontSize: 18,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText:
                  'Paste your lecture notes, articles, or any textual content here...',
              hintStyle: GoogleFonts.outfit(
                  color: WebColors.textTertiary, fontSize: 18),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.all(32),
              filled: false,
            ),
            onChanged: (_) {
              if (_selectedInputType != 'text')
                setState(() => _selectedInputType = 'text');
            },
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          children: [
            _buildSupportedChip(Icons.text_fields_rounded, 'Any Text'),
            _buildSupportedChip(Icons.copy_rounded, 'Lecture Notes'),
            _buildSupportedChip(Icons.article_rounded, 'Articles'),
          ],
        ),
      ],
    );
  }



  Widget _buildLinkInput() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: WebColors.primary.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.public_rounded,
              size: 40, color: WebColors.primary),
        ),
        const SizedBox(height: 32),
        Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: TextField(
            controller: _linkController,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: WebColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'https://example.com/article',
              hintStyle: GoogleFonts.outfit(color: WebColors.textTertiary),
              filled: true,
              fillColor: WebColors.backgroundAlt.withOpacity(0.5),
              prefixIcon: const Icon(Icons.link_rounded),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: WebColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: WebColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:
                    const BorderSide(color: WebColors.primary, width: 2),
              ),
            ),
            onChanged: (value) {
              if (_selectedInputType != 'link')
                setState(() => _selectedInputType = 'link');
            },
          ),
        ),
        const SizedBox(height: 40),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _buildSupportedChip(Icons.play_circle_rounded, 'YouTube Videos'),
            _buildSupportedChip(Icons.article_rounded, 'Blog Articles'),
            _buildSupportedChip(Icons.web_rounded, 'Web Pages'),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSupportedChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: WebColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: WebColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUpload(String type) {
    final hasFile = _fileName != null && _selectedInputType == type;
    if (hasFile) return _buildFilePreview();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _pickFile(type),
          child: CustomPaint(
            painter: DashedRectPainter(
              color: WebColors.primary.withOpacity(0.3),
              strokeWidth: 2,
              gap: 8,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 100),
              decoration: BoxDecoration(
                color: WebColors.primary.withOpacity(0.02),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: WebColors.subtleShadow,
                    ),
                    child: Icon(
                      _getFileUploadIcon(type),
                      size: 64,
                      color: WebColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _getFileUploadTitle(type),
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: WebColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getFileUploadSubtitle(type),
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      color: WebColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: WebColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Browse Files',
                      style: GoogleFonts.outfit(
                        color: WebColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildFilePreview() {
    return Center(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(60),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5)),
          boxShadow: WebColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: Color(0xFF22C55E),
                size: 64,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 40),
            Text(
              'FILE SELECTED',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF22C55E),
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _fileName!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: WebColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ready for AI analysis',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: WebColors.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _fileName = null;
                  _fileBytes = null;
                });
              },
              icon: Icon(Icons.delete_sweep_rounded,
                  color: Colors.red[400], size: 20),
              label: Text(
                'Remove and select another',
                style: GoogleFonts.outfit(
                  color: Colors.red[400],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                backgroundColor:
                    (Colors.red[50] ?? Colors.red).withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error, color: const Color(0xFFDC2626), size: 20),
          const SizedBox(width: 12),
          Text(
            _errorMessage,
            style: TextStyle(
              color: const Color(0xFFDC2626),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate().shake();
  }

  Widget _buildGenerateButton() {
    return Container(
      width: 400,
      height: 72,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WebColors.primary, Color(0xFF7C3AED), Color(0xFFC026D3)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WebColors.primary.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _processAndNavigate,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Text(
              'Generate Study Deck',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 2.seconds, color: Colors.white.withOpacity(0.3))
        .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.02, 1.02),
            duration: 1500.ms,
            curve: Curves.easeInOut);
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WebColors.primary.withOpacity(0.1),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.5, 1.5),
                  duration: 1.seconds,
                  curve: Curves.easeOut,
                )
                .fadeOut(duration: 1.seconds),
            Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(4),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(WebColors.primary),
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
              ),
            ),
            const Icon(Icons.auto_awesome_rounded,
                color: WebColors.primary, size: 32),
          ],
        ),
        const SizedBox(height: 48),
        Text(
          _extractionProgress.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: WebColors.textPrimary,
            letterSpacing: 2,
          ),
        ).animate().fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 12),
        Text(
          'Our AI is analyzing and structuring your knowledge...',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: WebColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ).animate(delay: 200.ms).fadeIn(),
      ],
    );
  }

  IconData _getFileUploadIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'slides':
        return Icons.slideshow_rounded;
      case 'image':
        return Icons.add_a_photo_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      case 'video':
        return Icons.videocam_rounded;
      default:
        return Icons.cloud_upload_outlined;
    }
  }

  String _getFileUploadTitle(String type) {
    switch (type) {
      case 'pdf':
        return 'Choose a PDF file';
      case 'slides':
        return 'Upload Presentation';
      case 'image':
        return 'Select an Image';
      case 'audio':
        return 'Select Audio File';
      case 'video':
        return 'Select Video File';
      default:
        return 'Select File';
    }
  }

  String _getFileUploadSubtitle(String type) {
    switch (type) {
      case 'pdf':
        return 'Drop your PDF here or click to browse';
      case 'slides':
        return 'Upload PPT, PPTX, or other presentation slides';
      case 'image':
        return 'Upload an image with text to turn it into flashcards';
      case 'audio':
        return 'Upload lecture recordings, notes, or educational audio';
      case 'video':
        return 'Upload educational video clips, lectures, or tutorials';
      default:
        return 'Select a file from your device';
    }
  }

}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Simple dashed border painter
class DashedRectPainter extends CustomPainter {
  final double strokeWidth;
  final Color color;
  final double gap;

  DashedRectPainter(
      {this.strokeWidth = 2.0, this.color = Colors.grey, this.gap = 5.0});

  @override
  void paint(Canvas canvas, Size size) {
    Paint dashedPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double x = size.width;
    double y = size.height;

    Path topPath = getDashedPath(
      a: const Point(0, 0),
      b: Point(x, 0),
      gap: gap,
    );

    Path rightPath = getDashedPath(
      a: Point(x, 0),
      b: Point(x, y),
      gap: gap,
    );

    Path bottomPath = getDashedPath(
      a: Point(0, y),
      b: Point(x, y),
      gap: gap,
    );

    Path leftPath = getDashedPath(
      a: const Point(0, 0),
      b: Point(0, y),
      gap: gap,
    );

    canvas.drawPath(topPath, dashedPaint);
    canvas.drawPath(rightPath, dashedPaint);
    canvas.drawPath(bottomPath, dashedPaint);
    canvas.drawPath(leftPath, dashedPaint);
  }

  Path getDashedPath({
    required Point a,
    required Point b,
    required double gap,
  }) {
    Size size = Size(b.x - a.x, b.y - a.y);
    Path path = Path();
    path.moveTo(a.x, a.y);
    bool shouldDraw = true;
    Point currentPoint = Point(a.x, a.y);

    num radians = dart_math.atan(size.height / size.width);

    num dx = gap * dart_math.cos(radians);
    num dy = gap * dart_math.sin(radians);

    while (shouldDraw) {
      currentPoint = Point(
        currentPoint.x + dx,
        currentPoint.y + dy,
      );
      if (shouldDraw) {
        path.lineTo(currentPoint.x, currentPoint.y);
      } else {
        path.moveTo(currentPoint.x, currentPoint.y);
      }
      shouldDraw = !shouldDraw;
    }
    return path;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class Point {
  final double x;
  final double y;
  const Point(this.x, this.y);
}

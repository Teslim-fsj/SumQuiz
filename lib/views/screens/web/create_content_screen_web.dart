import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/services/extraction_result_cache.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';

// ─────────────────────────────────────────────────────────────
//  Screen states
// ─────────────────────────────────────────────────────────────
enum _ScreenState { idle, building, done }

class CreateContentScreenWeb extends StatefulWidget {
  const CreateContentScreenWeb({super.key});

  @override
  State<CreateContentScreenWeb> createState() => _CreateContentScreenWebState();
}

class _CreateContentScreenWebState extends State<CreateContentScreenWeb>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // ── Upload state ─────────────────────────────────────────────
  String? _fileName;
  Uint8List? _fileBytes;
  String? _mimeType;
  String _uploadType = ''; // 'pdf', 'image', 'audio', 'link', 'video'

  // ── Screen state ─────────────────────────────────────────────
  _ScreenState _screenState = _ScreenState.idle;
  String _errorMessage = '';
  CancellationToken? _cancelToken;

  // ── Build animation steps ─────────────────────────────────────
  late AnimationController _buildAnimController;
  int _buildStepIndex = 0;
  final List<String> _buildSteps = [
    'Analyzing material…',
    'Creating summary…',
    'Generating quiz questions…',
    'Building flashcards…',
    'Finalizing your study pack…',
  ];

  // ── Result from generation ───────────────────────────────────
  String _resultFolderId = '';
  ExtractionResult? _extractionResult;
  String _packTitle = '';
  String _packSource = '';

  @override
  void initState() {
    super.initState();
    _buildAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _buildAnimController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  Upload helpers
  // ─────────────────────────────────────────────────────────────
  String _getMimeType(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt': 'text/plain',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'm4a': 'audio/mp4',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  Future<void> _handleAttachType(String type) async {
    final user = Provider.of<UserModel?>(context, listen: false);

    // Pro check for non-text types
    if ((type == 'pdf' || type == 'image' || type == 'audio' || type == 'video' || type == 'slides') &&
        user != null && !user.isPro) {
      showDialog(
        context: context,
        builder: (_) => UpgradeDialog(featureName: _typeLabel(type)),
      );
      return;
    }

    if (type == 'link') {
      // Already handled via input box (user types URL)
      setState(() {
        _uploadType = 'link';
        _fileName = null;
        _fileBytes = null;
      });
      _inputFocusNode.requestFocus();
      return;
    }

    List<String> allowed;
    switch (type) {
      case 'pdf':
      case 'slides':
        allowed = ['pdf', 'ppt', 'pptx', 'doc', 'docx', 'txt'];
        break;
      case 'image':
        allowed = ['jpg', 'jpeg', 'png', 'webp'];
        break;
      case 'audio':
        allowed = ['mp3', 'wav', 'm4a', 'aac'];
        break;
      case 'video':
        allowed = ['mp4', 'mov', 'avi', 'webm'];
        break;
      default:
        allowed = ['pdf'];
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowed,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      setState(() {
        _fileName = file.name;
        _fileBytes = file.bytes;
        _mimeType = _getMimeType(file.name);
        _uploadType = type;
      });
    }
  }

  String _typeLabel(String type) {
    const labels = {
      'pdf': 'PDF / Document Upload',
      'slides': 'Slides Upload',
      'image': 'Image Scan',
      'audio': 'Audio Analysis',
      'video': 'Video Analysis',
      'link': 'Web Link',
    };
    return labels[type] ?? type;
  }

  // ─────────────────────────────────────────────────────────────
  //  Main generate flow
  // ─────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    final raw = _inputController.text.trim();
    if (raw.isEmpty && _fileBytes == null) {
      setState(() => _errorMessage = 'Type a topic or attach a file to start.');
      return;
    }
    if (_screenState != _ScreenState.idle) return;

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      setState(() => _errorMessage = 'You must be signed in.');
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
      _screenState = _ScreenState.building;
      _buildStepIndex = 0;
      _errorMessage = '';
      _packTitle = raw.isEmpty ? (_fileName ?? 'Uploaded Content') : raw;
      _packSource =
          _fileBytes != null ? (_fileName ?? 'File') : 'Typed / pasted content';
    });

    _cancelToken = CancellationToken();
    final cancelToken = _cancelToken!;

    // Begin step animation loop
    _animateBuildSteps(cancelToken);

    try {
      if (_fileBytes != null) {
        // File-based extraction
        final extractionService =
            Provider.of<ContentExtractionService>(context, listen: false);

        String extractType;
        if (_uploadType == 'image') {
          extractType = 'image';
        } else if (_uploadType == 'audio') {
          extractType = 'audio';
        } else if (_uploadType == 'video') {
          extractType = 'video';
        } else {
          extractType = 'pdf';
        }

        final result = await extractionService.extractContent(
          type: extractType,
          input: _fileBytes!,
          userId: user.uid,
          mimeType: _mimeType,
          cancelToken: cancelToken,
          onProgress: (_) {},
        );
        if (!cancelToken.isCancelled && mounted) {
          await usageService.recordDeckGeneration(user.uid);
          if (extractType == 'pdf' || extractType == 'image' || extractType == 'audio') {
            await usageService.recordAction(user.uid, 'upload');
          }
          _extractionResult = result;
          setState(() => _screenState = _ScreenState.done);
        }
      } else if (_uploadType == 'link' ||
          (raw.startsWith('http://') || raw.startsWith('https://'))) {
        // Link-based extraction
        final extractionService =
            Provider.of<ContentExtractionService>(context, listen: false);
        final result = await extractionService.extractContent(
          type: 'link',
          input: raw,
          userId: user.uid,
          cancelToken: cancelToken,
          onProgress: (_) {},
        );
        if (!cancelToken.isCancelled && mounted) {
          await usageService.recordDeckGeneration(user.uid);
          _extractionResult = result;
          setState(() => _screenState = _ScreenState.done);
        }
      } else {
        // Topic or text
        final aiService =
            Provider.of<EnhancedAIService>(context, listen: false);
        final localDb =
            Provider.of<LocalDatabaseService>(context, listen: false);
        await usageService.recordDeckGeneration(user.uid);

        if (raw.split(' ').length <= 8 && !raw.contains('\n')) {
          // Treat as topic
          final folderId = await aiService.generateFromTopic(
            topic: raw,
            userId: user.uid,
            localDb: localDb,
            depth: 'intermediate',
            cardCount: 20,
          );
          if (!cancelToken.isCancelled && mounted) {
            _resultFolderId = folderId;
            setState(() => _screenState = _ScreenState.done);
          }
        } else {
          // Treat as pasted text
          final extractionService =
              Provider.of<ContentExtractionService>(context, listen: false);
          final result = await extractionService.extractContent(
            type: 'text',
            input: raw,
            userId: user.uid,
            cancelToken: cancelToken,
            onProgress: (_) {},
          );
          if (!cancelToken.isCancelled && mounted) {
            _extractionResult = result;
            setState(() => _screenState = _ScreenState.done);
          }
        }
      }
    } catch (e) {
      if (!cancelToken.isCancelled && mounted) {
        setState(() {
          _screenState = _ScreenState.idle;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _animateBuildSteps(CancellationToken cancelToken) async {
    for (int i = 0; i < _buildSteps.length; i++) {
      if (cancelToken.isCancelled || !mounted) return;
      if (_screenState != _ScreenState.building) return;
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted && _screenState == _ScreenState.building) {
        setState(() => _buildStepIndex = i);
      }
    }
  }

  void _navigateToStudyPack() {
    if (_resultFolderId.isNotEmpty) {
      context.push('/library/results-view/$_resultFolderId');
    } else if (_extractionResult != null) {
      ExtractionResultCache.set(_extractionResult!);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push('/create/extraction-view');
      });
    }
  }

  void _reset() {
    _cancelToken?.cancel();
    setState(() {
      _screenState = _ScreenState.idle;
      _buildStepIndex = 0;
      _errorMessage = '';
      _fileName = null;
      _fileBytes = null;
      _mimeType = null;
      _uploadType = '';
      _resultFolderId = '';
      _extractionResult = null;
    });
    _inputController.clear();
  }

  // ─────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WebColors.background,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 740),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic,
                              )),
                              child: child,
                            ),
                          ),
                          child: _screenState == _ScreenState.idle
                              ? _buildIdleContent()
                              : _screenState == _ScreenState.building
                                  ? _buildBuildingCard()
                                  : _buildDoneCard(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage.isNotEmpty) _buildErrorBanner(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Top bar
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_rounded,
                    color: WebColors.textSecondary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Back',
                  style: GoogleFonts.outfit(
                    color: WebColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: WebColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: WebColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded,
                color: WebColors.primary, size: 15),
            const SizedBox(width: 6),
            Text(
              'PRO',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: WebColors.primary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: () => context.push('/settings/subscription'),
      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
      label: const Text('Upgrade to Pro'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle:
            GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  IDLE — main input
  // ─────────────────────────────────────────────────────────────
  Widget _buildIdleContent() {
    return Column(
      key: const ValueKey('idle'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        _buildHeroText(),
        const SizedBox(height: 40),
        _buildChatInputBox(),
        const SizedBox(height: 24),
        _buildQuickTopics(),
        const SizedBox(height: 48),
        _buildAINote(),
      ],
    );
  }

  Widget _buildHeroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              WebColors.HeroGradient.createShader(bounds),
          child: Text(
            'Turn anything into\na study system',
            style: GoogleFonts.outfit(
              fontSize: 52,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1.5,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Type a topic, paste notes, or upload files — AI does the rest.',
          style: GoogleFonts.outfit(
            fontSize: 18,
            color: WebColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildChatInputBox() {
    final hasFile = _fileName != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WebColors.primary.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
          ),
        ],
        border: Border.all(color: WebColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          if (hasFile) _buildFileChip(),
          TextField(
            controller: _inputController,
            focusNode: _inputFocusNode,
            maxLines: 5,
            minLines: 3,
            style: GoogleFonts.outfit(
              fontSize: 17,
              color: WebColors.textPrimary,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: 'Type a topic or paste your material here…',
              hintStyle: GoogleFonts.outfit(
                color: WebColors.textTertiary,
                fontSize: 17,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            ),
            onChanged: (v) {
              if (_errorMessage.isNotEmpty) {
                setState(() => _errorMessage = '');
              }
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: WebColors.background,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              border: Border(
                  top: BorderSide(color: WebColors.border, width: 1)),
            ),
            child: Row(
              children: [
                // Attach button
                _buildAttachButton(),
                const Spacer(),
                // Generate button
                ElevatedButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Generate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WebColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w700),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildAttachButton() {
    return PopupMenuButton<String>(
      onSelected: _handleAttachType,
      tooltip: 'Attach file or link',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, -240),
      itemBuilder: (_) => [
        _attachMenuItem(Icons.picture_as_pdf_rounded, 'PDF / Document', 'pdf', false),
        _attachMenuItem(Icons.slideshow_rounded, 'Slides (PPT)', 'slides', false),
        _attachMenuItem(Icons.image_outlined, 'Image / Scan', 'image', false),
        _attachMenuItem(Icons.mic_none_rounded, 'Audio', 'audio', false),
        _attachMenuItem(Icons.videocam_outlined, 'Video', 'video', false),
        _attachMenuItem(Icons.link_rounded, 'Paste URL', 'link', true),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: WebColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_outline_rounded,
                size: 18, color: WebColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Attach',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: WebColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _attachMenuItem(
      IconData icon, String label, String value, bool isFree) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: WebColors.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 14, color: WebColors.textPrimary),
          ),
          if (!isFree) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: WebColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PRO',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: WebColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileChip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: WebColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file_rounded, size: 16, color: WebColors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _fileName ?? '',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: WebColors.primary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
              _fileName = null;
              _fileBytes = null;
              _uploadType = '';
            }),
            child: const Icon(Icons.close_rounded, size: 16, color: WebColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTopics() {
    const topics = [
      'Photosynthesis',
      'Mitosis',
      'Algebra',
      'World War II',
      'Newton\'s Laws',
      'Cell Biology',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK TOPICS',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: WebColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: topics.asMap().entries.map((entry) {
            return GestureDetector(
              onTap: () {
                _inputController.text = entry.value;
                _inputFocusNode.requestFocus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: WebColors.border),
                  boxShadow: WebColors.subtleShadow,
                ),
                child: Text(
                  entry.value,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: WebColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
                .animate(delay: (entry.key * 40).ms)
                .fadeIn()
                .scale(begin: const Offset(0.9, 0.9));
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAINote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WebColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: WebColors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI-generated content — always verify with trusted sources.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: WebColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILDING — animated progress card
  // ─────────────────────────────────────────────────────────────
  Widget _buildBuildingCard() {
    return Column(
      key: const ValueKey('building'),
      children: [
        const SizedBox(height: 60),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: WebColors.border),
            boxShadow: WebColors.cardShadow,
          ),
          child: Column(
            children: [
              // Animated icon
              ShaderMask(
                shaderCallback: (b) =>
                    WebColors.HeroGradient.createShader(b),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 56, color: Colors.white),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.12, 1.12),
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 32),
              Text(
                'Building your study pack…',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              // Steps
              ..._buildSteps.asMap().entries.map((e) {
                final done = e.key < _buildStepIndex;
                final active = e.key == _buildStepIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AnimatedOpacity(
                    opacity: active || done ? 1.0 : 0.3,
                    duration: const Duration(milliseconds: 400),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: done
                                ? const Color(0xFF22C55E)
                                : active
                                    ? WebColors.primary
                                    : WebColors.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: done
                                  ? const Color(0xFF22C55E)
                                  : active
                                      ? WebColors.primary
                                      : WebColors.border,
                            ),
                          ),
                          child: Icon(
                            done
                                ? Icons.check_rounded
                                : active
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: done || active ? Colors.white : WebColors.border,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          e.value,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: done
                                ? const Color(0xFF22C55E)
                                : active
                                    ? WebColors.textPrimary
                                    : WebColors.textTertiary,
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 10),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: WebColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _cancelToken?.cancel();
                  _reset();
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(color: WebColors.textTertiary),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).scale(
              begin: const Offset(0.97, 0.97),
              end: const Offset(1, 1),
            ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  DONE — study pack card
  // ─────────────────────────────────────────────────────────────
  Widget _buildDoneCard() {
    return Column(
      key: const ValueKey('done'),
      children: [
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: WebColors.border),
            boxShadow: WebColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: WebColors.HeroGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Study Pack Ready!',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: WebColors.primary,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          _packTitle,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: WebColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Source: $_packSource',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: WebColors.textTertiary,
                ),
              ),
              const SizedBox(height: 28),
              // Contents
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: WebColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: WebColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTAINS',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: WebColors.textTertiary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _packItem(Icons.text_snippet_outlined, 'Summary', const Color(0xFF6366F1)),
                    _packItem(Icons.style_rounded, 'Flashcards', const Color(0xFF8B5CF6)),
                    _packItem(Icons.quiz_outlined, 'Quiz', const Color(0xFF10B981)),
                    _packItem(Icons.description_outlined, 'Exam (if applicable)', const Color(0xFFEC4899)),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: WebColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '0%',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: WebColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: 0,
                      backgroundColor: WebColors.border,
                      color: WebColors.primary,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // CTAs
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: _navigateToStudyPack,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Studying'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WebColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _navigateToStudyPack,
                      icon: const Icon(Icons.bookmark_border_rounded),
                      label: const Text('Save to Library'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WebColors.primary,
                        side: const BorderSide(color: WebColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Create another pack'),
                  style: TextButton.styleFrom(
                    foregroundColor: WebColors.textTertiary,
                    textStyle: GoogleFonts.outfit(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
      ],
    );
  }

  Widget _packItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: WebColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const Icon(Icons.check_circle_rounded,
              size: 18, color: Color(0xFF22C55E)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Background
  // ─────────────────────────────────────────────────────────────
  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(color: WebColors.background),
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
                gradient: RadialGradient(colors: [
                  WebColors.primary.withValues(alpha: 0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: 80, duration: 10.seconds),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFC026D3).withValues(alpha: 0.05),
                  Colors.transparent,
                ]),
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveX(begin: 0, end: 100, duration: 14.seconds),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Error banner
  // ─────────────────────────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Positioned(
      bottom: 32,
      left: 32,
      right: 32,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _errorMessage = ''),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: Color(0xFFEF4444)),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.3, end: 0),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Attach Picker Sheet
// ─────────────────────────────────────────────────────────────
// End of file classes

// ─────────────────────────────────────────────────────────────
//  Grid background painter (reused from old code)
// ─────────────────────────────────────────────────────────────
class GridPainter extends CustomPainter {
  final Color color;
  GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter old) => old.color != color;
}

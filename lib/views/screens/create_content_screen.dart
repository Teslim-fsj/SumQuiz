import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/extraction_result.dart';
import '../../models/user_model.dart';
import '../../services/usage_service.dart';
import '../../services/content_extraction_service.dart';
import '../../services/enhanced_ai_service.dart';
import '../../services/local_database_service.dart';
import '../../utils/cancellation_token.dart';
import '../../services/extraction_result_cache.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// ─────────────────────────────────────────────────────────────
//  Input validator (shared utility)
// ─────────────────────────────────────────────────────────────
class InputValidator {
  static bool isValidUrl(String url) {
    if (url.trim().isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.hasAuthority;
    } catch (_) {
      return false;
    }
  }

  static bool isYoutubeUrl(String url) =>
      url.contains('youtube.com/watch') ||
      url.contains('youtu.be/') ||
      url.contains('youtube.com/shorts/');
}

// ─────────────────────────────────────────────────────────────
//  Screen states
// ─────────────────────────────────────────────────────────────
enum _ScreenState { idle, building, done }

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // ── Upload state ─────────────────────────────────────────────
  String? _fileName;
  Uint8List? _fileBytes;
  String? _mimeType;
  String _uploadType = '';

  // ── Screen state ─────────────────────────────────────────────
  _ScreenState _screenState = _ScreenState.idle;
  String _errorMessage = '';
  CancellationToken? _cancelToken;

  // ── Build animation steps ─────────────────────────────────────
  int _buildStepIndex = 0;
  final List<String> _buildSteps = [
    'Initializing AI engine...',
    'Reading and extracting content...',
    'Analyzing key concepts...',
    'Generating study materials...',
    'Finalizing your study pack...'
  ];

  // ── Result ───────────────────────────────────────────────────
  String _resultFolderId = '';
  ExtractionResult? _extractionResult;
  String _packTitle = '';
  String _packSource = '';

  // ── Colors Helper ───────────────────────────────────────────
  Color _getBg() => Theme.of(context).scaffoldBackgroundColor;
  Color _getPrimary() => Theme.of(context).colorScheme.primary;
  Color _getCard() => Theme.of(context).cardColor;
  Color _getBorder() => Theme.of(context).dividerColor;
  Color _getTextPrimary() => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color _getTextSecondary() => (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white).withValues(alpha: 0.7);
  Color _getTextTertiary() => (Theme.of(context).textTheme.bodySmall?.color ?? Colors.white).withValues(alpha: 0.4);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'm4a': 'audio/mp4',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  // ─────────────────────────────────────────────────────────────
  //  File attach
  // ─────────────────────────────────────────────────────────────
  Future<void> _handleAttachType(String type) async {
    final user = Provider.of<UserModel?>(context, listen: false);
    final isPro = user?.isPro ?? false;

    if (type != 'link' && !isPro) {
      showDialog(
        context: context,
        builder: (_) => UpgradeDialog(featureName: _typeLabel(type)),
      );
      return;
    }

    if (type == 'link') {
      setState(() => _uploadType = 'link');
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
      'link': 'Web Link',
    };
    return labels[type] ?? type;
  }

  // ─────────────────────────────────────────────────────────────
  //  Generate
  // ─────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    final raw = _inputController.text.trim();
    if (raw.isEmpty && _fileBytes == null) {
      setState(() => _errorMessage = 'Type a topic or attach a file first.');
      return;
    }
    if (_screenState != _ScreenState.idle) return;

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      setState(() => _errorMessage = 'Please sign in to continue.');
      return;
    }

    final usageService = UsageService();
    final action = _fileBytes != null ? 'upload' : 'generate';
    final canPerform = await usageService.canPerformAction(user.uid, action);
    if (!mounted) return;
    if (!canPerform) {
      showDialog(
        context: context,
        builder: (_) => UpgradeDialog(
          featureName: action == 'upload' ? 'Lifetime Upload Limit' : 'Daily Limit',
        ),
      );
      return;
    }

    setState(() {
      _screenState = _ScreenState.building;
      _buildStepIndex = 0;
      _errorMessage = '';
      _packTitle = raw.isEmpty ? (_fileName ?? 'Uploaded Content') : raw;
      _packSource =
          _fileBytes != null ? (_fileName ?? 'File') : 'Typed content';
    });

    _cancelToken = CancellationToken();
    final cancelToken = _cancelToken!;
    _animateBuildSteps(cancelToken);

    try {
      if (_fileBytes != null) {
        final extractionService =
            Provider.of<ContentExtractionService>(context, listen: false);
        String extractType;
        if (_uploadType == 'image') {
          extractType = 'image';
        } else if (_uploadType == 'audio') {
          extractType = 'audio';
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
          await usageService.recordAction(user.uid, action);
          await FirebaseCrashlytics.instance
              .log('Content extracted. Type: $extractType');

          await _generateFinalResults(result, user.uid, cancelToken);
        }
      } else if (_uploadType == 'link' ||
          (raw.startsWith('http://') || raw.startsWith('https://'))) {
        final extractionService =
            Provider.of<ContentExtractionService>(context, listen: false);

        // Detect if it's a YouTube URL to trigger Tier 0 Native Reasoning
        final type = InputValidator.isYoutubeUrl(raw) ? 'youtube' : 'link';

        final result = await extractionService.extractContent(
          type: type,
          input: raw,
          userId: user.uid,
          cancelToken: cancelToken,
          onProgress: (_) {},
        );
        if (!cancelToken.isCancelled && mounted) {
          await usageService.recordAction(user.uid, action);
          await _generateFinalResults(result, user.uid, cancelToken);
        }
      } else {
        final aiService = Provider.of<EnhancedAIService>(context, listen: false);
        final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
        final extractionService = Provider.of<ContentExtractionService>(context, listen: false);


        await usageService.recordAction(user.uid, action);

        if (raw.split(' ').length <= 8 && !raw.contains('\n')) {
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
            final result = await extractionService.extractContent(
            type: 'text',
            input: raw,
            userId: user.uid,
            cancelToken: cancelToken,
            onProgress: (_) {},
          );
          if (!cancelToken.isCancelled && mounted) {
            await _generateFinalResults(result, user.uid, cancelToken);
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

  Future<void> _generateFinalResults(ExtractionResult result, String userId,
      CancellationToken cancelToken) async {
    try {
      final aiService = Provider.of<EnhancedAIService>(context, listen: false);
      final localDb = Provider.of<LocalDatabaseService>(context, listen: false);

      // Update animation step to "Generating..." (index 3 in _buildSteps)
      if (mounted) setState(() => _buildStepIndex = 3);

      final folderId = await aiService.generateAndStoreOutputs(
        text: result.text,
        title: _packTitle,
        requestedOutputs: ['summary', 'quiz', 'flashcards'],
        userId: userId,
        localDb: localDb,
        onProgress: (message) {
          developer.log('Generation progress: $message', name: 'CreateContentScreen');
        },
        cancelToken: cancelToken,
      );

      if (!cancelToken.isCancelled && mounted) {
        _resultFolderId = folderId;
        setState(() => _screenState = _ScreenState.done);
      }
    } catch (e) {
      if (!cancelToken.isCancelled && mounted) {
        setState(() {
          _screenState = _ScreenState.idle;
          _errorMessage = 'Failed to generate study materials: $e';
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBg(),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
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
              ],
            ),
          ),
          if (_errorMessage.isNotEmpty) _buildErrorBanner(),
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
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
      child: Stack(children: [
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getPrimary().withValues(alpha: 0.07),
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: 40, duration: 8.seconds),
        Positioned(
          bottom: 80,
          left: -60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEC4899).withValues(alpha: 0.05),
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveX(begin: 0, end: 30, duration: 11.seconds),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getBorder()),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: _getTextPrimary(), size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Create',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _getTextPrimary(),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getPrimary().withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: _getPrimary().withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, color: _getPrimary(), size: 14),
            const SizedBox(width: 5),
            Text(
              'PRO',
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: _getPrimary(),
                  letterSpacing: 0.8),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => context.push('/settings/subscription'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          'Go Pro',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  IDLE
  // ─────────────────────────────────────────────────────────────
  Widget _buildIdleContent() {
    return SingleChildScrollView(
      key: const ValueKey('idle'),
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildHero(),
          const SizedBox(height: 28),
          _buildInputCard(),
          const SizedBox(height: 20),
          _buildQuickTopics(),
          const SizedBox(height: 32),
          _buildAINote(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
          ).createShader(b),
          child: Text(
            'Turn anything\ninto a study\nsystem',
            style: GoogleFonts.outfit(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Type a topic, paste your notes, or attach a file.',
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: _getTextSecondary(),
            height: 1.5,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _buildInputCard() {
    final hasFile = _fileName != null;
    return Container(
      decoration: BoxDecoration(
        color: _getCard(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getBorder()),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
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
              fontSize: 15,
              color: _getTextPrimary(),
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: 'Type a topic or paste your material…',
              hintStyle: GoogleFonts.outfit(
                color: _getTextTertiary(),
                fontSize: 15,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            onChanged: (v) {
              if (_errorMessage.isNotEmpty) {
                setState(() => _errorMessage = '');
              }
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: _getBorder())),
            ),
            child: Row(
              children: [
                _buildAttachPopup(),
                const Spacer(),
                GestureDetector(
                  onTap: _generate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Generate',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _buildAttachPopup() {
    final items = [
      {
        'icon': Icons.picture_as_pdf_rounded,
        'label': 'PDF / Doc',
        'type': 'pdf',
        'pro': true
      },
      {
        'icon': Icons.image_outlined,
        'label': 'Image',
        'type': 'image',
        'pro': true
      },
      {
        'icon': Icons.mic_none_rounded,
        'label': 'Audio',
        'type': 'audio',
        'pro': true
      },
      {
        'icon': Icons.link_rounded,
        'label': 'URL',
        'type': 'link',
        'pro': false
      },
    ];

    return PopupMenuButton<String>(
      onSelected: _handleAttachType,
      tooltip: 'Attach',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1E293B),
      offset: const Offset(0, -180),
      itemBuilder: (_) => items.map((opt) {
        return PopupMenuItem<String>(
          value: opt['type'] as String,
          child: Row(
            children: [
              Icon(opt['icon'] as IconData, color: _getPrimary(), size: 18),
              const SizedBox(width: 10),
              Text(
                opt['label'] as String,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              ),
              if (opt['pro'] as bool) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getPrimary().withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('PRO',
                      style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: _getPrimary(),
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _getBorder()),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 16, color: _getTextSecondary()),
            const SizedBox(width: 6),
            Text('Attach',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: _getTextSecondary(),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFileChip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _getPrimary().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file_rounded, size: 14, color: _getPrimary()),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              _fileName ?? '',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: _getPrimary(), fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 7),
          GestureDetector(
            onTap: () => setState(() {
              _fileName = null;
              _fileBytes = null;
              _uploadType = '';
            }),
            child: Icon(Icons.close_rounded, size: 14, color: _getPrimary()),
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
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: _getTextTertiary(),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: topics.asMap().entries.map((e) {
            return GestureDetector(
              onTap: () {
                _inputController.text = e.value;
                _inputFocusNode.requestFocus();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: _getBorder()),
                ),
                child: Text(
                  e.value,
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: _getTextSecondary(),
                      fontWeight: FontWeight.w500),
                ),
              ),
            ).animate(delay: (e.key * 40).ms).fadeIn().scale(
                  begin: const Offset(0.9, 0.9),
                );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAINote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBorder()),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: _getTextTertiary()),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI-generated content — always verify with trusted sources.',
              style: GoogleFonts.outfit(fontSize: 12, color: _getTextTertiary()),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILDING
  // ─────────────────────────────────────────────────────────────
  Widget _buildBuildingCard() {
    return SingleChildScrollView(
      key: const ValueKey('building'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _getCard(),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _getBorder()),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
              ).createShader(b),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 48, color: Colors.white),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.12, 1.12),
                  duration: 1200.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 24),
            Text(
              'Building your study pack…',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _getTextPrimary(),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ..._buildSteps.asMap().entries.map((e) {
              final done = e.key < _buildStepIndex;
              final active = e.key == _buildStepIndex;
              return AnimatedOpacity(
                opacity: active || done ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: done
                              ? const Color(0xFF22C55E)
                              : active
                                  ? _getPrimary()
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: done
                                ? const Color(0xFF22C55E)
                                : active
                                    ? _getPrimary()
                                    : _getBorder(),
                          ),
                        ),
                        child: Icon(
                          done
                              ? Icons.check_rounded
                              : active
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                          size: 14,
                          color: done || active ? Colors.white : _getBorder(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.value,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: done
                                ? const Color(0xFF22C55E)
                                : active
                                    ? _getTextPrimary()
                                    : _getTextTertiary(),
                          ),
                        ),
                      ),
                      if (active)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _getPrimary(),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _cancelToken?.cancel();
                _reset();
              },
              child: Text('Cancel',
                  style: GoogleFonts.outfit(color: _getTextTertiary())),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).scale(
            begin: const Offset(0.96, 0.96),
            end: const Offset(1, 1),
          ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  DONE
  // ─────────────────────────────────────────────────────────────
  Widget _buildDoneCard() {
    return SingleChildScrollView(
      key: const ValueKey('done'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _getCard(),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _getBorder()),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STUDY PACK READY!',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: _getPrimary(),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        _packTitle,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _getTextPrimary(),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Source: $_packSource',
              style: GoogleFonts.outfit(fontSize: 13, color: _getTextTertiary()),
            ),
            const SizedBox(height: 20),
            // Contents
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _getBorder()),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CONTAINS',
                      style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _getTextTertiary(),
                          letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  _packItem(Icons.text_snippet_outlined, 'Summary',
                      const Color(0xFF6366F1)),
                  _packItem(Icons.style_rounded, 'Flashcards',
                      const Color(0xFF8B5CF6)),
                  _packItem(
                      Icons.quiz_outlined, 'Quiz', const Color(0xFF10B981)),
                  _packItem(Icons.description_outlined, 'Exam',
                      const Color(0xFFEC4899)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Progress
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress',
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: _getTextSecondary(),
                            fontWeight: FontWeight.w600)),
                    Text('0%',
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: _getTextTertiary())),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: 0,
                    backgroundColor: _getBorder(),
                    color: _getPrimary(),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // CTAs
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToStudyPack,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Studying'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPrimary(),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w800),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _navigateToStudyPack,
                icon: const Icon(Icons.bookmark_border_rounded),
                label: const Text('Save to Library'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _getPrimary(),
                  side: BorderSide(color: _getPrimary().withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Create another'),
                style: TextButton.styleFrom(
                  foregroundColor: _getTextTertiary(),
                  textStyle: GoogleFonts.outfit(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms).scale(
            begin: const Offset(0.96, 0.96),
            end: const Offset(1, 1),
          ),
    );
  }

  Widget _packItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: _getTextSecondary(),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const Icon(Icons.check_circle_rounded,
              size: 16, color: Color(0xFF22C55E)),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Positioned(
      bottom: 24,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1010),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEF4444)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _errorMessage = ''),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: Color(0xFFEF4444)),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.3, end: 0),
    );
  }
}

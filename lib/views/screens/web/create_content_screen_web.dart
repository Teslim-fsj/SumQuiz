import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';

// ─────────────────────────────────────────────────────────────
//  Chat message model
// ─────────────────────────────────────────────────────────────
enum _WebMsgType { user, thinking, result }

class _WebChatMsg {
  final _WebMsgType type;
  final String? userText;
  final DateTime? sentAt;
  final String? packTitle;
  final String? packSource;
  final String? folderId;

  _WebChatMsg.user(this.userText)
      : type = _WebMsgType.user,
        sentAt = DateTime.now(),
        packTitle = null,
        packSource = null,
        folderId = null;

  _WebChatMsg.thinking()
      : type = _WebMsgType.thinking,
        sentAt = null,
        userText = null,
        packTitle = null,
        packSource = null,
        folderId = null;

  _WebChatMsg.result({
    required this.packTitle,
    required this.packSource,
    required this.folderId,
  })  : type = _WebMsgType.result,
        sentAt = null,
        userText = null;
}

// ─────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────
class CreateContentScreenWeb extends StatefulWidget {
  const CreateContentScreenWeb({super.key});

  @override
  State<CreateContentScreenWeb> createState() =>
      _CreateContentScreenWebState();
}

class _CreateContentScreenWebState extends State<CreateContentScreenWeb>
    with TickerProviderStateMixin {
  // ── Design tokens ─────────────────────────────────────────────
  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _accentColor => Theme.of(context).colorScheme.secondary;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _surfaceRaised => Theme.of(context).cardColor;
  Color get _userBubble => Theme.of(context).colorScheme.primaryContainer;

  // ── Controllers ───────────────────────────────────────────────
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // ── Upload state ──────────────────────────────────────────────
  String? _fileName;
  Uint8List? _fileBytes;
  String? _mimeType;
  String _uploadType = '';

  // ── Chat & generation state ───────────────────────────────────
  final List<_WebChatMsg> _messages = [];
  bool _isBuilding = false;
  String _errorMessage = '';
  CancellationToken? _cancelToken;
  String _selectedDifficulty = 'intermediate';
  int _selectedCount = 15;

  // ── Build step tracking ───────────────────────────────────────
  int _buildStepIndex = 0;
  final List<String> _buildSteps = [
    'Analyzing material…',
    'Creating summary…',
    'Generating quiz questions…',
    'Building flashcards…',
    'Finalizing your study pack…',
  ];

  // ── Result ────────────────────────────────────────────────────
  String _packTitle = '';
  String _packSource = '';

  bool get _isDone => _messages.any((m) => m.type == _WebMsgType.result);

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
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
      'webp': 'image/webp',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'm4a': 'audio/mp4',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  // ─────────────────────────────────────────────────────────────
  //  File attach
  // ─────────────────────────────────────────────────────────────
  Future<void> _handleAttachType(String type) async {
    final user = Provider.of<UserModel?>(context, listen: false);

    if ((type == 'pdf' ||
            type == 'image' ||
            type == 'audio' ||
            type == 'video' ||
            type == 'slides') &&
        user != null &&
        !user.isPro) {
      showDialog(
        context: context,
        builder: (_) => UpgradeDialog(featureName: _typeLabel(type)),
      );
      return;
    }

    if (type == 'link') {
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
  //  Generate
  // ─────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    final raw = _inputController.text.trim();
    if (raw.isEmpty && _fileBytes == null) {
      setState(
          () => _errorMessage = 'Type a topic or attach a file to start.');
      return;
    }
    if (_isBuilding) return;

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      setState(() => _errorMessage = 'You must be signed in.');
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
          featureName:
              action == 'upload' ? 'Lifetime Upload Limit' : 'Daily Limit',
        ),
      );
      return;
    }

    _packTitle = raw.isEmpty ? (_fileName ?? 'Uploaded Content') : raw;
    _packSource = _fileBytes != null
        ? (_fileName ?? 'File')
        : 'Typed / pasted content';

    final userText =
        raw.isNotEmpty ? raw : '📎 Processing: ${_fileName ?? 'file'}';

    setState(() {
      _messages.add(_WebChatMsg.user(userText));
      _messages.add(_WebChatMsg.thinking());
      _isBuilding = true;
      _buildStepIndex = 0;
      _errorMessage = '';
    });
    _scrollToBottom();

    _cancelToken = CancellationToken();
    final cancelToken = _cancelToken!;
    _animateBuildSteps(cancelToken);
    _inputController.clear();
    _inputFocusNode.unfocus();

    try {
      if (_fileBytes != null) {
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
          await usageService.recordAction(user.uid, action);
          await _generateFinalResults(result, user.uid, cancelToken);
        }
      } else if (_uploadType == 'link' ||
          raw.startsWith('http://') ||
          raw.startsWith('https://')) {
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
          await usageService.recordAction(user.uid, action);
          await _generateFinalResults(result, user.uid, cancelToken);
        }
      } else {
        // Capture all services before any await to satisfy use_build_context_synchronously
        final aiService =
            Provider.of<EnhancedAIService>(context, listen: false);
        final localDb =
            Provider.of<LocalDatabaseService>(context, listen: false);
        final extractionService =
            Provider.of<ContentExtractionService>(context, listen: false);
        await usageService.recordAction(user.uid, action);

        if (raw.split(' ').length <= 8 && !raw.contains('\n')) {
          final folderId = await aiService.generateFromTopic(
            topic: raw,
            userId: user.uid,
            localDb: localDb,
            depth: _selectedDifficulty,
            cardCount: _selectedCount,
          );
          if (!cancelToken.isCancelled && mounted) {
            _showResult(folderId);
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
          _isBuilding = false;
          _messages
              .removeWhere((m) => m.type == _WebMsgType.thinking);
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

      if (mounted) setState(() => _buildStepIndex = 3);

      final folderId = await aiService.generateAndStoreOutputs(
        text: result.text,
        title: _packTitle,
        requestedOutputs: ['summary', 'quiz', 'flashcards'],
        userId: userId,
        localDb: localDb,
        difficulty: _selectedDifficulty,
        questionCount: _selectedCount,
        cardCount: _selectedCount,
        onProgress: (message) {
          developer.log('Generation progress: $message',
              name: 'CreateContentScreenWeb');
        },
        cancelToken: cancelToken,
      );

      if (!cancelToken.isCancelled && mounted) {
        _showResult(folderId);
      }
    } catch (e) {
      if (!cancelToken.isCancelled && mounted) {
        setState(() {
          _isBuilding = false;
          _messages
              .removeWhere((m) => m.type == _WebMsgType.thinking);
          _errorMessage = 'Failed to generate study materials: $e';
        });
      }
    }
  }

  void _showResult(String folderId) {
    setState(() {
      _isBuilding = false;
      _messages.removeWhere((m) => m.type == _WebMsgType.thinking);
      _messages.add(_WebChatMsg.result(
        packTitle: _packTitle,
        packSource: _packSource,
        folderId: folderId,
      ));
      _fileName = null;
      _fileBytes = null;
      _uploadType = '';
    });
    _scrollToBottom();
  }

  void _animateBuildSteps(CancellationToken cancelToken) async {
    for (int i = 0; i < _buildSteps.length; i++) {
      if (cancelToken.isCancelled || !mounted) return;
      if (!_isBuilding) return;
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted && _isBuilding) {
        setState(() => _buildStepIndex = i);
      }
    }
  }

  void _navigateToStudyPack(String folderId) {
    if (folderId.isNotEmpty) {
      context.pushNamed('results-view',
          pathParameters: {'folderId': folderId});
    }
  }

  void _reset() {
    _cancelToken?.cancel();
    setState(() {
      _messages.clear();
      _isBuilding = false;
      _buildStepIndex = 0;
      _errorMessage = '';
      _fileName = null;
      _fileBytes = null;
      _mimeType = null;
      _uploadType = '';
      _packTitle = '';
      _packSource = '';
    });
    _inputController.clear();
  }

  // ─────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _buildIdleContent()
                      : _buildChatArea(),
                ),
              ],
            ),
          ),
          if (_errorMessage.isNotEmpty) _buildErrorBanner(),
          _buildBottomInputBar(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Top bar
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = Provider.of<UserModel?>(context);
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(color: colorScheme.primary.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
            ).createShader(b),
            child: Text(
              'SumQuiz',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Create',
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary),
            ),
          ),
          const Spacer(),
          if (_messages.isNotEmpty)
            TextButton.icon(
              onPressed: _reset,
              icon: Icon(Icons.add_rounded,
                  size: 16, color: colorScheme.primary),
              label: Text(
                'New Session',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary),
              ),
            ),
          const SizedBox(width: 12),
          _buildProBadge(user),
        ],
      ),
    );
  }

  Widget _buildProBadge(UserModel? user) {
    if (user?.isPro ?? false) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          border:
              Border.all(color: _primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded,
                color: _primaryColor, size: 14),
            const SizedBox(width: 5),
            Text(
              'PRO',
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: _primaryColor,
                  letterSpacing: 0.8),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => context.push('/settings/subscription'),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _accentColor],
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          'Upgrade to Pro',
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
  //  IDLE state
  // ─────────────────────────────────────────────────────────────
  Widget _buildIdleContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHero()
                  .animate()
                  .fadeIn(duration: 700.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 44),
              _buildSourceRow()
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 500.ms),
              const SizedBox(height: 20),
              _buildSuggestionChips()
                  .animate()
                  .fadeIn(delay: 320.ms, duration: 500.ms),
              const SizedBox(height: 36),
              _buildAINote()
                  .animate()
                  .fadeIn(delay: 440.ms, duration: 500.ms),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Turn anything into a\n',
                style: GoogleFonts.outfit(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                  height: 1.15,
                ),
              ),
              WidgetSpan(
                child: ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                    colors: [_primaryColor, _accentColor],
                  ).createShader(b),
                  child: Text(
                    'study system',
                    style: GoogleFonts.outfit(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Type a topic, paste notes, or upload files — AI generates\na complete study pack with summary, quiz and flashcards.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: _textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceRow() {
    final sources = [
      (Icons.picture_as_pdf_rounded, 'PDF', 'pdf'),
      (Icons.description_outlined, 'Notes', 'image'),
      (Icons.link_rounded, 'Link', 'link'),
      (Icons.mic_none_rounded, 'Audio', 'audio'),
      (Icons.videocam_outlined, 'Video', 'video'),
    ];
    return Column(
      children: [
        Text(
          'ADD SOURCE',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: _textSecondary.withValues(alpha: 0.5),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: sources
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _buildSourceButton(s.$1, s.$2, s.$3),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSourceButton(IconData icon, String label, String type) {
    return GestureDetector(
      onTap: () => _handleAttachType(type),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primaryColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _primaryColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final chips = [
      'Generate exam',
      'Create flashcards',
      'Summarize notes',
      'Explain simply',
      'Mind map',
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (label) => GestureDetector(
              onTap: () {
                _inputController.text = label;
                _inputFocusNode.requestFocus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: _primaryColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAINote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: _primaryColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 15,
              color: _textSecondary.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Text(
            'AI-generated — always verify with trusted sources.',
            style: GoogleFonts.outfit(
                fontSize: 12,
                color: _textSecondary.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Chat area
  // ─────────────────────────────────────────────────────────────
  Widget _buildChatArea() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.builder(
          controller: _scrollController,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final msg = _messages[index];
            switch (msg.type) {
              case _WebMsgType.user:
                return _buildUserBubble(msg);
              case _WebMsgType.thinking:
                return _buildAIThinkingBubble();
              case _WebMsgType.result:
                return _buildAIResultCard(msg);
            }
          },
        ),
      ),
    );
  }

  Widget _buildUserBubble(_WebChatMsg msg) {
    final hour = msg.sentAt?.hour.toString().padLeft(2, '0') ?? '';
    final min = msg.sentAt?.minute.toString().padLeft(2, '0') ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _userBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                  color: _primaryColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              msg.userText ?? '',
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: _textPrimary,
                height: 1.5,
              ),
            ),
          ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.06, end: 0),
          const SizedBox(height: 5),
          Text(
            'Sent $hour:$min',
            style: GoogleFonts.outfit(
                fontSize: 11,
                color: _textSecondary.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildAIThinkingBubble() {
    final step = _buildStepIndex < _buildSteps.length
        ? _buildSteps[_buildStepIndex]
        : 'Finalizing…';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIAvatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                    colors: [_accentColor, _primaryColor],
                  ).createShader(b),
                  child: Text(
                    step,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      duration: 1800.ms,
                      color: _accentColor.withValues(alpha: 0.35),
                    ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:
                        (_buildStepIndex + 1) / _buildSteps.length,
                    minHeight: 3,
                    backgroundColor: _surfaceRaised,
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    _cancelToken?.cancel();
                    setState(() {
                      _isBuilding = false;
                      _messages.removeWhere(
                          (m) => m.type == _WebMsgType.thinking);
                    });
                  },
                  child: Text(
                    'Cancel generation',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: _textSecondary.withValues(alpha: 0.5),
                      decoration: TextDecoration.underline,
                      decorationColor:
                          _textSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildAIResultCard(_WebChatMsg msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIAvatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(
                    color: _primaryColor.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'GENERATED CONTENT',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _primaryColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '📚 ${msg.packTitle ?? ''}',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  // Content badges
                  Row(
                    children: [
                      _contentBadge('📄', 'Summary'),
                      const SizedBox(width: 8),
                      _contentBadge('❓', 'Quiz'),
                      const SizedBox(width: 8),
                      _contentBadge('🗂️', 'Flashcards'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 13, color: _textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Based on ${msg.packSource ?? ''}',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: _textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // CTA row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 46,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _primaryColor,
                                  Color(0xFF9333EA)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _navigateToStudyPack(
                                  msg.folderId ?? ''),
                              icon: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18),
                              label: Text(
                                'Start Studying',
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: () => context.go('/library'),
                            icon: Icon(
                                Icons.bookmark_border_rounded,
                                size: 16),
                            label: Text(
                              'Save to Library',
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primaryColor,
                              side: BorderSide(
                                  color: _primaryColor
                                      .withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFollowUpChips(),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.07, end: 0);
  }

  Widget _buildFollowUpChips() {
    final chips = ['Make it harder', 'Add more flashcards', 'Simplify'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (label) => GestureDetector(
              onTap: () {
                _inputController.text = label;
                _inputFocusNode.requestFocus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: _accentColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accentColor,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _contentBadge(String emoji, String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.auto_awesome_rounded,
          color: Colors.white, size: 18),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Bottom input bar
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border(
          top: BorderSide(color: _primaryColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Source type row
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _sourceChip(Icons.picture_as_pdf_rounded, 'PDF',
                          'pdf'),
                      _sourceChip(Icons.description_outlined, 'Notes',
                          'image'),
                      _sourceChip(Icons.link_rounded, 'Link', 'link'),
                      _sourceChip(
                          Icons.mic_none_rounded, 'Audio', 'audio'),
                      _sourceChip(
                          Icons.videocam_outlined, 'Video', 'video'),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 20, color: _primaryColor.withValues(alpha: 0.2)),
                      const SizedBox(width: 12),
                      _difficultyChip('Beginner', 'beginner'),
                      _difficultyChip('Intermediate', 'intermediate'),
                      _difficultyChip('Advanced', 'advanced'),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 20, color: _primaryColor.withValues(alpha: 0.2)),
                      const SizedBox(width: 12),
                      _countChip(10),
                      _countChip(15),
                      _countChip(20),
                      _countChip(30),
                    ],
                  ),
                ),
              ),
              if (_fileName != null) _buildAttachedFileChip(),
              // Main input row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _surfaceRaised,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color:
                                  _primaryColor.withValues(alpha: 0.15)),
                        ),
                        child: TextField(
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          maxLines: 5,
                          minLines: 1,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: _textPrimary,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: _isDone
                                ? 'Ask a follow-up question…'
                                : 'Type a topic, paste notes, or add a link…',
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 14,
                              color: _textSecondary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _generate(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Send button
                    GestureDetector(
                      onTap: _isBuilding ? null : _generate,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: _isBuilding
                              ? null
                              : LinearGradient(
                                  colors: [_primaryColor, _accentColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: _isBuilding ? _surfaceRaised : null,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isBuilding
                              ? Icons.hourglass_bottom_rounded
                              : Icons.arrow_upward_rounded,
                          color: _isBuilding
                              ? _textSecondary
                              : Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceChip(IconData icon, String label, String type) {
    final isActive = _uploadType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _handleAttachType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? _primaryColor.withValues(alpha: 0.18)
                : _surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? _primaryColor.withValues(alpha: 0.5)
                  : _primaryColor.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: isActive ? _primaryColor : _textSecondary,
                  size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? _primaryColor : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachedFileChip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _primaryColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.attach_file_rounded,
                  size: 13, color: _primaryColor),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  _fileName ?? '',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: _primaryColor,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() {
                  _fileName = null;
                  _fileBytes = null;
                  _uploadType = '';
                }),
                child: Icon(Icons.close_rounded,
                    size: 13, color: _primaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _difficultyChip(String label, String value) {
    final isActive = _selectedDifficulty == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedDifficulty = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? _accentColor.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? _accentColor.withValues(alpha: 0.5) : _textSecondary.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? _accentColor : _textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _countChip(int count) {
    final isActive = _selectedCount == count;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCount = count),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? _primaryColor.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? _primaryColor.withValues(alpha: 0.5) : _textSecondary.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? _primaryColor : _textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Error banner
  // ─────────────────────────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.red, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage,
                  style:
                      GoogleFonts.outfit(fontSize: 13, color: Colors.red),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _errorMessage = ''),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
  }
}

import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// ─────────────────────────────────────────────────────────────
//  Input validator
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
//  Chat message model
// ─────────────────────────────────────────────────────────────
enum _MsgType { user, thinking, result }

class _ChatMsg {
  final _MsgType type;
  final String? userText;
  final DateTime? sentAt;
  final String? packTitle;
  final String? packSource;
  final String? folderId;

  _ChatMsg.user(this.userText)
      : type = _MsgType.user,
        sentAt = DateTime.now(),
        packTitle = null,
        packSource = null,
        folderId = null;

  _ChatMsg.thinking()
      : type = _MsgType.thinking,
        sentAt = null,
        userText = null,
        packTitle = null,
        packSource = null,
        folderId = null;

  _ChatMsg.result({
    required this.packTitle,
    required this.packSource,
    required this.folderId,
  })  : type = _MsgType.result,
        sentAt = null,
        userText = null;
}

// ─────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────
class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen>
    with TickerProviderStateMixin {
  // ── Design tokens ─────────────────────────────────────────────
  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _accentColor => Theme.of(context).colorScheme.secondary;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

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
  final List<_ChatMsg> _messages = [];
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

  bool get _isDone => _messages.any((m) => m.type == _MsgType.result);

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
    if (_isBuilding) return;

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
          featureName:
              action == 'upload' ? 'Lifetime Upload Limit' : 'Daily Limit',
        ),
      );
      return;
    }

    _packTitle = raw.isEmpty ? (_fileName ?? 'Uploaded Content') : raw;
    _packSource = _fileBytes != null ? (_fileName ?? 'File') : 'Typed content';

    final userText =
        raw.isNotEmpty ? raw : '📎 Processing: ${_fileName ?? 'file'}';

    setState(() {
      _messages.add(_ChatMsg.user(userText));
      _messages.add(_ChatMsg.thinking());
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
          raw.startsWith('http://') ||
          raw.startsWith('https://')) {
        final extractionService =
            Provider.of<ContentExtractionService>(context, listen: false);
        final type = InputValidator.isYoutubeUrl(raw) ? 'link' : 'link';
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
          _messages.removeWhere((m) => m.type == _MsgType.thinking);
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
              name: 'CreateContentScreen');
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
          _messages.removeWhere((m) => m.type == _MsgType.thinking);
          _errorMessage = 'Failed to generate study materials: $e';
        });
      }
    }
  }

  void _showResult(String folderId) {
    setState(() {
      _isBuilding = false;
      _messages.removeWhere((m) => m.type == _MsgType.thinking);
      _messages.add(_ChatMsg.result(
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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _messages.isEmpty
                  ? _buildIdleContent()
                  : _buildChatList(),
            ),
            if (_errorMessage.isNotEmpty) _buildErrorBanner(),
            _buildBottomInputBar(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  App bar
  // ─────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = Provider.of<UserModel?>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: colorScheme.onSurfaceVariant, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
            ).createShader(b),
            child: Text(
              'SumQuiz',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          if (_messages.isNotEmpty)
            GestureDetector(
              onTap: _reset,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        color: colorScheme.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'New',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildProBadge(user),
        ],
      ),
    );
  }

  Widget _buildProBadge(UserModel? user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (user?.isPro ?? false) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded,
                color: colorScheme.primary, size: 14),
            const SizedBox(width: 5),
            Text(
              'PRO',
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                  letterSpacing: 0.8),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => context.push('/settings/subscription'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.secondary],
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
  //  IDLE state
  // ─────────────────────────────────────────────────────────────
  Widget _buildIdleContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          _buildHero().animate().fadeIn(duration: 600.ms).slideY(
                begin: 0.06,
                end: 0,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 36),
          _buildSourceGrid()
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms),
          const SizedBox(height: 20),
          _buildSuggestionChips()
              .animate()
              .fadeIn(delay: 320.ms, duration: 500.ms),
          const SizedBox(height: 32),
          _buildAINote().animate().fadeIn(delay: 440.ms, duration: 500.ms),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Turn anything\ninto a ',
                style: GoogleFonts.outfit(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                  height: 1.2,
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
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Type a topic, paste notes, or upload files — AI does the rest.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: _textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceGrid() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sources = [
      (Icons.picture_as_pdf_rounded, 'PDF', 'pdf'),
      (Icons.description_outlined, 'Notes', 'image'),
      (Icons.link_rounded, 'Link', 'link'),
      (Icons.mic_none_rounded, 'Audio', 'audio'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADD SOURCE',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 3.4,
          children: sources
              .map((s) => _buildSourceButton(s.$1, s.$2, s.$3))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSourceButton(IconData icon, String label, String type) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: () => _handleAttachType(type),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chips = [
      'Generate exam',
      'Create flashcards',
      'Summarize notes',
      'Explain simply',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .map(
              (label) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    _inputController.text = label;
                    _inputFocusNode.requestFocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildAINote() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI-generated content — always verify with trusted sources.',
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Chat list
  // ─────────────────────────────────────────────────────────────
  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        switch (msg.type) {
          case _MsgType.user:
            return _buildUserBubble(msg);
          case _MsgType.thinking:
            return _buildAIThinkingBubble();
          case _MsgType.result:
            return _buildAIResultCard(msg);
        }
      },
    );
  }

  Widget _buildUserBubble(_ChatMsg msg) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hour = msg.sentAt?.hour.toString().padLeft(2, '0') ?? '';
    final min = msg.sentAt?.minute.toString().padLeft(2, '0') ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border:
                  Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              msg.userText ?? '',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: colorScheme.onPrimaryContainer,
                height: 1.5,
              ),
            ),
          ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.08, end: 0),
          const SizedBox(height: 4),
          Text(
            'Sent $hour:$min',
            style: GoogleFonts.outfit(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildAIThinkingBubble() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final step = _buildStepIndex < _buildSteps.length
        ? _buildSteps[_buildStepIndex]
        : 'Finalizing…';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIAvatar(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                    colors: [colorScheme.secondary, colorScheme.primary],
                  ).createShader(b),
                  child: Text(
                    step,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      duration: 1800.ms,
                      color: colorScheme.secondary.withValues(alpha: 0.35),
                    ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_buildStepIndex + 1) / _buildSteps.length,
                    minHeight: 3,
                    backgroundColor: theme.cardColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    _cancelToken?.cancel();
                    setState(() {
                      _isBuilding = false;
                      _messages.removeWhere(
                          (m) => m.type == _MsgType.thinking);
                    });
                  },
                  child: Text(
                    'Cancel generation',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      decoration: TextDecoration.underline,
                      decorationColor:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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

  Widget _buildAIResultCard(_ChatMsg msg) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIAvatar(),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'GENERATED CONTENT',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '📚 ${msg.packTitle ?? ''}',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _contentBadge('📄', 'Summary'),
                      _contentBadge('❓', 'Quiz'),
                      _contentBadge('🗂️', 'Flashcards'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 11, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Based on ${msg.packSource ?? ''}',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Start Studying CTA
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _navigateToStudyPack(msg.folderId ?? ''),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(
                          'Start Studying',
                          style: GoogleFonts.outfit(
                               fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Save to Library CTA
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/library'),
                      icon: const Icon(Icons.bookmark_border_rounded,
                          size: 16),
                      label: Text(
                        'Save to Library',
                        style: GoogleFonts.outfit(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        side: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFollowUpChips(),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _buildFollowUpChips() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chips = ['Make harder', 'Add more cards', 'Simplify'];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips
          .map(
            (label) => GestureDetector(
              onTap: () {
                _inputController.text = label;
                _inputFocusNode.requestFocus();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(100),
                  border:
                      Border.all(color: colorScheme.secondary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.secondary,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _contentBadge(String emoji, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAvatar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.auto_awesome_rounded,
          color: Colors.white, size: 15),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Bottom input bar
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomInputBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(color: colorScheme.primary.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Difficulty and Count row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                _difficultyChip('Beginner', 'beginner'),
                _difficultyChip('Intermediate', 'intermediate'),
                _difficultyChip('Advanced', 'advanced'),
                const SizedBox(width: 8),
                Container(width: 1, height: 16, color: colorScheme.primary.withValues(alpha: 0.2)),
                const SizedBox(width: 8),
                _countChip(10),
                _countChip(15),
                _countChip(20),
                _countChip(30),
              ],
            ),
          ),
          if (_fileName != null) _buildAttachedFileChip(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _showSourcePicker,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Icon(Icons.attach_file_rounded,
                        color: colorScheme.onSurfaceVariant, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.15)),
                    ),
                    child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      maxLines: 4,
                      minLines: 1,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: _isDone
                            ? 'Ask a follow-up question…'
                            : 'Type a topic, paste notes…',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _generate(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isBuilding ? null : _generate,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: _isBuilding
                          ? null
                          : LinearGradient(
                              colors: [colorScheme.primary, colorScheme.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _isBuilding ? theme.cardColor : null,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isBuilding
                          ? Icons.hourglass_bottom_rounded
                          : Icons.arrow_upward_rounded,
                      color:
                          _isBuilding ? colorScheme.onSurfaceVariant : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachedFileChip() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file_rounded,
                size: 13, color: colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _fileName ?? '',
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: colorScheme.primary,
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
                  size: 13, color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _difficultyChip(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = _selectedDifficulty == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedDifficulty = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? colorScheme.secondary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? colorScheme.secondary.withValues(alpha: 0.5) : colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? colorScheme.secondary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _countChip(int count) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = _selectedCount == count;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCount = count),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? colorScheme.primary.withValues(alpha: 0.5) : colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  void _showSourcePicker() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add Source',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 3.0,
              children: [
                _sheetTile(Icons.picture_as_pdf_rounded, 'PDF / Doc',
                    'pdf', ctx),
                _sheetTile(
                    Icons.image_outlined, 'Image / Notes', 'image', ctx),
                _sheetTile(Icons.link_rounded, 'Web Link', 'link', ctx),
                _sheetTile(
                    Icons.mic_none_rounded, 'Audio', 'audio', ctx),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile(
      IconData icon, String label, String type, BuildContext ctx) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        _handleAttachType(type);
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: colorScheme.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Error banner
  // ─────────────────────────────────────────────────────────────
  Widget _buildErrorBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: colorScheme.error, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage,
              style: GoogleFonts.outfit(fontSize: 12, color: colorScheme.error),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = ''),
            child:
                Icon(Icons.close_rounded, size: 14, color: colorScheme.error),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
  }
}

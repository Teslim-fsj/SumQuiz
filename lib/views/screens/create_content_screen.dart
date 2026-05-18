import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/user_model.dart';
import '../../utils/youtube_pro_gate.dart';
import '../../providers/create_content_provider.dart';
import '../widgets/create_content/source_choice_card.dart';
import '../widgets/create_content/config_selector.dart';
import '../widgets/create_content/creation_progress_indicator.dart';
import '../widgets/create_content/creation_success_view.dart';
import '../widgets/create_content/extraction_review_view.dart';
import '../widgets/upgrade_dialog.dart';
import '../../widgets/sumi_mascot.dart';
import '../../models/sumi_emotion.dart';

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final folderId =
          GoRouterState.of(context).uri.queryParameters['folderId'];
      if (folderId != null) {
        Provider.of<CreateContentProvider>(context, listen: false)
            .setPreSelectedFolderId(folderId);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CreateContentProvider>(context);
    final user = Provider.of<UserModel?>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context, provider),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _buildPhaseContent(context, provider, user),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, CreateContentProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, size: 22),
        onPressed: () {
          provider.reset();
          context.pop();
        },
      ),
      title: Text(
        'Synthesis Lab',
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
      ),
      actions: [
        if (provider.phase != CreationPhase.source)
          TextButton(
            onPressed: provider.reset,
            child: Text(
              'Reset',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhaseContent(
      BuildContext context, CreateContentProvider provider, UserModel? user) {
    switch (provider.phase) {
      case CreationPhase.source:
        return _buildSourceSelection(context, provider, user);
      case CreationPhase.extractionReview:
        return const ExtractionReviewView();
      case CreationPhase.config:
        return _buildConfiguration(context, provider);
      case CreationPhase.processing:
        return CreationProgressIndicator(
          message: provider.progressMessage,
          tip: provider.currentTip,
        );
      case CreationPhase.success:
        return CreationSuccessView(
          title: provider.fileName ??
              (provider.textContent.length > 20
                  ? '${provider.textContent.substring(0, 20)}...'
                  : provider.textContent),
          onViewPack: () {
            context.pushNamed('results-view',
                pathParameters: {'folderId': provider.generatedFolderId});
            provider.reset();
          },
          onReset: provider.reset,
        );
      case CreationPhase.error:
        return _buildErrorView(context, provider);
    }
  }

  Widget _buildSourceSelection(
      BuildContext context, CreateContentProvider provider, UserModel? user) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Convert Chaos into Insight',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.displayLarge?.color,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          const SizedBox(height: 12),
          Text(
            'Choose a source to begin your deep-dive.',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: theme.hintColor,
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 40),

          _buildSectionHeader('Smart Tools', Icons.bolt_rounded),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
            children: [
              SourceChoiceCard(
                title: 'New Workspace',
                description: 'Blank note environment',
                icon: Icons.edit_note_rounded,
                onTap: () => context.push('/notes/new'),
                color: const Color(0xFF8B5CF6),
                isNew: true,
              ),
              SourceChoiceCard(
                title: 'Capture Lecture',
                description: 'Real-time transcription',
                icon: Icons.record_voice_over_rounded,
                onTap: () {
                  context.push('/notes/new?startRecording=true');
                },
                color: const Color(0xFFEC4899),
                isPro: true,
              ),
            ],
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 40),

          _buildSectionHeader('AI Extraction Hub', Icons.auto_awesome_rounded),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
            children: [
              SourceChoiceCard(
                title: 'Concept / Text',
                description: 'Paste your raw research',
                icon: Icons.text_fields_rounded,
                onTap: () => _showTextInputDialog(context, provider),
                color: const Color(0xFF3B82F6),
              ),
              SourceChoiceCard(
                title: 'PDF Library',
                description: 'Analyze local documents',
                icon: Icons.picture_as_pdf_rounded,
                onTap: () => _pickFile(context, provider, user,
                    ['pdf', 'doc', 'docx', 'txt'], 'pdf'),
                color: const Color(0xFFEF4444),
              ),
              SourceChoiceCard(
                title: 'Web Intel',
                description: 'Import from any URL',
                icon: Icons.link_rounded,
                onTap: () => _showUrlInputDialog(context, provider),
                color: const Color(0xFF10B981),
              ),
              SourceChoiceCard(
                title: 'Video Sync',
                description: 'YouTube video analysis',
                icon: Icons.play_circle_fill_rounded,
                onTap: () {
                  if (!userMayImportFromYouTube(user)) {
                    showDialog<void>(
                        context: context,
                        builder: (_) => const UpgradeDialog(
                            featureName: 'YouTube import'));
                    return;
                  }
                  _showUrlInputDialog(context, provider, isYoutube: true);
                },
                color: const Color(0xFFF59E0B),
                isPro: true,
              ),
              SourceChoiceCard(
                title: 'Scan Notes',
                description: 'OCR from your images',
                icon: Icons.camera_alt_rounded,
                onTap: () => _pickFile(context, provider, user,
                    ['jpg', 'jpeg', 'png', 'webp'], 'image'),
                color: const Color(0xFF6366F1),
                isPro: true,
              ),
              SourceChoiceCard(
                title: 'Audio Brief',
                description: 'Transcribe recordings',
                icon: Icons.audio_file_rounded,
                onTap: () => _pickFile(context, provider, user,
                    ['mp3', 'wav', 'm4a', 'aac'], 'audio'),
                color: const Color(0xFF22C55E),
                isPro: true,
              ),
            ],
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile(BuildContext context, CreateContentProvider provider,
      UserModel? user, List<String> extensions, String type) async {
    if (user != null && !user.isPro && user.computeUnits <= 0) {
      showDialog(
          context: context,
          builder: (_) => const UpgradeDialog(featureName: 'Neural Uploads'));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      provider.setSource(
        type,
        fileName: file.name,
        bytes: file.bytes,
        mime: _getMimeType(file.name),
      );
    }
  }

  void _showTextInputDialog(
      BuildContext context, CreateContentProvider provider) {
    _textController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          top: 32,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Input Source Knowledge',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _textController,
                maxLines: 10,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Paste your topic, notes, or raw data here...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final text = _textController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context);
                  final isTopic = text.split(' ').length <= 8;
                  provider.setSource(isTopic ? 'topic' : 'text', text: text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Next Step', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUrlInputDialog(BuildContext context, CreateContentProvider provider,
      {bool isYoutube = false}) {
    _textController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          top: 32,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isYoutube ? 'Synchronize YouTube Video' : 'Import Web Document',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _textController,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  hintText: isYoutube
                      ? 'https://youtube.com/watch?v=...'
                      : 'https://example.com/article',
                  hintStyle: GoogleFonts.inter(color: Colors.grey.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                  prefixIcon: Icon(isYoutube
                      ? Icons.play_circle_outline_rounded
                      : Icons.link_rounded, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final url = _textController.text.trim();
                if (url.isNotEmpty && url.startsWith('http')) {
                  final u = Provider.of<UserModel?>(context, listen: false);
                  final lower = url.toLowerCase();
                  final looksYt = lower.contains('youtube.com/') ||
                      lower.contains('youtu.be/') ||
                      lower.contains('m.youtube.com/');
                  if (looksYt && !userMayImportFromYouTube(u)) {
                    showDialog<void>(
                      context: context,
                      builder: (_) =>
                          const UpgradeDialog(featureName: 'YouTube import'),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  provider.setSource('link', text: url);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Initialize Sync', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  String _getMimeType(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt': 'text/plain',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'm4a': 'audio/mp4',
      'aac': 'audio/aac',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  Widget _buildConfiguration(
      BuildContext context, CreateContentProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSourcePreview(context, provider),
          const SizedBox(height: 32),
          ConfigSelector(
            selectedDifficulty: provider.selectedDifficulty,
            selectedQuizCount: provider.quizCount,
            selectedFlashcardCount: provider.flashcardCount,
            selectedQuestionTypes: provider.selectedQuestionTypes,
            selectedArchetype: provider.selectedArchetype,
            onDifficultyChanged: (v) => provider.updateConfig(difficulty: v),
            onQuizCountChanged: (v) => provider.updateConfig(quizCount: v),
            onFlashcardCountChanged: (v) =>
                provider.updateConfig(flashcardCount: v),
            onToggleType: (v) => provider.toggleQuestionType(v),
            onArchetypeChanged: (v) => provider.updateConfig(archetype: v),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () {
              final user = Provider.of<UserModel?>(context, listen: false);
              if (user != null) {
                provider.startGeneration(
                  user.uid,
                  allowYouTubeImport: userMayImportFromYouTube(user),
                  allowPdfImport: userMayImportFromPdf(user),
                  allowWebImport: userMayImportFromWeb(user),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              shadowColor: colorScheme.primary.withOpacity(0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Launch AI Synthesis',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 16),
          TextButton(
            onPressed: provider.backToSource,
            child: Text(
              'Change Data Source',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePreview(
      BuildContext context, CreateContentProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    IconData icon;
    String label;
    String detail;

    switch (provider.selectedSourceType) {
      case 'pdf':
        icon = Icons.picture_as_pdf_rounded;
        label = 'Document Locked';
        detail = provider.fileName ?? 'Unknown file';
        break;
      case 'image':
        icon = Icons.camera_alt_rounded;
        label = 'Image Captured';
        detail = provider.fileName ?? 'Unknown image';
        break;
      case 'audio':
        icon = Icons.mic_rounded;
        label = 'Audio Initialized';
        detail = provider.fileName ?? 'Unknown recording';
        break;
      case 'link':
        icon = Icons.link_rounded;
        label = 'URL Connected';
        detail = provider.textContent;
        break;
      case 'topic':
        icon = Icons.lightbulb_rounded;
        label = 'Core Concept';
        detail = provider.textContent;
        break;
      default:
        icon = Icons.text_snippet_rounded;
        label = 'Data Stream';
        detail = 'Custom notes provided';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.displayLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, CreateContentProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;

    String displayMessage = provider.errorMessage;
    String displayTitle = 'Synthesis Error';

    if (provider.errorMessage.contains('USAGE_LIMIT_REACHED') || 
        provider.errorMessage.contains('CAPACITY_STABILIZING')) {
      displayTitle = 'Neural Capacity Full';
      displayMessage =
          "Your neural momentum is currently stabilizing! Sumi suggests a quick break while your learning circuits reset. Upgrade for more capacity!";
    } else if (provider.errorMessage.contains('API key is not configured')) {
      displayMessage =
          "Synthesis engine is offline for maintenance. Please wait.";
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SumiMascot(state: SumiState.confused, size: 120),
          const SizedBox(height: 32),
          Text(
            displayTitle,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Theme.of(context).hintColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          if (!provider.errorMessage.contains('USAGE_LIMIT_REACHED'))
            ElevatedButton(
              onPressed: provider.backToConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Retry Synthesis', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            )
          else
            ElevatedButton(
              onPressed: () => context.push('/settings/subscription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Unlock Pro', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: provider.reset,
            child: Text('Reset Selection', style: GoogleFonts.inter(color: Theme.of(context).hintColor)),
          ),
        ],
      ),
    );
  }
}

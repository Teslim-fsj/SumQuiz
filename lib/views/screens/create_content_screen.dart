import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/user_model.dart';
import '../../providers/create_content_provider.dart';
import '../widgets/create_content/source_choice_card.dart';
import '../widgets/create_content/config_selector.dart';
import '../widgets/create_content/creation_progress_indicator.dart';
import '../widgets/create_content/creation_success_view.dart';
import '../widgets/upgrade_dialog.dart';

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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

  PreferredSizeWidget _buildAppBar(BuildContext context, CreateContentProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () {
          if (provider.phase == CreationPhase.processing) {
             // Show cancel confirmation if needed
          }
          provider.reset();
          context.pop();
        },
      ),
      title: ShaderMask(
        shaderCallback: (b) => LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
        ).createShader(b),
        child: Text(
          'SumQuiz AI',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
      centerTitle: true,
      actions: [
        if (provider.phase != CreationPhase.source)
          TextButton(
            onPressed: provider.reset,
            child: Text(
              'Reset',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhaseContent(BuildContext context, CreateContentProvider provider, UserModel? user) {
    switch (provider.phase) {
      case CreationPhase.source:
        return _buildSourceSelection(context, provider, user);
      case CreationPhase.config:
        return _buildConfiguration(context, provider);
      case CreationPhase.processing:
        return CreationProgressIndicator(message: provider.progressMessage);
      case CreationPhase.success:
        return CreationSuccessView(
          title: provider.fileName ?? (provider.textContent.length > 20 ? '${provider.textContent.substring(0, 20)}...' : provider.textContent),
          onViewPack: () {
            context.pushNamed('results-view', pathParameters: {'folderId': provider.generatedFolderId});
            provider.reset();
          },
          onReset: provider.reset,
        );
      case CreationPhase.error:
        return _buildErrorView(context, provider);
    }
  }

  // --- PHASE 1: SOURCE SELECTION ---
  Widget _buildSourceSelection(BuildContext context, CreateContentProvider provider, UserModel? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What would you\nlike to study?',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.1,
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 12),
          Text(
            'Choose a source and our AI will generate your personalized study materials.',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 40),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
            children: [
              SourceChoiceCard(
                title: 'Text/Topic',
                description: 'Paste notes or type a subject',
                icon: Icons.text_fields_rounded,
                onTap: () => _showTextInputDialog(context, provider),
                color: Colors.blue,
              ),
              SourceChoiceCard(
                title: 'PDF/Docs',
                description: 'Upload your documents',
                icon: Icons.picture_as_pdf_rounded,
                onTap: () => _pickFile(context, provider, user, ['pdf', 'doc', 'docx', 'txt'], 'pdf'),
                color: Colors.redAccent,
              ),
              SourceChoiceCard(
                title: 'Web Link',
                description: 'Import from any URL',
                icon: Icons.link_rounded,
                onTap: () => _showUrlInputDialog(context, provider),
                color: Colors.teal,
              ),
              SourceChoiceCard(
                title: 'YouTube',
                description: 'Analyze video content',
                icon: Icons.play_circle_fill_rounded,
                onTap: () => _showUrlInputDialog(context, provider, isYoutube: true),
                color: Colors.orange,
              ),
              SourceChoiceCard(
                title: 'Images',
                description: 'Scan notes and photos',
                icon: Icons.camera_alt_rounded,
                onTap: () => _pickFile(context, provider, user, ['jpg', 'jpeg', 'png', 'webp'], 'image'),
                color: Colors.deepPurple,
              ),
              SourceChoiceCard(
                title: 'Audio',
                description: 'Transcribe recordings',
                icon: Icons.mic_rounded,
                onTap: () => _pickFile(context, provider, user, ['mp3', 'wav', 'm4a', 'aac'], 'audio'),
                color: Colors.green,
              ),
            ],
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  Future<void> _pickFile(BuildContext context, CreateContentProvider provider, UserModel? user, List<String> extensions, String type) async {
    if (user != null && !user.isPro && type != 'pdf') {
       showDialog(context: context, builder: (_) => UpgradeDialog(featureName: '$type Uploads'));
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

  void _showTextInputDialog(BuildContext context, CreateContentProvider provider) {
    _textController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 24,
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
              'Enter Topic or Notes',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 8,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Type your topic here (e.g. Photosynthesis) or paste your long notes...',
                hintStyle: GoogleFonts.outfit(color: Colors.grey),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Next'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showUrlInputDialog(BuildContext context, CreateContentProvider provider, {bool isYoutube = false}) {
    _textController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 24,
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
              isYoutube ? 'Enter YouTube Link' : 'Enter Web Link',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: isYoutube ? 'https://youtube.com/watch?v=...' : 'https://example.com/article',
                hintStyle: GoogleFonts.outfit(color: Colors.grey),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(isYoutube ? Icons.play_circle_outline_rounded : Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final url = _textController.text.trim();
                if (url.isNotEmpty && url.startsWith('http')) {
                  Navigator.pop(context);
                  provider.setSource('link', text: url);
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Next'),
            ),
            const SizedBox(height: 32),
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
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
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

  // --- PHASE 2: CONFIGURATION ---
  Widget _buildConfiguration(BuildContext context, CreateContentProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSourcePreview(context, provider),
          const SizedBox(height: 32),
          ConfigSelector(
            selectedDifficulty: provider.selectedDifficulty,
            selectedCount: provider.quizCount,
            selectedQuestionTypes: provider.selectedQuestionTypes,
            onDifficultyChanged: (v) => provider.updateConfig(difficulty: v),
            onCountChanged: (v) => provider.updateConfig(quizCount: v, flashcardCount: v),
            onToggleType: (v) => provider.toggleQuestionType(v),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () {
              final user = Provider.of<UserModel?>(context, listen: false);
              if (user != null) {
                provider.startGeneration(user.uid);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
              shadowColor: colorScheme.primary.withValues(alpha: 0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Generate Study Pack',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 12),
          TextButton(
            onPressed: provider.backToSource,
            child: Text(
              'Change Source',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePreview(BuildContext context, CreateContentProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    IconData icon;
    String label;
    String detail;

    switch (provider.selectedSourceType) {
      case 'pdf':
        icon = Icons.picture_as_pdf_rounded;
        label = 'Document picked';
        detail = provider.fileName ?? 'Unknown file';
        break;
      case 'image':
        icon = Icons.camera_alt_rounded;
        label = 'Image picked';
        detail = provider.fileName ?? 'Unknown image';
        break;
      case 'audio':
        icon = Icons.mic_rounded;
        label = 'Audio picked';
        detail = provider.fileName ?? 'Unknown recording';
        break;
      case 'link':
        icon = Icons.link_rounded;
        label = 'Link entered';
        detail = provider.textContent;
        break;
      case 'topic':
        icon = Icons.lightbulb_rounded;
        label = 'Topic entered';
        detail = provider.textContent;
        break;
      default:
        icon = Icons.text_snippet_rounded;
        label = 'Custom text';
        detail = 'Notes and content provided';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PHASE: ERROR ---
  Widget _buildErrorView(BuildContext context, CreateContentProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 64),
          ),
          const SizedBox(height: 32),
          Text(
            'Something went wrong',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            provider.errorMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: provider.backToConfig,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.onSurface,
              foregroundColor: colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: provider.reset,
            child: const Text('Change Source'),
          ),
        ],
      ),
    );
  }
}

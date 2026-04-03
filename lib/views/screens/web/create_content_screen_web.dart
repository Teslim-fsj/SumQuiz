import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/user_model.dart';
import '../../../providers/create_content_provider.dart';
import '../../widgets/create_content/config_selector.dart';
import '../../widgets/create_content/creation_progress_indicator.dart';
import '../../widgets/create_content/creation_success_view.dart';
import '../../widgets/upgrade_dialog.dart';

class CreateContentScreenWeb extends StatefulWidget {
  const CreateContentScreenWeb({super.key});

  @override
  State<CreateContentScreenWeb> createState() => _CreateContentScreenWebState();
}

class _CreateContentScreenWebState extends State<CreateContentScreenWeb> {
  final _textController = TextEditingController();

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
      body: Column(
        children: [
          _buildWebHeader(context, provider),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _buildPhaseContent(context, provider, user),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebHeader(BuildContext context, CreateContentProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
            ).createShader(b),
            child: Text(
              'SumQuiz Studio',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          if (provider.phase != CreationPhase.source)
            OutlinedButton.icon(
              onPressed: provider.reset,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Wizard'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
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
          title: provider.fileName ?? (provider.textContent.length > 30 ? '${provider.textContent.substring(0, 30)}...' : provider.textContent),
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
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          Text(
            'How would you like to start?',
            style: GoogleFonts.outfit(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 16),
          Text(
            'Select your material source and our AI will build your complete study pack.',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 60),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildWebSourceCard(
                    context,
                    'PDF / Documents',
                    'Upload lectures, textbooks, or notes.',
                    Icons.picture_as_pdf_rounded,
                    () => _pickFile(context, provider, user, ['pdf', 'doc', 'docx', 'txt'], 'pdf'),
                    Colors.redAccent,
                  ),
                  _buildWebSourceCard(
                    context,
                    'Topic / Subject',
                    'Type a topic and AI will generate content.',
                    Icons.lightbulb_rounded,
                    () => _showInputDialog(context, provider, 'Enter Topic', 'e.g. Quantum Physics or Cell Biology', isTopic: true),
                    Colors.blueAccent,
                  ),
                  _buildWebSourceCard(
                    context,
                    'Paste Content',
                    'Directly paste your notes here.',
                    Icons.text_snippet_rounded,
                    () => _showInputDialog(context, provider, 'Paste Notes', 'Paste your long content here...'),
                    Colors.orangeAccent,
                  ),
                  _buildWebSourceCard(
                    context,
                    'Web Link',
                    'Import an article or research paper.',
                    Icons.link_rounded,
                    () => _showInputDialog(context, provider, 'Enter URL', 'https://example.com/article', isLink: true),
                    Colors.tealAccent,
                  ),
                  _buildWebSourceCard(
                    context,
                    'YouTube Video',
                    'Extract knowledge from videos.',
                    Icons.play_circle_fill_rounded,
                    () => _showInputDialog(context, provider, 'YouTube URL', 'https://youtube.com/watch?v=...', isLink: true),
                    Colors.deepOrange,
                  ),
                ],
              );
            },
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildWebSourceCard(BuildContext context, String title, String desc, IconData icon, VoidCallback onTap, Color accentColor) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        height: 240,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.05),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 36),
            ),
            const Spacer(),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
      provider.setSource(type, fileName: file.name, bytes: file.bytes, mime: _getMimeType(file.name));
    }
  }

  void _showInputDialog(BuildContext context, CreateContentProvider provider, String title, String hint, {bool isTopic = false, bool isLink = false}) {
    _textController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: _textController,
            autofocus: true,
            maxLines: isLink || isTopic ? 1 : 10,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: Colors.grey),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final text = _textController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context);
                provider.setSource(isTopic ? 'topic' : (isLink ? 'link' : 'text'), text: text);
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Next'),
          ),
        ],
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
      'mp4': 'video/mp4',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  // --- PHASE 2: CONFIGURATION ---
  Widget _buildConfiguration(BuildContext context, CreateContentProvider provider) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhaseHeader('Ready to scan', 'Your source is picked. Now configure how you want to study.'),
                const SizedBox(height: 32),
                ConfigSelector(
                  selectedDifficulty: provider.selectedDifficulty,
                  selectedCount: provider.selectedCount,
                  selectedQuestionTypes: provider.selectedQuestionTypes,
                  onDifficultyChanged: (v) => provider.updateConfig(difficulty: v),
                  onCountChanged: (v) => provider.updateConfig(count: v),
                  onToggleType: (v) => provider.toggleQuestionType(v),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: () {
                      final user = Provider.of<UserModel?>(context, listen: false);
                      if (user != null) provider.startGeneration(user.uid);
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 24),
                        const SizedBox(width: 16),
                        Text(
                          'Generate Full Study Pack',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 60),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SOURCE PREVIEW', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: theme.colorScheme.primary, letterSpacing: 1.5)),
                  const SizedBox(height: 20),
                  _buildSourceSummary(provider),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  Text('AI GENERATES:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                  const SizedBox(height: 16),
                  _buildAIFeatureRow(Icons.description_rounded, 'Comprehensive Summary'),
                  _buildAIFeatureRow(Icons.quiz_rounded, 'Topic-aligned Quiz'),
                  _buildAIFeatureRow(Icons.style_rounded, 'Interactive Flashcards'),
                  _buildAIFeatureRow(Icons.psychology_rounded, 'SRS Scheduling'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseHeader(String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 12),
        Text(subtitle, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildSourceSummary(CreateContentProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          provider.fileName ?? (provider.textContent.length > 100 ? '${provider.textContent.substring(0, 100)}...' : provider.textContent),
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Input Type: ${provider.selectedSourceType.toUpperCase()}',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildAIFeatureRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // --- PHASE: ERROR ---
  Widget _buildErrorView(BuildContext context, CreateContentProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 600,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 60),
          const SizedBox(height: 32),
          Text('Extraction Failed', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
          const SizedBox(height: 16),
          Text(provider.errorMessage, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: provider.reset, child: const Text('Choose Different Source')),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: provider.backToConfig,
                style: ElevatedButton.styleFrom(backgroundColor: colorScheme.onSurface, foregroundColor: colorScheme.surface),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

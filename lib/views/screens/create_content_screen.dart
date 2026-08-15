import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/user_model.dart';
import '../../utils/youtube_pro_gate.dart';
import '../../providers/create_content_provider.dart';
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
  late final TextEditingController _topicController;
  final TextEditingController _urlController = TextEditingController();
  bool _showMoreOptions = false;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: 'CRISPR-Cas9');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<CreateContentProvider>(context, listen: false);
      if (provider.textContent.isNotEmpty) {
        _topicController.text = provider.textContent;
      }
      final folderId =
          GoRouterState.of(context).uri.queryParameters['folderId'];
      if (folderId != null) {
        provider.setPreSelectedFolderId(folderId);
      }
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<CreateContentProvider>(context);
    final user = Provider.of<UserModel?>(context);

    if (provider.limitReached) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          provider.clearLimitReached();
          UpgradeDialog.show(context, featureName: 'AI Synthesis');
        }
      });
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _buildPhaseContent(context, provider, user, isDark),
        ),
      ),
    );
  }

  Widget _buildPhaseContent(BuildContext context,
      CreateContentProvider provider, UserModel? user, bool isDark) {
    switch (provider.phase) {
      case CreationPhase.source:
      case CreationPhase.config:
        return _buildCustomizeStudyPackView(context, provider, user, isDark);
      case CreationPhase.extractionReview:
        return const ExtractionReviewView();
      case CreationPhase.processing:
        return CreationProgressIndicator(
          message: provider.progressMessage,
          tip: provider.currentTip,
        );
      case CreationPhase.success:
        return CreationSuccessView(
          title: provider.fileName ??
              (_topicController.text.isNotEmpty
                  ? _topicController.text
                  : provider.textContent),
          onViewPack: () {
            context.pushNamed('results-view',
                pathParameters: {'folderId': provider.generatedFolderId});
            provider.reset();
          },
          onReset: () {
            provider.reset();
            _topicController.text = 'CRISPR-Cas9';
          },
        );
      case CreationPhase.error:
        return _buildErrorView(context, provider);
    }
  }

  Widget _buildCustomizeStudyPackView(BuildContext context,
      CreateContentProvider provider, UserModel? user, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);
    final textDark = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const primaryBlue = Color(0xFF1D4ED8);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Screen Title Header
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Customize Study Pack',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Main Customization Card
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Card Header with Back and SumQuiz Logo
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              provider.reset();
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/');
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: 28,
                                color: textDark,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/sumquiz_logo.png',
                                width: 22,
                                height: 22,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.school_rounded,
                                  color: primaryBlue,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'SumQuiz',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const SizedBox(width: 32), // Balance back button
                        ],
                      ),
                    ),

                    Divider(height: 1, color: borderColor),

                    // Topic Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Topic',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _topicController,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: textDark,
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Enter topic or keyword...',
                                      hintStyle: GoogleFonts.inter(
                                        color: textMuted,
                                        fontSize: 15,
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 12),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: textMuted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 1, color: borderColor),

                    // Difficulty Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Difficulty',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                _buildDifficultyPill(
                                  label: 'Easy',
                                  value: 'beginner',
                                  isSelected:
                                      provider.selectedDifficulty == 'beginner',
                                  onTap: () => provider.updateConfig(
                                      difficulty: 'beginner'),
                                  isDark: isDark,
                                ),
                                _buildDifficultyPill(
                                  label: 'Medium',
                                  value: 'intermediate',
                                  isSelected: provider.selectedDifficulty ==
                                          'intermediate' ||
                                      provider.selectedDifficulty == 'medium',
                                  onTap: () => provider.updateConfig(
                                      difficulty: 'intermediate'),
                                  isDark: isDark,
                                ),
                                _buildDifficultyPill(
                                  label: 'Hard',
                                  value: 'advanced',
                                  isSelected:
                                      provider.selectedDifficulty == 'advanced',
                                  onTap: () => provider.updateConfig(
                                      difficulty: 'advanced'),
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 1, color: borderColor),

                    // Quiz Items & Flashcards Steppers Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quiz Items
                          Text(
                            'Quiz Items',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildStepper(
                            value: provider.quizCount,
                            onChanged: (newVal) =>
                                provider.updateConfig(quizCount: newVal),
                            min: 3,
                            max: 30,
                            isDark: isDark,
                            borderColor: borderColor,
                            textDark: textDark,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Questions per session',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Flashcards
                          Text(
                            'Flashcards',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildStepper(
                            value: provider.flashcardCount,
                            onChanged: (newVal) =>
                                provider.updateConfig(flashcardCount: newVal),
                            min: 3,
                            max: 40,
                            isDark: isDark,
                            borderColor: borderColor,
                            textDark: textDark,
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 1, color: borderColor),

                    // Quiz Format Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quiz Format',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFormatChip(
                                label: 'Multiple Choice',
                                isSelected: provider.selectedQuestionTypes
                                    .contains('Multiple Choice'),
                                onTap: () => provider
                                    .toggleQuestionType('Multiple Choice'),
                                isDark: isDark,
                                borderColor: borderColor,
                              ),
                              _buildFormatChip(
                                label: 'True/False',
                                isSelected: provider.selectedQuestionTypes
                                    .contains('True/False'),
                                onTap: () =>
                                    provider.toggleQuestionType('True/False'),
                                isDark: isDark,
                                borderColor: borderColor,
                              ),
                              _buildFormatChip(
                                label: 'Short Answer',
                                isSelected: provider.selectedQuestionTypes
                                    .contains('Short Answer') ||
                                    provider.selectedQuestionTypes
                                        .contains('Fill in Blank'),
                                onTap: () =>
                                    provider.toggleQuestionType('Short Answer'),
                                isDark: isDark,
                                borderColor: borderColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // More options expandable toggle
                    InkWell(
                      onTap: () => setState(
                          () => _showMoreOptions = !_showMoreOptions),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _showMoreOptions
                                  ? 'Fewer options'
                                  : 'More options',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showMoreOptions
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expanded options area
                    if (_showMoreOptions) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ATTACH SOURCE MATERIAL',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: textMuted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildSourceActionButton(
                                    icon: Icons.picture_as_pdf_rounded,
                                    label: 'PDF Document',
                                    onTap: () => _pickFile(context, provider,
                                        user, ['pdf'], 'pdf'),
                                    isDark: isDark,
                                  ),
                                  _buildSourceActionButton(
                                    icon: Icons.play_circle_fill_rounded,
                                    label: 'YouTube',
                                    onTap: () => _showUrlInputDialog(
                                        context, provider,
                                        isYoutube: true),
                                    isDark: isDark,
                                  ),
                                  _buildSourceActionButton(
                                    icon: Icons.link_rounded,
                                    label: 'Web Link',
                                    onTap: () => _showUrlInputDialog(
                                        context, provider,
                                        isYoutube: false),
                                    isDark: isDark,
                                  ),
                                  _buildSourceActionButton(
                                    icon: Icons.camera_alt_rounded,
                                    label: 'Scan / Image',
                                    onTap: () => _pickFile(context, provider,
                                        user, ['jpg', 'jpeg', 'png'], 'image'),
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                              if (provider.fileName != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded,
                                          size: 16, color: primaryBlue),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Attached: ${provider.fileName}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: primaryBlue,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: provider.backToSource,
                                        child: const Icon(Icons.close_rounded,
                                            size: 16, color: primaryBlue),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Generate Study Pack CTA
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () => _onGeneratePressed(provider, user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Generate Study Pack',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyPill({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    const primaryBlue = Color(0xFF2563EB);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper({
    required int value,
    required ValueChanged<int> onChanged,
    required int min,
    required int max,
    required bool isDark,
    required Color borderColor,
    required Color textDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 20),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            color: textDark,
            splashRadius: 20,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          Container(
            width: 1,
            height: 28,
            color: borderColor,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 48),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textDark,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: borderColor,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 20),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            color: textDark,
            splashRadius: 20,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color borderColor,
  }) {
    const primaryBlue = Color(0xFF2563EB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryBlue
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryBlue : borderColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2563EB)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onGeneratePressed(
      CreateContentProvider provider, UserModel? user) async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty && provider.textContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic to study!')),
      );
      return;
    }

    if (provider.selectedSourceType.isEmpty) {
      provider.setSource('topic', text: topic.isNotEmpty ? topic : 'General');
    } else if (topic.isNotEmpty && provider.selectedSourceType == 'topic') {
      provider.setSource('topic', text: topic);
    }

    if (user != null) {
      provider.startGeneration(
        user.uid,
        allowYouTubeImport: userMayImportFromYouTube(user),
        allowPdfImport: userMayImportFromPdf(user),
        allowWebImport: userMayImportFromWeb(user),
      );
    }
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
      if (_topicController.text.isEmpty ||
          _topicController.text == 'CRISPR-Cas9') {
        _topicController.text = file.name.split('.').first;
      }
    }
  }

  void _showUrlInputDialog(BuildContext context, CreateContentProvider provider,
      {bool isYoutube = false}) {
    _urlController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          top: 24,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isYoutube ? 'Attach YouTube Video' : 'Attach Web Article',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: isYoutube
                    ? 'https://youtube.com/watch?v=...'
                    : 'https://example.com/article',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                    isYoutube
                        ? Icons.play_circle_outline_rounded
                        : Icons.link_rounded,
                    size: 20),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final url = _urlController.text.trim();
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
                  provider.setSource(isYoutube ? 'youtube' : 'link', text: url);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Attach Source',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Retry Synthesis',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            )
          else
            ElevatedButton(
              onPressed: () => context.push('/settings/subscription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Unlock Pro',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: provider.reset,
            child: Text('Reset Selection',
                style: GoogleFonts.inter(color: Theme.of(context).hintColor)),
          ),
        ],
      ),
    );
  }
}

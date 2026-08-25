import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/user_model.dart';
import '../../utils/youtube_pro_gate.dart';
import '../../providers/create_content_provider.dart';
import '../widgets/create_content/creation_progress_indicator.dart';
import '../widgets/create_content/creation_success_view.dart';
import '../widgets/create_content/extraction_review_view.dart';
import '../widgets/upgrade_dialog.dart';
import '../../widgets/sumi_mascot.dart';
import '../../models/sumi_emotion.dart';
import '../../theme/web_theme.dart';

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  late final TextEditingController _topicController;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _rawTextController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<CreateContentProvider>(context, listen: false);
      if (provider.fileName != null && provider.fileName!.isNotEmpty) {
        _topicController.text = provider.fileName!;
      } else if (provider.textContent.isNotEmpty &&
          provider.selectedSourceType == 'topic') {
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
    _rawTextController.dispose();
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
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
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
        return _buildSourceSelectionView(context, provider, user, isDark);
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
            _topicController.clear();
          },
        );
      case CreationPhase.error:
        return _buildErrorView(context, provider);
    }
  }

  // ─── 1. Knowledge Source Selection Hub ──────────────────────────────────────

  Widget _buildSourceSelectionView(BuildContext context,
      CreateContentProvider provider, UserModel? user, bool isDark) {
    final textDark = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar
          Row(
            children: [
              if (context.canPop())
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  color: textDark,
                ),
              Text(
                'Create Material',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: WebColors.purplePrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: WebColors.purplePrimary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      user?.isPro == true ? 'Pro Unlimited' : 'AI Powered',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: WebColors.purplePrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Hero Header
          Text(
            'What would you like to study today?',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: textDark,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(duration: 250.ms),
          const SizedBox(height: 8),
          Text(
            'Upload a document, paste notes, or type any topic to synthesize a complete study pack.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: textMuted,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 50.ms, duration: 250.ms),
          const SizedBox(height: 24),

          // Source Cards Grid
          Text(
            'IMPORT MATERIALS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 12),

          _buildSourceCard(
            title: 'Upload Document / PDF',
            description:
                'Textbooks, slide decks, research papers, and Word files (.pdf, .docx, .txt)',
            icon: Icons.picture_as_pdf_rounded,
            iconBg: const Color(0xFFEF4444),
            isDark: isDark,
            onTap: () => _pickFile(
                context, provider, user, ['pdf', 'doc', 'docx', 'txt'], 'pdf'),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),

          _buildSourceCard(
            title: 'Scan or Photo / Notes',
            description:
                'Snap a photo of your book, handwritten notes, or whiteboard with on-device OCR',
            icon: Icons.camera_alt_rounded,
            iconBg: const Color(0xFF06B6D4),
            isDark: isDark,
            onTap: () => _pickImage(context, provider, user),
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 12),

          _buildSourceCard(
            title: 'Voice & Audio Brief',
            description:
                'Upload lecture audio, discussions, or voice memos (.mp3, .wav, .m4a)',
            icon: Icons.mic_rounded,
            iconBg: const Color(0xFF10B981),
            isDark: isDark,
            onTap: () => _pickFile(
                context, provider, user, ['mp3', 'wav', 'm4a', 'aac'], 'audio'),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),

          _buildSourceCard(
            title: 'YouTube Video',
            description:
                'Turn any educational YouTube video into instant interactive quizzes and flashcards',
            icon: Icons.play_circle_fill_rounded,
            iconBg: const Color(0xFFDC2626),
            isDark: isDark,
            onTap: () =>
                _showUrlInputDialog(context, provider, isYoutube: true),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 12),

          _buildSourceCard(
            title: 'Web Article / Link',
            description:
                'Extract key insights, summaries, and test items from any public webpage',
            icon: Icons.language_rounded,
            iconBg: const Color(0xFF3B82F6),
            isDark: isDark,
            onTap: () =>
                _showUrlInputDialog(context, provider, isYoutube: false),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 24),

          // Instant Generation Section
          Text(
            'OR GENERATE FROM SCRATCH',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 12),

          _buildSourceCard(
            title: 'Type a Topic / Subject',
            description:
                'Enter any subject (e.g. "CRISPR-Cas9", "Macroeconomics") for autonomous AI curriculum generation',
            icon: Icons.auto_awesome_rounded,
            iconBg: const Color(0xFF7C3AED),
            isDark: isDark,
            onTap: () => _showTopicInputDialog(context, provider),
          ).animate().fadeIn(delay: 350.ms),
          const SizedBox(height: 12),

          _buildSourceCard(
            title: 'Paste Raw Text / Notes',
            description:
                'Paste syllabus notes, excerpts, or research summaries directly into the editor',
            icon: Icons.text_fields_rounded,
            iconBg: const Color(0xFF8B5CF6),
            isDark: isDark,
            onTap: () => _showRawTextInputDialog(context, provider),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSourceCard({
    required String title,
    required String description,
    required IconData icon,
    required Color iconBg,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFE2E8F0);
    final textDark = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconBg, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey[400], size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 2. Full-Page Professional Customization Screen ─────────────────────────

  Widget _buildCustomizeStudyPackView(BuildContext context,
      CreateContentProvider provider, UserModel? user, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final textDark = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final sourceDisplay = provider.fileName ??
        (provider.selectedSourceType.isNotEmpty
            ? provider.selectedSourceType.toUpperCase()
            : 'Custom Topic');

    return Column(
      children: [
        // Top App Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  provider.backToSource();
                },
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: textDark,
                tooltip: 'Back to Sources',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Customize Study Pack',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
              ),
              TextButton(
                onPressed: provider.reset,
                child: Text(
                  'Reset',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Source Status Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: WebColors.purplePrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: WebColors.purplePrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: WebColors.purplePrimary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: WebColors.purplePrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SOURCE ATTACHED',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                color: WebColors.purplePrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sourceDisplay,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: provider.backToSource,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: WebColors.purplePrimary
                                  .withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Change',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: WebColors.purplePrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 1. Topic & Deck Name
                _buildSectionHeader('DECK TITLE & TOPIC', textMuted),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: cardBg,
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
                            hintText: 'Enter topic name or study subject...',
                            hintStyle: GoogleFonts.inter(
                              color: textMuted,
                              fontSize: 15,
                            ),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      Icon(Icons.edit_outlined, size: 18, color: textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Difficulty Selection
                _buildSectionHeader('COMPLEXITY LEVEL', textMuted),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildDifficultyCard(
                      label: 'Beginner',
                      subtitle: 'Foundational & recall',
                      value: 'beginner',
                      isSelected: provider.selectedDifficulty == 'beginner',
                      onTap: () =>
                          provider.updateConfig(difficulty: 'beginner'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    _buildDifficultyCard(
                      label: 'Intermediate',
                      subtitle: 'Applied concepts',
                      value: 'intermediate',
                      isSelected:
                          provider.selectedDifficulty == 'intermediate' ||
                              provider.selectedDifficulty == 'medium',
                      onTap: () =>
                          provider.updateConfig(difficulty: 'intermediate'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    _buildDifficultyCard(
                      label: 'Advanced',
                      subtitle: 'Deep synthesis',
                      value: 'advanced',
                      isSelected: provider.selectedDifficulty == 'advanced',
                      onTap: () =>
                          provider.updateConfig(difficulty: 'advanced'),
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. Volume Targets (Steppers)
                _buildSectionHeader('VOLUME OF MATERIALS', textMuted),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quiz Questions',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Practice items per session',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
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
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: borderColor),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Flashcards',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Active recall cards',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Quiz Format Selection
                _buildSectionHeader('QUESTION FORMATS', textMuted),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildFormatChip(
                      label: 'Multiple Choice',
                      isSelected: provider.selectedQuestionTypes
                          .contains('Multiple Choice'),
                      onTap: () =>
                          provider.toggleQuestionType('Multiple Choice'),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                    _buildFormatChip(
                      label: 'True / False',
                      isSelected:
                          provider.selectedQuestionTypes.contains('True/False'),
                      onTap: () => provider.toggleQuestionType('True/False'),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                    _buildFormatChip(
                      label: 'Short Answer',
                      isSelected: provider.selectedQuestionTypes
                              .contains('Short Answer') ||
                          provider.selectedQuestionTypes
                              .contains('Fill in Blank'),
                      onTap: () => provider.toggleQuestionType('Short Answer'),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 5. Study Archetype
                _buildSectionHeader('STUDY ARCHETYPE', textMuted),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildArchetypeCard(
                        title: 'Sprinter',
                        subtitle: 'High-yield memory sprint',
                        icon: Icons.bolt_rounded,
                        isSelected: provider.selectedArchetype ==
                            StudyArchetype.sprinter,
                        onTap: () => provider.updateConfig(
                            archetype: StudyArchetype.sprinter),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildArchetypeCard(
                        title: 'Architect',
                        subtitle: 'Deep conceptual mastery',
                        icon: Icons.account_tree_rounded,
                        isSelected: provider.selectedArchetype ==
                            StudyArchetype.architect,
                        onTap: () => provider.updateConfig(
                            archetype: StudyArchetype.architect),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // Sticky Bottom Generate Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(top: BorderSide(color: borderColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => _onGeneratePressed(provider, user),
                icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                label: Text(
                  'Generate Study Pack',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebColors.purplePrimary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: color,
      ),
    );
  }

  Widget _buildDifficultyCard({
    required String label,
    required String subtitle,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? WebColors.purplePrimary
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? WebColors.purplePrimary
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0)),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.8)
                      : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchetypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? WebColors.purplePrimary.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? WebColors.purplePrimary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? WebColors.purplePrimary
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[500],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? WebColors.purplePrimary
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 18),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            color: textDark,
            splashRadius: 18,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 36),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textDark,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 18),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            color: textDark,
            splashRadius: 18,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? WebColors.purplePrimary
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? WebColors.purplePrimary : borderColor,
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

  // ─── Input & Pick Handlers ──────────────────────────────────────────────────

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
    } else if (topic.isNotEmpty) {
      provider.updateTitle(topic);
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
      _topicController.text = file.name.split('.').first;
    }
  }

  Future<void> _pickImage(BuildContext context, CreateContentProvider provider,
      UserModel? user) async {
    if (user != null && !user.isPro && user.computeUnits <= 0) {
      showDialog(
          context: context,
          builder: (_) => const UpgradeDialog(featureName: 'Neural Uploads'));
      return;
    }

    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      provider.setSource(
        'image',
        fileName: image.name,
        bytes: bytes,
        mime: 'image/jpeg',
      );
      _topicController.text = image.name.split('.').first;
    }
  }

  void _showTopicInputDialog(
      BuildContext context, CreateContentProvider provider) {
    _topicController.clear();
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
              'Enter Subject or Topic',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sumi AI will generate structured flashcards, quizzes, and key concepts.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _topicController,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. Quantum Computing, Photosynthesis...',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.auto_awesome_rounded,
                    color: WebColors.purplePrimary, size: 20),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final topic = _topicController.text.trim();
                if (topic.isNotEmpty) {
                  Navigator.pop(context);
                  provider.setSource('topic', text: topic, fileName: topic);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: WebColors.purplePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Continue to Customize',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRawTextInputDialog(
      BuildContext context, CreateContentProvider provider) {
    _rawTextController.clear();
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
              'Paste Notes or Syllabus Text',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rawTextController,
              autofocus: true,
              maxLines: 6,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Paste lecture notes, study guide text, or summary...',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final text = _rawTextController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context);
                  final firstWords = text.split(' ').take(4).join(' ');
                  provider.setSource('text',
                      text: text, fileName: '$firstWords...');
                  _topicController.text = firstWords;
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: WebColors.purplePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Continue with Notes',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
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
                  provider.setSource(isYoutube ? 'youtube' : 'link',
                      text: url,
                      fileName: isYoutube ? 'YouTube Video' : 'Web Article');
                  _topicController.text =
                      isYoutube ? 'YouTube Video Study' : 'Web Article Study';
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: WebColors.purplePrimary,
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

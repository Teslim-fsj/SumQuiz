import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:sumquiz/services/exam_pdf_generator.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/utils/share_code_generator.dart';
import 'package:sumquiz/services/youtube_service.dart';
import 'package:sumquiz/utils/youtube_pro_gate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sumquiz/services/download/download_helper.dart';
import 'package:sumquiz/theme/web_theme.dart';

class ExamCreationScreen extends StatefulWidget {
  const ExamCreationScreen({super.key});

  @override
  State<ExamCreationScreen> createState() => _ExamCreationScreenState();
}

class _ExamCreationScreenState extends State<ExamCreationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _customLevelController = TextEditingController();
  final TextEditingController _smartDescriptionController =
      TextEditingController();

  String _selectedLevel = 'JSS1';
  int _numberOfQuestions = 15;
  String _duration = '60';
  String _selectedDifficultyName = 'Intermediate';
  String _cognitiveFocus = 'Apply & Analyze';
  double _difficultyValue = 0.5;

  bool _includeMultipleChoice = true;
  bool _includeShortAnswer = false;
  bool _includeTheory = false;
  bool _includeTrueFalse = false;
  bool _evenTopicCoverage = true;
  bool _focusWeakAreas = false;

  String _sourceMaterial = '';
  String _selectedSourceType = '';
  String _sourceFileName = '';

  bool _isProcessing = false;
  String _processingMessage = '';
  final ImagePicker _imagePicker = ImagePicker();
  CancellationToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    _titleController.dispose();
    _subjectController.dispose();
    _customLevelController.dispose();
    _smartDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = Provider.of<UserModel?>(context, listen: false);
    final textDark = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);

    if (user != null &&
        !user.isPro &&
        user.role != UserRole.creator &&
        user.examsGenerated >= 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => const UpgradeDialog(
              featureName: 'Tutor Exam',
            ),
          );
        }
      });

      return Scaffold(
        appBar: AppBar(
          title: const Text('Create New Exam'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              Text('Tutor Exam feature requires Pro subscription',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.push('/settings/subscription'),
                child: const Text('Upgrade to Pro'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'SumQuiz',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            Text(
              'Step 1: Setup',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textDark),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF6B5CE7)),
                  const SizedBox(height: 16),
                  Text(
                    _processingMessage,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      _cancelToken?.cancel();
                      setState(() {
                        _isProcessing = false;
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Source Material',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Choose how you want to build this exam.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            WebColors.purplePrimary.withValues(alpha: 0.1),
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL == null
                            ? Image.asset(
                                'assets/images/sumi.png',
                                width: 28,
                                height: 28,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    color: WebColors.purplePrimary,
                                    size: 20),
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridSourceCard(
                          title: 'PDF Document',
                          subtitle: 'Upload a file',
                          icon: Icons.picture_as_pdf_outlined,
                          isSelected: _selectedSourceType == 'PDF',
                          onTap: () => _selectSourceMaterial('PDF'),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridSourceCard(
                          title: 'Paste Notes',
                          subtitle: 'Direct text input',
                          icon: Icons.description_outlined,
                          badgeText: '✨ SUMI SUGGESTED',
                          isSelected: _selectedSourceType == 'Notes',
                          onTap: () => _selectSourceMaterial('Notes'),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridSourceCard(
                          title: 'Images',
                          subtitle: 'Scan diagrams/text',
                          icon: Icons.image_outlined,
                          isSelected: _selectedSourceType == 'Image',
                          onTap: () => _showImageSourceSelection(),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridSourceCard(
                          title: 'YouTube Link',
                          subtitle: 'Generate from video',
                          icon: Icons.play_circle_outline_rounded,
                          isSelected: _selectedSourceType == 'YouTube',
                          onTap: () => _selectSourceMaterial('YouTube'),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  if (_sourceMaterial.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF16A34A), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Attached: ${_sourceFileName.isNotEmpty ? _sourceFileName : 'Source loaded (${_sourceMaterial.length} chars)'}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF15803D),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() {
                              _sourceMaterial = '';
                              _sourceFileName = '';
                              _selectedSourceType = '';
                            }),
                            child: const Icon(Icons.close_rounded,
                                size: 18, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          size: 16, color: Color(0xFF0F172A)),
                      const SizedBox(width: 6),
                      Text(
                        'Smart Description',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(Optional)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _smartDescriptionController,
                            style: GoogleFonts.inter(
                                fontSize: 14, color: textDark),
                            maxLines: 2,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText:
                                  "Tell Sumi what you want to focus on (e.g., 'Focus heavily on the causes of the Civil...",
                              hintStyle: GoogleFonts.inter(
                                fontSize: 13,
                                color: textMuted,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _showPromptSuggestionsModal,
                          icon: Icon(Icons.mic_none_rounded,
                              color: textDark, size: 22),
                          tooltip: 'Prompt Suggestions',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Exam Configuration',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildConfigRow(
                          icon: Icons.psychology_outlined,
                          title: 'Difficulty Level',
                          value: _selectedDifficultyName,
                          onTap: _showDifficultyModal,
                          isDark: isDark,
                        ),
                        Divider(height: 1, color: borderColor),
                        _buildConfigRow(
                          icon: Icons.format_list_bulleted_rounded,
                          title: 'Question Count',
                          value: '$_numberOfQuestions Questions',
                          onTap: _showQuestionCountModal,
                          isDark: isDark,
                        ),
                        Divider(height: 1, color: borderColor),
                        _buildConfigRow(
                          icon: Icons.lightbulb_outlined,
                          title: 'Cognitive Focus',
                          value: _cognitiveFocus,
                          onTap: _showCognitiveFocusModal,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _generateDraftExam,
                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            isDark ? const Color(0xFF1E293B) : Colors.white,
                        side: BorderSide(color: borderColor, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.04),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Create Exam',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded,
                              color: textDark, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildGridSourceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    String? badgeText,
    bool isSelected = false,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isSelected
        ? WebColors.purplePrimary
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFE2E8F0));
    final textDark = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      height: 125,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
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
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: textDark, size: 24),
                    if (badgeText != null)
                      Text(
                        badgeText,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: textDark,
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final textDark = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: textDark),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textMuted, size: 22),
          ],
        ),
      ),
    );
  }

  void _showDifficultyModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Difficulty Level',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.sentiment_satisfied_alt_rounded,
                    color: Colors.green),
                title: const Text('Beginner (Easy)'),
                subtitle: const Text('Foundational recall and basic definitions'),
                trailing: _selectedDifficultyName == 'Beginner'
                    ? const Icon(Icons.check, color: WebColors.purplePrimary)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedDifficultyName = 'Beginner';
                    _difficultyValue = 0.2;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sentiment_neutral_rounded,
                    color: Colors.blue),
                title: const Text('Intermediate (Medium)'),
                subtitle: const Text('Applied concepts and scenario analysis'),
                trailing: _selectedDifficultyName == 'Intermediate'
                    ? const Icon(Icons.check, color: WebColors.purplePrimary)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedDifficultyName = 'Intermediate';
                    _difficultyValue = 0.5;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sentiment_very_satisfied_rounded,
                    color: Colors.orange),
                title: const Text('Advanced (Hard)'),
                subtitle: const Text('Deep evaluation, theory & multi-step problems'),
                trailing: _selectedDifficultyName == 'Advanced'
                    ? const Icon(Icons.check, color: WebColors.purplePrimary)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedDifficultyName = 'Advanced';
                    _difficultyValue = 0.8;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuestionCountModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Question Count',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [10, 15, 20, 25, 30, 40, 50].map((count) {
                  final isSelected = _numberOfQuestions == count;
                  return ChoiceChip(
                    label: Text('$count Questions'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _numberOfQuestions = count);
                        Navigator.pop(context);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showCognitiveFocusModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Cognitive Focus',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Apply & Analyze'),
                subtitle: const Text('Practical problem solving and real-world application'),
                trailing: _cognitiveFocus == 'Apply & Analyze'
                    ? const Icon(Icons.check, color: WebColors.purplePrimary)
                    : null,
                onTap: () {
                  setState(() => _cognitiveFocus = 'Apply & Analyze');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Recall & Understand'),
                subtitle: const Text('Key definitions, terms, and foundational memory'),
                trailing: _cognitiveFocus == 'Recall & Understand'
                    ? const Icon(Icons.check, color: WebColors.purplePrimary)
                    : null,
                onTap: () {
                  setState(() => _cognitiveFocus = 'Recall & Understand');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Evaluate & Create'),
                subtitle: const Text('High-order critique, essay theory, and synthesis'),
                trailing: _cognitiveFocus == 'Evaluate & Create'
                    ? const Icon(Icons.check, color: WebColors.purplePrimary)
                    : null,
                onTap: () {
                  setState(() => _cognitiveFocus = 'Evaluate & Create');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPromptSuggestionsModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Focus Prompts',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Focus heavily on formulas and calculation steps',
                  'Emphasize key definitions and vocabulary',
                  'Include real-world case study questions',
                  'Test common pitfalls and misconceptions',
                ].map((prompt) {
                  return ActionChip(
                    label: Text(prompt, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        _smartDescriptionController.text = prompt;
                      });
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageSourceSelection() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Select Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo (Snap)'),
              onTap: () {
                Navigator.pop(context);
                _pickFromImagePicker(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pick from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFromImagePicker(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Select Files'),
              onTap: () {
                Navigator.pop(context);
                _selectSourceMaterial('Image');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromImagePicker(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> images = await _imagePicker.pickMultiImage(
          imageQuality: 80,
          maxHeight: 1920,
          maxWidth: 1920,
        );

        if (images.isNotEmpty) {
          List<Map<String, dynamic>> newFiles = [];
          for (final image in images) {
            final bytes = await image.readAsBytes();
            newFiles.add({
              'name': image.name,
              'bytes': bytes,
              'type': 'image',
            });
          }
          _processSelectedFiles(newFiles);
        }
      } else {
        bool keepSnapping = true;
        while (keepSnapping) {
          final XFile? image = await _imagePicker.pickImage(
            source: source,
            imageQuality: 80,
            maxHeight: 1920,
            maxWidth: 1920,
          );

          if (image != null) {
            final bytes = await image.readAsBytes();
            _processSelectedFiles([
              {
                'name': image.name,
                'bytes': bytes,
                'type': 'image',
              }
            ]);

            if (mounted) {
              final shouldContinue = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Add Another Page?'),
                  content: const Text(
                      'Would you like to snap another photo to add to this exam?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Done')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Snap Another')),
                  ],
                ),
              );
              keepSnapping = shouldContinue ?? false;
            } else {
              keepSnapping = false;
            }
          } else {
            keepSnapping = false;
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _processSelectedFiles(List<Map<String, dynamic>> files) async {
    if (files.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Extracting content...';
    });

    try {
      final user = Provider.of<UserModel?>(context, listen: false);
      final enhancedAiService =
          Provider.of<EnhancedAIService>(context, listen: false);
      final extractionService = ContentExtractionService(enhancedAiService);
      _cancelToken = CancellationToken();

      String combinedText = _sourceMaterial;
      if (combinedText.isNotEmpty) combinedText += '\n\n';

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        setState(() => _processingMessage =
            'Extracting from ${file['name']} (${i + 1}/${files.length})...');

        final extractionResult = await extractionService.extractContent(
          type: file['type'] ?? 'image',
          input: file['bytes'],
          userId: user?.uid,
          mimeType: (file['type'] == 'pdf') ? 'application/pdf' : 'image/jpeg',
          allowYouTubeImport: userMayImportFromYouTube(user),
          onProgress: (msg) {
            if (mounted) setState(() => _processingMessage = msg);
          },
          cancelToken: _cancelToken,
        );

        if (combinedText.isNotEmpty && !combinedText.endsWith('\n\n')) {
          combinedText += '\n\n';
        }
        combinedText +=
            '--- Source: ${file['name']} ---\n${extractionResult.text}';
      }

      if (mounted) {
        setState(() {
          _sourceMaterial = combinedText;
          _sourceFileName = files.isNotEmpty
              ? (files.length == 1
                  ? files.first['name']
                  : '${files.length} files attached')
              : 'Uploaded Files';
          _selectedSourceType = files.isNotEmpty
              ? (files.first['type'] == 'pdf' ? 'PDF' : 'Image')
              : '';
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectSourceMaterial(String type) async {
    setState(() {
      _selectedSourceType = type;
    });

    try {
      FilePickerResult? result;
      FileType fileType = FileType.any;
      List<String>? allowedExtensions;

      if (type == 'PDF') {
        fileType = FileType.custom;
        allowedExtensions = ['pdf'];
      } else if (type == 'Image') {
        fileType = FileType.image;
      } else if (type == 'YouTube') {
        _showYoutubeInputDialog();
        return;
      } else if (type == 'Notes') {
        _showNotesInputDialog();
        return;
      } else if (type == 'Audio') {
        fileType = FileType.audio;
      }

      setState(() {
        _isProcessing = true;
        _processingMessage = 'Selecting $type...';
      });

      result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        withData: true,
        allowMultiple: true,
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        List<Map<String, dynamic>> newFiles = [];
        for (final file in result.files) {
          if (file.bytes != null) {
            newFiles.add({
              'name': file.name,
              'bytes': file.bytes,
              'type': type.toLowerCase(),
            });
          }
        }
        _processSelectedFiles(newFiles);
      } else {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showNotesInputDialog() {
    final TextEditingController notesController =
        TextEditingController(text: _sourceMaterial);
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
            const Text(
              'Paste Teaching Notes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 12,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Paste your notes or full lesson text here...',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final text = notesController.text.trim();
                Navigator.pop(context);
                if (text.isNotEmpty) {
                  setState(() {
                    _sourceMaterial = text;
                    _sourceFileName = 'Direct Notes (${text.length} chars)';
                    _selectedSourceType = 'Notes';
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Done'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showYoutubeInputDialog() {
    final TextEditingController urlController = TextEditingController();
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
            const Text(
              'Enter YouTube Link',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?v=...',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.play_circle_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final url = urlController.text.trim();
                if (url.isNotEmpty && url.startsWith('http')) {
                  Navigator.pop(context);
                  _extractFromYoutube(url);
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Extract Transcript'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _extractFromYoutube(String url) async {
    final u = Provider.of<UserModel?>(context, listen: false);
    if (!userMayImportFromYouTube(u)) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => const UpgradeDialog(featureName: 'YouTube import'),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Fetching YouTube transcript...';
    });

    try {
      final youtubeService =
          Provider.of<YoutubeService>(context, listen: false);
      final transcript = await youtubeService.getTranscript(url);

      if (!mounted) return;
      setState(() {
        _sourceMaterial = transcript;
        _sourceFileName = 'YouTube Video Transcript';
        _selectedSourceType = 'YouTube';
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('YouTube Error: $e')),
      );
    }
  }

  Future<void> _generateDraftExam() async {
    if (_sourceMaterial.isEmpty && _smartDescriptionController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select or upload source material first'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    String examTitle = _titleController.text.trim();
    String subjectName = _subjectController.text.trim();

    if (examTitle.isEmpty) {
      if (_sourceFileName.isNotEmpty) {
        examTitle = _sourceFileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      } else if (_smartDescriptionController.text.isNotEmpty) {
        final words = _smartDescriptionController.text.split(' ');
        examTitle = words.take(5).join(' ');
      } else {
        examTitle = '$_selectedDifficultyName Exam Assessment';
      }
    }

    if (subjectName.isEmpty) {
      subjectName = examTitle;
    }

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Generating exam questions with AI...';
    });

    try {
      final user = Provider.of<UserModel?>(context, listen: false);
      if (user == null) throw Exception('User not authenticated');

      final enhancedAIService =
          Provider.of<EnhancedAIService>(context, listen: false);

      // Prepare question types
      final questionTypes = <String>[];
      if (_includeMultipleChoice) questionTypes.add('Multiple Choice');
      if (_includeShortAnswer) questionTypes.add('Short Answer');
      if (_includeTheory) questionTypes.add('Theory');
      if (_includeTrueFalse) questionTypes.add('True/False');

      if (questionTypes.isEmpty) {
        questionTypes.add('Multiple Choice');
      }

      // Combine source with smart description and cognitive focus instructions
      String combinedSource = _sourceMaterial;
      if (_smartDescriptionController.text.trim().isNotEmpty) {
        combinedSource =
            'Focus / Instructions: ${_smartDescriptionController.text.trim()}\nCognitive Focus: $_cognitiveFocus\n\n$combinedSource';
      } else {
        combinedSource =
            'Cognitive Focus: $_cognitiveFocus\n\n$combinedSource';
      }

      // Generate the exam using AI service
      _cancelToken = CancellationToken();

      final quiz = await enhancedAIService.generateExam(
        text: combinedSource,
        title: examTitle,
        subject: subjectName,
        level: _selectedLevel == 'Custom'
            ? _customLevelController.text
            : _selectedLevel,
        questionCount: _numberOfQuestions,
        easyCount:
            ((1.0 - _difficultyValue) * _numberOfQuestions * 0.7).round(),
        mediumCount: (_numberOfQuestions -
            ((1.0 - _difficultyValue) * _numberOfQuestions * 0.7).round() -
            (_difficultyValue * _numberOfQuestions * 0.7).round()),
        hardCount: (_difficultyValue * _numberOfQuestions * 0.7).round(),
        questionTypes: questionTypes,
        userId: user.uid,
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _processingMessage = message;
            });
          }
        },
        cancelToken: _cancelToken,
      );

      if (!mounted) return;

      final questions = quiz.questions;

      // Navigate to the question editor screen
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => QuestionEditorScreen(
              examTitle: examTitle,
              subject: subjectName,
              classLevel: _selectedLevel == 'Custom'
                  ? _customLevelController.text
                  : _selectedLevel,
              numberOfQuestions: _numberOfQuestions,
              duration: int.tryParse(_duration) ?? 60,
              questionTypes: questionTypes,
              difficultyMix: _difficultyValue,
              sourceMaterial: _sourceMaterial,
              initialQuestions: questions,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      // Log the actual error and stack trace for debugging
      debugPrint('Error generating exam: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating exam: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class QuestionEditorScreen extends StatefulWidget {
  final String examTitle;
  final String subject;
  final String classLevel;
  final int numberOfQuestions;
  final int duration;
  final List<String> questionTypes;
  final double difficultyMix;
  final String sourceMaterial;
  final List<LocalQuizQuestion>? initialQuestions;

  const QuestionEditorScreen({
    super.key,
    required this.examTitle,
    required this.subject,
    required this.classLevel,
    required this.numberOfQuestions,
    required this.duration,
    required this.questionTypes,
    required this.difficultyMix,
    required this.sourceMaterial,
    this.initialQuestions,
  });

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  late List<LocalQuizQuestion> _questions;
  bool _isProcessing = false;
  String _processingMessage = '';
  CancellationToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _questions = widget.initialQuestions ?? [];

    // If no initial questions were provided, generate mock questions
    if (_questions.isEmpty) {
      _generateMockQuestions();
    }
  }

  void _generateMockQuestions() {
    _questions = List.generate(
      widget.numberOfQuestions,
      (index) {
        final typeIndex = index % widget.questionTypes.length;
        final type = widget.questionTypes[typeIndex];

        if (type == 'Multiple Choice') {
          return LocalQuizQuestion(
            question: 'Sample MCQ $index: What is the capital of Nigeria?',
            options: ['Lagos', 'Abuja', 'Kano', 'Ibadan'],
            correctAnswer: 'Abuja',
            explanation: 'Abuja became the capital of Nigeria in 1991.',
            questionType: 'Multiple Choice',
          );
        } else if (type == 'True/False') {
          return LocalQuizQuestion(
            question: 'Sample T/F $index: Nigeria gained independence in 1960.',
            options: ['True', 'False'],
            correctAnswer: 'True',
          );
        } else {
          // For other question types
          return LocalQuizQuestion(
            question:
                'Sample question $index: What is the main purpose of an exam?',
            options: [
              'To evaluate knowledge',
              'To waste time',
              'To confuse students',
              'None of the above'
            ],
            correctAnswer: 'To evaluate knowledge',
            explanation:
                "Exams are designed to assess a student's understanding of a subject.",
            questionType: type,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white : const Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'SumQuiz',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF6B5CE7),
              ),
            ),
            Text(
              'Step 3: Review',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.file_upload_outlined,
                color: isDark ? Colors.white70 : const Color(0xFF64748B)),
            tooltip: 'Export Exam',
            onPressed: _exportExam,
          ),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF6B5CE7)),
                  const SizedBox(height: 16),
                  Text(
                    _processingMessage,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    children: [
                      // ── Header Row ──────────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Final Review',
                                  style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Read through the generated questions. Tap any question to edit.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Sumi AI Assist Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.smart_toy_outlined,
                                    size: 14, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sumi',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    ),
                                    Text(
                                      'AI Assist',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Question Cards ──────────────────────────────────────
                      ...List.generate(
                        _questions.length,
                        (index) => _buildReviewQuestionCard(index, isDark),
                      ),

                      const SizedBox(height: 16),

                      // ── + Add Question Button ──────────────────────────────
                      Center(
                        child: TextButton.icon(
                          onPressed: _addQuestion,
                          style: TextButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF3E8FF),
                            foregroundColor: const Color(0xFF6B5CE7),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            'Add Question',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // ── Sticky Bottom Action Bar ─────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFF1F5F9),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saveExam,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : const Color(0xFFE2E8F0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Save Draft',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _exportExam,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Assign or Export',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
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

  Widget _buildReviewQuestionCard(int index, bool isDark) {
    final q = _questions[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${index + 1}.  ',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                ),
              ),
              Expanded(
                child: Text(
                  q.question,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (action) {
                  if (action == 'edit') {
                    _editQuestionDialog(index);
                  } else if (action == 'regenerate') {
                    _regenerateQuestion(index);
                  } else if (action == 'delete') {
                    _deleteQuestion(index);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit question'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'regenerate',
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded,
                            size: 18, color: Color(0xFF6B5CE7)),
                        SizedBox(width: 10),
                        Text('Regenerate'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: Color(0xFFEF4444)),
                        SizedBox(width: 10),
                        Text('Delete',
                            style: TextStyle(color: Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Radio options list
          ...List.generate(
            q.options.length,
            (optIdx) {
              final optionText = q.options[optIdx];
              final isCorrect = (q.correctAnswer == optionText);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: isCorrect
                          ? const Color(0xFF6B5CE7)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        optionText,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight:
                              isCorrect ? FontWeight.w700 : FontWeight.w400,
                          color: isCorrect
                              ? (isDark ? Colors.white : const Color(0xFF1E293B))
                              : (isDark ? Colors.grey[400] : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Explanation Card (Soft purple container)
          if ((q.explanation?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF312E81).withValues(alpha: 0.3)
                    : const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF3E8FF),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outlined,
                          size: 16, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 6),
                      Text(
                        'Explanation',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q.explanation ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark
                          ? Colors.grey[300]
                          : const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF1F5F9),
          ),
        ],
      ),
    );
  }

  void _editQuestionDialog(int index) {
    final q = _questions[index];
    final qController = TextEditingController(text: q.question);
    final expController = TextEditingController(text: q.explanation);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Question ${index + 1}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Question Text',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Explanation',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _questions[index] = LocalQuizQuestion(
                  question: qController.text.trim(),
                  options: q.options,
                  correctAnswer: q.correctAnswer,
                  explanation: expController.text.trim(),
                  questionType: q.questionType,
                );
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B5CE7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _regenerateQuestion(int index) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Regenerating question ${index + 1}...';
    });

    try {
      final enhancedAIService =
          Provider.of<EnhancedAIService>(context, listen: false);
      _cancelToken = CancellationToken();

      final oldQuestion = _questions[index];
      final regeneratedQuestion = await enhancedAIService.regenerateQuestion(
        sourceText: widget.sourceMaterial,
        subject: widget.subject,
        level: widget.classLevel,
        oldQuestion: oldQuestion,
        cancelToken: _cancelToken,
      );

      setState(() {
        _questions[index] = regeneratedQuestion;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  void _deleteQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  Future<void> _saveExam() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Saving exam to library...';
    });

    try {
      final user = Provider.of<UserModel?>(context, listen: false);
      if (user == null) throw Exception('User not authenticated');

      await LocalDatabaseService().init();
      if (!mounted) return;

      final quiz = LocalQuiz(
        id: const Uuid().v4(),
        title: widget.examTitle,
        questions: _questions,
        timestamp: DateTime.now(),
        userId: user.uid,
        isSynced: false,
        isExam: true,
      );

      await LocalDatabaseService().saveQuiz(quiz);
      if (!mounted) return;

      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exam saved to library!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  void _addQuestion() {
    setState(() {
      _questions.add(LocalQuizQuestion(
        question: 'New question...',
        options: ['Option A', 'Option B', 'Option C', 'Option D'],
        correctAnswer: 'Option A',
        explanation: 'Explanation for the new question',
        questionType: 'Multiple Choice',
      ));
    });
  }

  void _exportExam() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExportOptionsScreen(
          examTitle: widget.examTitle,
          subject: widget.subject,
          classLevel: widget.classLevel,
          duration: widget.duration,
          questions: _questions,
        ),
      ),
    );
  }
}

// ─── ExportOptionsScreen (Step 4: Success & Export Modal) ───────────────────

class ExportOptionsScreen extends StatefulWidget {
  final String examTitle;
  final String subject;
  final String classLevel;
  final int duration;
  final List<LocalQuizQuestion> questions;

  const ExportOptionsScreen({
    super.key,
    required this.examTitle,
    required this.subject,
    required this.classLevel,
    required this.duration,
    required this.questions,
  });

  @override
  State<ExportOptionsScreen> createState() => _ExportOptionsScreenState();
}

class _ExportOptionsScreenState extends State<ExportOptionsScreen> {
  String _selectedFormat = 'pdf'; // 'pdf' | 'doc' | 'gdocs'
  bool _includeAnswerSheet = true;
  bool _includeMarkingScheme = false;
  bool _showSchoolLogo = true;
  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white : const Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'SumQuiz',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF6B5CE7),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: isDark ? Colors.white70 : const Color(0xFF64748B)),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF6B5CE7)),
                  const SizedBox(height: 16),
                  Text(
                    _processingMessage,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // ── Success Header ─────────────────────────────────────────
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B5CE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Success! Your exam is ready.',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Review the preview below. When you're ready, configure your export settings.",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.4,
                      color: const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // ── Document Preview Card ──────────────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Top Header Banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF312E81).withValues(alpha: 0.3)
                                : const Color(0xFFFAF5FF),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.school_outlined,
                                  size: 16, color: Color(0xFF6B5CE7)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.examTitle.isNotEmpty
                                      ? widget.examTitle
                                      : 'Midterm Examination - Biology 101',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  'Preview',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Skeleton page layout preview
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSkeletonLine(width: 160, height: 10),
                              const SizedBox(height: 8),
                              _buildSkeletonLine(width: double.infinity, height: 8),
                              const SizedBox(height: 6),
                              _buildSkeletonLine(width: double.infinity, height: 8),
                              const SizedBox(height: 6),
                              _buildSkeletonLine(width: 100, height: 8),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 10,
                                          backgroundColor:
                                              Colors.grey[300],
                                          child: Text('1',
                                              style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildSkeletonLine(
                                            width: 180, height: 8),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildSkeletonLine(width: 120, height: 6),
                                    const SizedBox(height: 6),
                                    _buildSkeletonLine(width: 80, height: 6),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── EXPORT FORMAT Section ──────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'EXPORT FORMAT',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildFormatCard(
                    id: 'pdf',
                    icon: Icons.picture_as_pdf_rounded,
                    iconBg: const Color(0xFFF3E8FF),
                    iconColor: const Color(0xFF9333EA),
                    title: 'PDF Document',
                    subtitle: 'Best for printing',
                    isSelected: _selectedFormat == 'pdf',
                    onTap: () => setState(() => _selectedFormat = 'pdf'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildFormatCard(
                    id: 'doc',
                    icon: Icons.description_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                    title: 'Word Document',
                    subtitle: 'Fully editable',
                    isSelected: _selectedFormat == 'doc',
                    onTap: () => setState(() => _selectedFormat = 'doc'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildFormatCard(
                    id: 'gdocs',
                    icon: Icons.article_rounded,
                    iconBg: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF059669),
                    title: 'Google Docs',
                    subtitle: 'Save to Drive',
                    isSelected: _selectedFormat == 'gdocs',
                    onTap: () => setState(() => _selectedFormat = 'gdocs'),
                    isDark: isDark,
                  ),

                  const SizedBox(height: 24),

                  // ── INCLUSIONS Section ─────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'INCLUSIONS',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          activeTrackColor: const Color(0xFF6B5CE7),
                          title: Text(
                            'Include Answer Sheet',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          value: _includeAnswerSheet,
                          onChanged: (val) =>
                              setState(() => _includeAnswerSheet = val),
                        ),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFF1F5F9),
                        ),
                        SwitchListTile(
                          activeTrackColor: const Color(0xFF6B5CE7),
                          title: Text(
                            'Include Marking Scheme',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          value: _includeMarkingScheme,
                          onChanged: (val) =>
                              setState(() => _includeMarkingScheme = val),
                        ),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFF1F5F9),
                        ),
                        SwitchListTile(
                          activeTrackColor: const Color(0xFF6B5CE7),
                          title: Row(
                            children: [
                              Text(
                                'Show School Logo',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.info_outline_rounded,
                                  size: 14, color: Color(0xFF94A3B8)),
                            ],
                          ),
                          value: _showSchoolLogo,
                          onChanged: (val) =>
                              setState(() => _showSchoolLogo = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Download / Share Button ────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _exportExamFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B5CE7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.upload_rounded, size: 20),
                      label: Text(
                        'Download / Share Exam',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildFormatCard({
    required String id,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6B5CE7)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected
                  ? const Color(0xFF6B5CE7)
                  : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
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

  Widget _buildSkeletonLine({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Future<void> _exportExamFile() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Preparing ${_selectedFormat.toUpperCase()} file...';
    });

    try {
      final user = Provider.of<UserModel?>(context, listen: false);
      String? shareCode;

      if (user != null) {
        shareCode = ShareCodeGenerator.generate();
        final publicDeckId = const Uuid().v4();

        final publicDeck = PublicDeck(
          id: publicDeckId,
          creatorId: user.uid,
          creatorName: user.displayName,
          title: widget.examTitle.trim().isNotEmpty
              ? widget.examTitle.trim()
              : widget.subject,
          description:
              "Practice Exam for ${widget.subject} (${widget.classLevel})",
          shareCode: shareCode,
          isExam: true,
          summaryData: {},
          quizData: {
            'title': widget.examTitle.trim().isNotEmpty
                ? widget.examTitle.trim()
                : widget.subject,
            'questions': widget.questions.map((q) => q.toMap()).toList(),
          },
          flashcardData: {},
          noteData: {},
          publishedAt: DateTime.now(),
        );

        await FirestoreService().publishDeck(publicDeck);
      }

      final pdfGenerator = ExamPdfGenerator();

      final config = ExamPdfConfig(
        schoolName: _showSchoolLogo ? 'GREENHILL ACADEMY' : 'SUMQUIZ ACADEMY',
        examTitle: widget.examTitle,
        subject: widget.subject,
        classLevel: widget.classLevel,
        durationMinutes: widget.duration,
        shareCode: shareCode,
        creatorName: user?.displayName ?? 'Educator',
        marksA: 1,
        marksB: 5,
        marksC: 10,
        includeAnswerSheet: _includeAnswerSheet,
        includeMarkingScheme: _includeMarkingScheme,
        randomizeOptions: false,
      );

      final studentPaper = pdfGenerator.generateStudentPaper(
        questions: widget.questions,
        config: config,
      );
      final bytes = await studentPaper.save();
      final fileName =
          '${widget.examTitle.replaceAll(' ', '_')}_Exam_Paper.pdf';

      if (mounted) setState(() => _isProcessing = false);

      await downloadPdf(bytes, fileName);

      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: fileName,
        );
      } catch (e) {
        debugPrint('Print layout error: $e');
      }

      if (mounted) setState(() => _isProcessing = false);
    } catch (e) {
      debugPrint('Export Error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error exporting: $e')));
      }
    }
  }
}


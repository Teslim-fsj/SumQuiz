import 'package:flutter/material.dart';
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

class ExamCreationScreen extends StatefulWidget {
  const ExamCreationScreen({super.key});

  @override
  State<ExamCreationScreen> createState() => _ExamCreationScreenState();
}

class _ExamCreationScreenState extends State<ExamCreationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _customLevelController = TextEditingController();
  String _selectedLevel = 'JSS1';
  int _numberOfQuestions = 20;
  String _duration = '60';
  bool _includeMultipleChoice = true;
  bool _includeShortAnswer = false;
  bool _includeTheory = false;
  bool _includeTrueFalse = false;
  double _difficultyValue = 0.5; // Medium difficulty by default
  bool _advancedSettings = false;
  bool _evenTopicCoverage = true;
  bool _focusWeakAreas = false;
  String _sourceMaterial = '';
  bool _showFullPreview = false;
  bool _isProcessing = false;
  String _processingMessage = '';
  CancellationToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    _titleController.dispose();
    _subjectController.dispose();
    _customLevelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<UserModel?>(context, listen: false);

    // Check if user has Pro access
    // Check if user has Pro access OR has trial exams remaining
    if (user != null && !user.isPro && user.examsGenerated >= 3) {
      // Show upgrade dialog if user is not Pro
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                'Tutor Exam feature requires Pro subscription',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Upgrade to access advanced exam creation tools',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  context.push('/settings/subscription');
                },
                child: const Text('Upgrade to Pro'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Exam'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_processingMessage),
                  const SizedBox(height: 8),
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Create New Exam',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Turn your teaching materials into an editable test paper.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (user != null && !user.isPro) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Free Trial: ${user.examsGenerated}/3 Exams Used',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                Text(
                                  'Upgrade to Pro for unlimited generation.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                  ],

                  // Basic Info Section
                  _buildSectionCard(
                    title: 'Basic Info',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Exam Title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedLevel,
                          decoration: const InputDecoration(
                            labelText: 'Class / Level',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            'JSS1',
                            'JSS2',
                            'JSS3',
                            'SS1',
                            'SS2',
                            'SS3',
                            '100 Level',
                            'Custom'
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedLevel = newValue!;
                            });
                          },
                        ),
                        if (_selectedLevel == 'Custom') ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _customLevelController,
                            decoration: const InputDecoration(
                              labelText: 'Specify Custom Class / Level',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: _subjectController,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller:
                                    TextEditingController(text: _duration),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Duration',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _duration = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text('mins'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Source Material Section
                  _buildSectionCard(
                    title: 'Source Material',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload Material',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          children: [
                            _buildUploadOption('PDF', Icons.picture_as_pdf, () {
                              _selectSourceMaterial('PDF');
                            }),
                            _buildUploadOption('Scan / Image', Icons.image, () {
                              _selectSourceMaterial('Image');
                            }),
                            _buildUploadOption('Notes', Icons.note_alt, () {
                              _selectSourceMaterial('Notes');
                            }),
                            _buildUploadOption('YouTube', Icons.play_circle_fill, () {
                              if (!userMayImportFromYouTube(user)) {
                                showDialog<void>(
                                  context: context,
                                  builder: (_) => const UpgradeDialog(
                                    featureName: 'YouTube import',
                                  ),
                                );
                                return;
                              }
                              _selectSourceMaterial('YouTube');
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_sourceMaterial.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: Colors.green),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Extracted content preview',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _showFullPreview
                                      ? _sourceMaterial
                                      : '${_sourceMaterial.substring(0, _sourceMaterial.length > 100 ? 100 : _sourceMaterial.length)}...',
                                  maxLines: _showFullPreview ? null : 3,
                                  style: theme.textTheme.bodySmall,
                                ),
                                if (_sourceMaterial.length > 100) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _showFullPreview = !_showFullPreview;
                                      });
                                    },
                                    child: Text(_showFullPreview
                                        ? 'Show Less'
                                        : 'View Full'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Question Settings Section
                  _buildSectionCard(
                    title: 'Question Settings',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Number of Questions
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Number of Questions',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_numberOfQuestions',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: _numberOfQuestions.toDouble(),
                          min: 5,
                          max: 50,
                          divisions: 45,
                          label: _numberOfQuestions.round().toString(),
                          onChanged: (double value) {
                            setState(() {
                              _numberOfQuestions = value.round();
                            });
                          },
                        ),

                        const SizedBox(height: 24),

                        // Question Types
                        Text(
                          'Question Types',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          children: [
                            FilterChip(
                              label: const Text('Multiple Choice'),
                              selected: _includeMultipleChoice,
                              onSelected: (selected) {
                                setState(() {
                                  _includeMultipleChoice = selected;
                                });
                              },
                            ),
                            FilterChip(
                              label: const Text('Short Answer'),
                              selected: _includeShortAnswer,
                              onSelected: (selected) {
                                setState(() {
                                  _includeShortAnswer = selected;
                                });
                              },
                            ),
                            FilterChip(
                              label: const Text('Theory / Essay'),
                              selected: _includeTheory,
                              onSelected: (selected) {
                                setState(() {
                                  _includeTheory = selected;
                                });
                              },
                            ),
                            FilterChip(
                              label: const Text('True/False'),
                              selected: _includeTrueFalse,
                              onSelected: (selected) {
                                setState(() {
                                  _includeTrueFalse = selected;
                                });
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Difficulty Mix
                        Text(
                          'Difficulty Mix',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Easy',
                              style: theme.textTheme.bodySmall,
                            ),
                            Expanded(
                              child: Slider(
                                value: _difficultyValue,
                                min: 0.0,
                                max: 1.0,
                                label: '${(_difficultyValue * 100).round()}%',
                                onChanged: (double value) {
                                  setState(() {
                                    _difficultyValue = value;
                                  });
                                },
                              ),
                            ),
                            Text(
                              'Hard',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              'Easy ${(100 - (_difficultyValue * 100)).round()}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _difficultyValue < 0.5
                                    ? theme.colorScheme.primary
                                    : theme.disabledColor,
                              ),
                            ),
                            Text(
                              'Medium ${((_difficultyValue * 100) - 50).abs().round()}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: (_difficultyValue >= 0.4 &&
                                        _difficultyValue <= 0.6)
                                    ? theme.colorScheme.primary
                                    : theme.disabledColor,
                              ),
                            ),
                            Text(
                              'Hard ${(_difficultyValue * 100).round()}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _difficultyValue > 0.5
                                    ? theme.colorScheme.primary
                                    : theme.disabledColor,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Advanced Settings Toggle
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _advancedSettings = !_advancedSettings;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Advanced Settings',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _advancedSettings
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                            ],
                          ),
                        ),

                        if (_advancedSettings) ...[
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            title: const Text('Generate evenly across topics'),
                            value: _evenTopicCoverage,
                            onChanged: (bool? value) {
                              setState(() {
                                _evenTopicCoverage = value!;
                              });
                            },
                          ),
                          CheckboxListTile(
                            title:
                                const Text('Focus on weak / highlighted areas'),
                            value: _focusWeakAreas,
                            onChanged: (bool? value) {
                              setState(() {
                                _focusWeakAreas = value!;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Generate Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Consumer<UserModel?>(
                      builder: (context, user, child) {
                        final bool isLimitReached = user != null && !user.isPro && user.examsGenerated >= 3;
                        
                        return ElevatedButton.icon(
                          onPressed: (isLimitReached || _sourceMaterial.isEmpty)
                              ? (isLimitReached ? () => context.push('/settings/subscription') : null)
                              : _generateDraftExam,
                          icon: Icon(isLimitReached ? Icons.workspace_premium : Icons.auto_awesome),
                          label: Text(
                            isLimitReached ? 'Upgrade to Pro' : 'Generate Draft Exam',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLimitReached ? theme.colorScheme.tertiary : theme.colorScheme.primary,
                            foregroundColor: isLimitReached ? theme.colorScheme.onTertiary : theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Editable before export.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption(String title, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectSourceMaterial(String type) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Selecting $type...';
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
        setState(() => _isProcessing = false);
        _showYoutubeInputDialog();
        return;
      } else if (type == 'Notes') {
        setState(() => _isProcessing = false);
        _showNotesInputDialog();
        return;
      } else if (type == 'Audio') {
        fileType = FileType.audio;
      }

      result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        withData: true,
        allowMultiple: true, 
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        setState(() => _isProcessing = true);
        final user = Provider.of<UserModel?>(context, listen: false);
        final enhancedAiService = Provider.of<EnhancedAIService>(context, listen: false);
        final extractionService = ContentExtractionService(enhancedAiService);
        _cancelToken = CancellationToken();

        String combinedText = '';

        for (int i = 0; i < result.files.length; i++) {
          final file = result.files[i];
          final bytes = file.bytes;
          final name = file.name;

          if (bytes != null) {
            setState(() => _processingMessage = 'Extracting content from $name (${i + 1}/${result!.files.length})...');
            
            final extractionResult = await extractionService.extractContent(
              type: type.toLowerCase(),
              input: bytes,
              userId: user?.uid,
              mimeType: type == 'PDF' ? 'application/pdf' : 'image/jpeg',
              allowYouTubeImport: userMayImportFromYouTube(user),
              onProgress: (msg) {
                if (mounted) setState(() => _processingMessage = msg);
              },
              cancelToken: _cancelToken,
            );

            if (!mounted) return;
            if (combinedText.isNotEmpty) {
               combinedText += '\n\n--- Source: $name ---\n\n';
            }
            combinedText += extractionResult.text;
          }
        }

        if (!mounted) return;
        setState(() {
          _sourceMaterial = combinedText;
          _isProcessing = false;
        });
      } else {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error extracting content: $e'),
              backgroundColor: Colors.red),
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
                  setState(() => _sourceMaterial = text);
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
        builder: (_) =>
            const UpgradeDialog(featureName: 'YouTube import'),
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
    if (_titleController.text.isEmpty || _subjectController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in the exam title and subject'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Generating exam questions...';
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

      // Check if question types are selected
      if (questionTypes.isEmpty) {
        throw Exception('Please select at least one question type');
      }

      // Generate the exam using AI service
      _cancelToken = CancellationToken();

      final quiz = await enhancedAIService.generateExam(
        text: _sourceMaterial,
        title: _titleController.text,
        subject: _subjectController.text,
        level: _selectedLevel == 'Custom' ? _customLevelController.text : _selectedLevel,
        questionCount: _numberOfQuestions,
        questionTypes: questionTypes,
        difficultyMix: _difficultyValue,
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
              examTitle: _titleController.text,
              subject: _subjectController.text,
              classLevel: _selectedLevel == 'Custom' ? _customLevelController.text : _selectedLevel,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveExam,
            tooltip: 'Save to Library',
          ),
          TextButton(
            onPressed: _exportExam,
            child: const Text('Export Exam'),
          ),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_processingMessage),
                ],
              ),
            )
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  // Top bar with exam info
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: theme.cardColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.examTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Total Questions: ${_questions.length}',
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                'Estimated Duration: ${widget.duration} mins',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addQuestion,
                          tooltip: 'Add Question',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Questions list
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: List.generate(
                        _questions.length,
                        (index) => _buildQuestionCard(index),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final theme = Theme.of(context);
    final question = _questions[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Q${index + 1}. (MCQ)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editQuestion(index),
                  tooltip: 'Edit',
                  color: theme.colorScheme.primary,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _regenerateQuestion(index),
                  tooltip: 'Regenerate',
                  color: theme.colorScheme.secondary,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteQuestion(index),
                  tooltip: 'Delete',
                  color: theme.colorScheme.error,
                ),
              ],
            ),
            TextFormField(
              initialValue: question.question,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _questions[index] = LocalQuizQuestion(
                    question: value,
                    options: question.options,
                    correctAnswer: question.correctAnswer,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: question.correctAnswer,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _questions[index] = LocalQuizQuestion(
                      question: question.question,
                      options: question.options,
                      correctAnswer: value,
                    );
                  });
                }
              },
              child: Column(
                children: List.generate(
              question.options.length,
              (optionIndex) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Radio<String>(
                      value: question.options[optionIndex],
                      groupValue: question.correctAnswer,
                      onChanged: (value) {
                        setState(() {
                          _questions[index] = LocalQuizQuestion(
                            question: question.question,
                            options: question.options,
                            correctAnswer: value!,
                          );
                        });
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: question.options[optionIndex],
                        decoration: InputDecoration(
                          labelText:
                              'Option ${String.fromCharCode(65 + optionIndex)}',
                          border: const OutlineInputBorder(),
                          suffixIcon: question.correctAnswer ==
                                  question.options[optionIndex]
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : null,
                        ),
                        onChanged: (value) {
                          final newOptions =
                              List<String>.from(question.options);
                          newOptions[optionIndex] = value;

                          // Update correct answer if it was this option
                          String newCorrectAnswer = question.correctAnswer;
                          if (question.correctAnswer ==
                              question.options[optionIndex]) {
                            newCorrectAnswer = value;
                          }

                          setState(() {
                            _questions[index] = LocalQuizQuestion(
                              question: question.question,
                              options: newOptions,
                              correctAnswer: newCorrectAnswer,
                              explanation: question.explanation,
                              questionType: question.questionType,
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
              initialValue: question.explanation,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: 'Explanation (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _questions[index] = LocalQuizQuestion(
                    question: question.question,
                    options: question.options,
                    correctAnswer: question.correctAnswer,
                    explanation: value,
                    questionType: question.questionType,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editQuestion(int index) {
    // In a real implementation, this might open a detailed edit dialog
    // For now, the inline editing is already available in the card
    debugPrint('Editing question $index');
  }

  Future<void> _regenerateQuestion(int index) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Regenerating question ${index + 1}...';
    });

    try {
      final enhancedAIService = Provider.of<EnhancedAIService>(context, listen: false);
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question regenerated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error regenerating question: $e');
      debugPrint('Stack trace: $stackTrace');

      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating question: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Question deleted'),
        backgroundColor: Colors.orange,
      ),
    );
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
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error saving exam: $e');
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error saving exam'), backgroundColor: Colors.red),
        );
      }
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New question added'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _exportExam() {
    // Navigate to export options screen
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
  bool _includeAnswerSheet = false;
  bool _includeMarkingScheme = false;
  bool _randomizeQuestionOrder = false;
  bool _randomizeOptions = false;
  bool _isProcessing = false;
  String _processingMessage = '';

  // New Header & Marks Info
  final _schoolNameController = TextEditingController();
  int _marksA = 1;
  int _marksB = 5;
  int _marksC = 10;

  @override
  void dispose() {
    _schoolNameController.dispose();
    super.dispose();
  }

  int get _totalMarks {
    int total = 0;
    for (var q in widget.questions) {
      if (q.questionType == 'Multiple Choice' ||
          q.questionType == 'True/False') {
        total += _marksA;
      } else if (q.questionType == 'Short Answer') {
        total += _marksB;
      } else {
        total += _marksC;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Exam'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_processingMessage),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  'Professional structure for printable exams.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),

                // 1. Header Information
                _buildSectionCard(
                  title: 'Exam Header',
                  child: Column(
                    children: [
                      TextField(
                        controller: _schoolNameController,
                        decoration: const InputDecoration(
                          labelText: 'School Name',
                          hintText: 'e.g. Greenhill International Academy',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Marks Allocation
                _buildSectionCard(
                  title: 'Marks Allocation',
                  child: Column(
                    children: [
                      _buildMarkInput(
                        'Section A (MCQ / T&F)',
                        _marksA,
                        (val) => setState(() => _marksA = val),
                      ),
                      const Divider(),
                      _buildMarkInput(
                        'Section B (Short Answer)',
                        _marksB,
                        (val) => setState(() => _marksB = val),
                      ),
                      const Divider(),
                      _buildMarkInput(
                        'Section C (Theory / Essay)',
                        _marksC,
                        (val) => setState(() => _marksC = val),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL MARKS:',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              '$_totalMarks',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Document Settings
                _buildSectionCard(
                  title: 'Document Settings',
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Include answer sheet'),
                        subtitle:
                            const Text('Separate page with correct options'),
                        value: _includeAnswerSheet,
                        onChanged: (bool? value) {
                          setState(() {
                            _includeAnswerSheet = value!;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Include marking scheme'),
                        subtitle:
                            const Text('Detailed explanations for answers'),
                        value: _includeMarkingScheme,
                        onChanged: (bool? value) {
                          setState(() {
                            _includeMarkingScheme = value!;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Randomize question order'),
                        value: _randomizeQuestionOrder,
                        onChanged: (bool? value) {
                          setState(() {
                            _randomizeQuestionOrder = value!;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Randomize options'),
                        value: _randomizeOptions,
                        onChanged: (bool? value) {
                          setState(() {
                            _randomizeOptions = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Download PDF button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _downloadPdf,
                    icon: const Icon(Icons.download),
                    label: const Text(
                      'Download PDF',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildMarkInput(String label, int value, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: value > 0 ? () => onChanged(value - 1) : null,
              ),
              Text('$value',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Generating Professional Exam Paper...';
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
          title: widget.subject,
          description:
              "Practice Exam for ${widget.subject} ${widget.classLevel}",
          shareCode: shareCode,
          summaryData: {},
          quizData: {
            'questions': widget.questions.map((q) => q.toMap()).toList(),
          },
          flashcardData: {},
          publishedAt: DateTime.now(),
        );

        await FirestoreService().publishDeck(publicDeck);
      }

      final pdfGenerator = ExamPdfGenerator();
      final schoolName = _schoolNameController.text.trim().isEmpty
          ? 'SUMQUIZ ACADEMY'
          : _schoolNameController.text.trim().toUpperCase();

      // Process questions for randomization
      var allQuestions = List<LocalQuizQuestion>.from(widget.questions);
      if (_randomizeQuestionOrder) allQuestions.shuffle();

      final config = ExamPdfConfig(
        schoolName: schoolName,
        examTitle: widget.examTitle,
        subject: widget.subject,
        classLevel: widget.classLevel,
        durationMinutes: widget.duration,
        shareCode: shareCode,
        marksA: _marksA,
        marksB: _marksB,
        marksC: _marksC,
        includeAnswerSheet: _includeAnswerSheet,
        includeMarkingScheme: _includeMarkingScheme,
        randomizeOptions: _randomizeOptions,
      );

      final studentPaper = pdfGenerator.generateStudentPaper(
        questions: allQuestions,
        config: config,
      );
      final bytes = await studentPaper.save();

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: '${widget.examTitle.replaceAll(' ', '_')}_Exam_Paper.pdf',
      );

      try {
        await Printing.sharePdf(
          bytes: bytes,
          filename: '${widget.examTitle.replaceAll(' ', '_')}_Exam_Paper.pdf',
        );
      } catch (e) {
        debugPrint('Web download fallback error: $e');
      }

      if (mounted) setState(() => _isProcessing = false);
    } catch (e) {
      debugPrint('PDF Export Error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
      }
    }
  }

  // PDF generation is now handled by ExamPdfGenerator service.
}

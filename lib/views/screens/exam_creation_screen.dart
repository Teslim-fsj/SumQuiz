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
  final ImagePicker _imagePicker = ImagePicker();
  // ignore: unused_field - reserved for future multi-file source support
  // final List<Map<String, dynamic>> _selectedSourceFiles = [];
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
    // Check if user has Pro access OR has trial exams remaining OR is a teacher
    if (user != null &&
        !user.isPro &&
        user.role != UserRole.creator &&
        user.examsGenerated >= 3) {
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (user != null && !user.isPro) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome,
                              color: theme.colorScheme.primary, size: 20),
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
                                    color: theme.colorScheme.onPrimaryContainer
                                        .withValues(alpha: 0.8),
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
                            _buildUploadOption('Scan / Image', Icons.camera_alt,
                                () {
                              _showImageSourceSelection();
                            }),
                            _buildUploadOption('Notes', Icons.note_alt, () {
                              _selectSourceMaterial('Notes');
                            }),
                            _buildUploadOption(
                                'YouTube', Icons.play_circle_fill, () {
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
                        final bool isLimitReached = user != null &&
                            !user.isPro &&
                            user.examsGenerated >= 3;

                        return ElevatedButton.icon(
                          onPressed: (isLimitReached || _sourceMaterial.isEmpty)
                              ? (isLimitReached
                                  ? () => context.push('/settings/subscription')
                                  : null)
                              : _generateDraftExam,
                          icon: Icon(isLimitReached
                              ? Icons.workspace_premium
                              : Icons.auto_awesome),
                          label: Text(
                            isLimitReached
                                ? 'Upgrade to Pro'
                                : 'Generate Draft Exam',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLimitReached
                                ? theme.colorScheme.tertiary
                                : theme.colorScheme.primary,
                            foregroundColor: isLimitReached
                                ? theme.colorScheme.onTertiary
                                : theme.colorScheme.onPrimary,
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
            color: Colors.black.withValues(alpha: 0.05),
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
              examTitle: _titleController.text,
              subject: _subjectController.text,
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
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    size: 18, color: Color(0xFF6B5CE7)),
                tooltip: 'Regenerate',
                onPressed: () => _regenerateQuestion(index),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Color(0xFFEF4444)),
                tooltip: 'Delete',
                onPressed: () => _deleteQuestion(index),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: Color(0xFF64748B)),
                tooltip: 'Edit',
                onPressed: () => _editQuestionDialog(index),
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
          title: widget.subject,
          description:
              "Practice Exam for ${widget.subject} ${widget.classLevel}",
          shareCode: shareCode,
          summaryData: {},
          quizData: {
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


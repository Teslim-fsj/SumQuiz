import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/note_provider.dart';
import '../../providers/sumi_provider.dart';
import '../../models/user_model.dart';
import '../../services/mastery_service.dart';
import '../widgets/handwriting_canvas.dart';
import '../widgets/sumi_lens.dart';
import '../widgets/ghost_link.dart';
import '../widgets/catch_up_widget.dart';
import '../../services/transcript_recovery_service.dart';
import '../widgets/recording_bar_widget.dart';
import '../widgets/aura_alert_banner.dart';

class NoteEditorScreen extends StatefulWidget {
  final String noteId;
  final String? folderId;
  const NoteEditorScreen({super.key, required this.noteId, this.folderId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late quill.QuillController _controller;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  
  bool _isDrawingMode = false;
  bool _isInitialized = false;
  bool _showSidebar = true;
  Offset? _lensPosition;
  
  StreamSubscription<String>? _transcriptSub;

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController.basic();
    final noteProvider = context.read<NoteProvider>();
    final user = Provider.of<UserModel?>(context, listen: false);

    if (widget.noteId == 'new') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final uri = GoRouterState.of(context).uri;
        await noteProvider.createNewNote(user?.uid ?? '');
        if (mounted) {
          if (uri.queryParameters['startRecording'] == 'true') {
            noteProvider.startRecording(user?.uid ?? '');
          }
          setState(() {
            _isInitialized = true;
          });
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadNote();
      });
    }

    _titleController.addListener(_onTitleChanged);
    _controller.addListener(_onContentChanged);
    _controller.onSelectionChanged = _handleSelectionChanged;

    _transcriptSub = noteProvider.transcriptChunkStream.listen((text) {
      if (mounted && text.isNotEmpty) {
        _appendLiveText(text);
      }
    });
  }

  void _handleSelectionChanged(TextSelection selection) {
    if (selection.isCollapsed) {
      if (_lensPosition != null) setState(() => _lensPosition = null);
      return;
    }
    setState(() {
      _lensPosition = const Offset(150, 400);
    });
  }

  void _appendLiveText(String text) {
    final length = _controller.document.length;
    final insertionIndex = length > 0 ? length - 1 : 0;
    
    final List<String> keywords = ['mitochondria', 'energy', 'atp', 'cell', 'nucleus', 'important', 'exam'];
    bool isKeyword = keywords.any((k) => text.toLowerCase().contains(k));
    
    String textToInsert = text;
    if (insertionIndex > 0) {
      final lastChar = _controller.document.toPlainText().substring(insertionIndex - 1, insertionIndex);
      if (lastChar != ' ' && lastChar != '\n') {
        textToInsert = ' $text';
      }
    }
    
    _controller.document.insert(insertionIndex, textToInsert);
    
    if (isKeyword) {
      _controller.formatText(
        insertionIndex, 
        textToInsert.length, 
        quill.Attribute.clone(quill.Attribute.color, Colors.orangeAccent.toARGB32().toRadixString(16))
      );
    }
    
    final isAtEnd = _controller.selection.extentOffset >= length - 1;
    if (isAtEnd) {
      _controller.updateSelection(
        TextSelection.collapsed(offset: _controller.document.length - 1),
        quill.ChangeSource.local,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _loadNote() async {
    final provider = context.read<NoteProvider>();
    await provider.loadNote(widget.noteId);
    final note = provider.currentNote;

    if (note != null) {
      _titleController.text = note.title;

      if (!mounted) return;
      final user = Provider.of<UserModel?>(context, listen: false);
      final mastery = Provider.of<MasteryService>(context, listen: false);
      if (user != null && note.topicIds.isNotEmpty) {
        for (final topicId in note.topicIds) {
          mastery.processSignal(LearningSignal(
            topicId: topicId,
            type: SignalType.noteReread,
            timestamp: DateTime.now(),
          ));
        }
      }

      if (note.content.isNotEmpty) {
        try {
          final doc = quill.Document.fromJson(jsonDecode(note.content));
          _controller = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
          _controller.addListener(_onContentChanged);
          _controller.onSelectionChanged = _handleSelectionChanged;
        } catch (e) {
          _controller.document.insert(0, note.content);
        }
      }
      setState(() {
        _isInitialized = true;
      });

      final recovered = await TranscriptRecoveryService().getRecoveredTranscript(note.id);
      if (recovered != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Found unsaved transcript from previous session.'),
            action: SnackBarAction(
              label: 'RESTORE',
              onPressed: () {
                _appendLiveText('\n[RECOVERED]: $recovered\n');
                TranscriptRecoveryService().clearRecovery(note.id);
              },
            ),
            duration: const Duration(seconds: 10),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
  }

  void _onTitleChanged() {
    if (!_isInitialized) return;
    context.read<NoteProvider>().updateNoteTitle(_titleController.text);
  }

  void _onContentChanged() {
    if (!_isInitialized) return;
    final json = jsonEncode(_controller.document.toDelta().toJson());
    context.read<NoteProvider>().updateNoteContent(json);
  }

  Future<void> _insertImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final String path = image.path;
      final int index = _controller.selection.baseOffset;
      final int length = _controller.selection.extentOffset - index;
      _controller.replaceText(index, length, quill.BlockEmbed.image(path), null);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _editorFocusNode.dispose();
    _transcriptSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noteProvider = context.watch<NoteProvider>();
    final user = Provider.of<UserModel?>(context);
    final isRecording = noteProvider.state == NoteProcessingState.recording;

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: colorScheme.surface, 
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary))
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            if (noteProvider.errorMessage.isNotEmpty)
              AuraAlertBanner(
                title: "Neural Disruption",
                description: noteProvider.errorMessage,
                onIgnore: () => noteProvider.clearError(),
                actionLabel: "DISMISS",
                onAction: () => noteProvider.clearError(),
              ),
            _buildTopBar(noteProvider, isRecording, user, theme),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        _buildEditorArea(noteProvider, theme),
                        if (_lensPosition != null)
                          SumiLensMenu(
                            position: _lensPosition!,
                            onAction: (action) async {
                              final selection = _controller.selection;
                              if (selection.isCollapsed) {
                                setState(() => _lensPosition = null);
                                return;
                              }

                              final selectedText = _controller.document.toPlainText().substring(selection.start, selection.end);
                              final sumi = context.read<SumiProvider>();
                              
                              setState(() => _lensPosition = null);

                              if (action == 'Simplify') {
                                sumi.askSumi("Simplify this: $selectedText");
                              } else if (action == 'Explain') {
                                sumi.askSumi("Explain this concepts: $selectedText");
                              } else if (action == 'Deep Dive') {
                                sumi.askSumi("Give me a deep dive on: $selectedText");
                              } else if (action == 'Quiz') {
                                sumi.askSumi("Quiz me on this: $selectedText");
                              }
                            },
                          ),
                        if (isRecording && noteProvider.liveInsights.isNotEmpty)
                          Positioned(
                            right: 20,
                            bottom: 20,
                            child: CatchUpWidget(
                              missedConcepts: noteProvider.liveInsights.take(3).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_showSidebar)
                    _buildRightSidebar(noteProvider, theme),
                ],
              ),
            ),
            const RecordingBarWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(NoteProvider noteProvider, bool isRecording, UserModel? user, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: colorScheme.onSurface),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _titleController,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Untitled Note',
                border: InputBorder.none,
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
            ),
          ),
          if (isRecording)
            _buildCaptureBadge(theme),
          const SizedBox(width: 16),
          _buildTopAction(Icons.draw_rounded, 'Sketch', () {
            setState(() => _isDrawingMode = !_isDrawingMode);
          }, theme, isActive: _isDrawingMode),
          const SizedBox(width: 12),
          _buildTopAction(Icons.add_photo_alternate_rounded, 'Diagram', _insertImage, theme),
          const SizedBox(width: 12),
          _buildTopAction(
            noteProvider.state == NoteProcessingState.generating 
              ? Icons.hourglass_empty_rounded 
              : Icons.auto_awesome_rounded, 
            noteProvider.state == NoteProcessingState.generating ? 'Processing...' : 'Synthesize', 
            () async {
              if (user != null && noteProvider.state != NoteProcessingState.generating) {
                final folderId = await noteProvider.generateStudyMaterials(user.uid);
                if (folderId != null && mounted) {
                  context.pushNamed('results-view', pathParameters: {'folderId': folderId});
                }
              }
            }, 
            theme,
            isActive: noteProvider.state == NoteProcessingState.generating,
            activeColor: colorScheme.tertiary,
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => setState(() => _showSidebar = !_showSidebar),
            icon: Icon(
              _showSidebar ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded, 
              color: colorScheme.onSurfaceVariant
            ),
            style: IconButton.styleFrom(
              backgroundColor: _showSidebar ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle),
          ).animate(onPlay: (c) => c.repeat()).fadeIn().fadeOut(),
          const SizedBox(width: 8),
          Text(
            'LIVE RECORDING',
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAction(IconData icon, String? label, VoidCallback onTap, ThemeData theme, {bool isActive = false, Color? activeColor}) {
    final colorScheme = theme.colorScheme;
    final color = activeColor ?? colorScheme.primary;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? color : colorScheme.onSurfaceVariant),
            if (label != null) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14, 
                  fontWeight: FontWeight.w600, 
                  color: isActive ? color : colorScheme.onSurfaceVariant
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditorArea(NoteProvider provider, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    return Container(
      color: colorScheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: quill.QuillEditor.basic(
              controller: _controller,
              scrollController: _scrollController,
              config: quill.QuillEditorConfig(
                autoFocus: true,
                padding: const EdgeInsets.all(40),
                placeholder: 'Start typing, recording, or sketching...',
                embedBuilders: [
                  ImageEmbedBuilder(),
                ],
                customStyles: quill.DefaultStyles(
                  paragraph: quill.DefaultTextBlockStyle(
                    GoogleFonts.inter(
                      fontSize: 16, 
                      height: 1.8, 
                      color: colorScheme.onSurface
                    ),
                    const quill.HorizontalSpacing(0, 0),
                    const quill.VerticalSpacing(0, 0),
                    const quill.VerticalSpacing(0, 0),
                    null,
                  ),
                  h1: quill.DefaultTextBlockStyle(
                    GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(16, 0), const quill.VerticalSpacing(0, 0), null,
                  ),
                  h2: quill.DefaultTextBlockStyle(
                    GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(12, 0), const quill.VerticalSpacing(0, 0), null,
                  ),
                ),
              ),
            ),
          ),
          if (_isDrawingMode)
            Positioned.fill(
              child: HandwritingCanvas(
                strokes: provider.drawingStrokes,
                onStrokeComplete: (stroke) => provider.addDrawingStroke(stroke),
                currentAudioTime: provider.recordingDuration,
                onStrokeTap: (time) => provider.seekAudio(time),
              ),
            ),
          Positioned(
            top: 24,
            right: 24,
            child: GhostLinkIndicator(label: 'Related Concepts', onTap: () {}),
          ),
        ],
      ),
    );
  }

  Widget _buildRightSidebar(NoteProvider provider, ThemeData theme) {
    final sumi = context.watch<SumiProvider>();
    final note = provider.currentNote;
    final colorScheme = theme.colorScheme;
    
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(left: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1))),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSidebarSection('TOPICS & ENTITIES', note?.topicNames ?? [], theme),
          const SizedBox(height: 32),
          _buildInsightCard(sumi, theme),
          const SizedBox(height: 32),
          _buildRecordingsList(provider, theme),
        ],
      ),
    );
  }

  Widget _buildRecordingsList(NoteProvider provider, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AUDIO SESSIONS',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11, 
            fontWeight: FontWeight.bold, 
            color: colorScheme.onSurfaceVariant, 
            letterSpacing: 1.2
          ),
        ),
        const SizedBox(height: 16),
        if (provider.currentNoteRecordings.isEmpty)
          Text('No recordings yet.', style: GoogleFonts.inter(fontSize: 13, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontStyle: FontStyle.italic)),
        ...provider.currentNoteRecordings.map((rec) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                onPressed: () => provider.playRecording(rec),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recording ${rec.createdAt.day}/${rec.createdAt.month}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                    Text(
                      '${rec.durationSeconds}s • ${rec.createdAt.hour}:${rec.createdAt.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: () => provider.deleteRecording(rec.id),
                color: colorScheme.error.withValues(alpha: 0.8),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildSidebarSection(String title, List<String> items, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11, 
            fontWeight: FontWeight.bold, 
            color: colorScheme.onSurfaceVariant, 
            letterSpacing: 1.2
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Text('Extracting context...', style: GoogleFonts.inter(fontSize: 13, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontStyle: FontStyle.italic)),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.tag_rounded, size: 10, color: colorScheme.tertiary),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(item, style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurface))),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildInsightCard(SumiProvider sumi, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                'AI ASSISTANT', 
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.secondary)
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sumi.isStreaming 
              ? (sumi.streamingMessage ?? 'Thinking...') 
              : (sumi.dialogue ?? 'I am monitoring your notes to provide real-time insights.'),
            style: GoogleFonts.inter(fontSize: 13, color: colorScheme.onSurface, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class ImageEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(
    BuildContext context,
    quill.EmbedContext embedContext,
  ) {
    final imageUrl = embedContext.node.value.data;
    if (imageUrl == null || imageUrl.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    
    final String urlStr = imageUrl.toString();
    if (kIsWeb || urlStr.startsWith('http') || urlStr.startsWith('blob:')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            urlStr,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.red),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            io.File(urlStr),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.red),
          ),
        ),
      );
    }
  }
}

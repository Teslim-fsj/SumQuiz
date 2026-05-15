import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/note_provider.dart';
import '../../providers/sumi_provider.dart';
import '../../models/user_model.dart';
import '../../services/mastery_service.dart';
import '../widgets/handwriting_canvas.dart';
import '../widgets/aura_waveform.dart';
import '../widgets/sumi_lens.dart';
import '../widgets/ghost_link.dart';
import '../widgets/catch_up_widget.dart';
import '../../models/local_note.dart';
import '../../services/transcript_recovery_service.dart';

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

    // Listen for live transcription chunks
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
    
    // Semantic Stream Highlight Logic (Mocked)
    final List<String> keywords = ['mitochondria', 'energy', 'atp', 'cell', 'nucleus'];
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
        quill.Attribute.clone(quill.Attribute.color, Colors.orangeAccent.value.toRadixString(16))
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

      // Check for recovered transcript after a crash
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
    context.read<SumiProvider>().setFocusedMode(true);
  }

  void _onContentChanged() {
    if (!_isInitialized) return;
    final json = jsonEncode(_controller.document.toDelta().toJson());
    context.read<NoteProvider>().updateNoteContent(json);
    context.read<SumiProvider>().setFocusedMode(true);
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
        backgroundColor: theme.scaffoldBackgroundColor, 
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary))
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 80),
                    Expanded(
                      child: _buildEditorArea(noteProvider, theme),
                    ),
                  ],
                ),
              ),
              if (_showSidebar)
                _buildRightSidebar(noteProvider, theme),
            ],
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: _buildTopBar(noteProvider, isRecording, user, theme),
          ),
          if (isRecording)
            Positioned(
              bottom: 40,
              left: 40,
              right: 40,
              child: AuraWaveform(
                isRecording: isRecording,
                tone: AuraTone.analytical,
                amplitudeStream: noteProvider.amplitudeStream,
              ),
            ),
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
              bottom: 120,
              child: CatchUpWidget(
                missedConcepts: noteProvider.liveInsights.take(3).toList(),
              ),
            ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: _buildRecordingButton(noteProvider, user, isRecording, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(NoteProvider noteProvider, bool isRecording, UserModel? user, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: Icon(Icons.arrow_back_ios_new, size: 18, color: theme.textTheme.bodyLarge?.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.displayLarge?.color,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Note Title',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: theme.hintColor),
                  ),
                ),
              ),
              if (isRecording)
                _buildCaptureBadge(theme),
              const SizedBox(width: 12),
              _buildMemoryBadge(theme),
              const SizedBox(width: 12),
              _buildTopAction(Icons.draw_outlined, 'Sketch', () {
                setState(() => _isDrawingMode = !_isDrawingMode);
              }, theme, isActive: _isDrawingMode),
              const SizedBox(width: 8),
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
                isActive: noteProvider.state == NoteProcessingState.generating
              ),
              const SizedBox(width: 8),
              _buildTopAction(Icons.view_sidebar_rounded, null, () {
                setState(() => _showSidebar = !_showSidebar);
              }, theme),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                child: user?.photoUrl == null ? Icon(Icons.person, size: 18, color: colorScheme.onPrimaryContainer) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ).animate(onPlay: (c) => c.repeat()).fadeIn().fadeOut(),
          const SizedBox(width: 8),
          Text(
            'LIVE',
            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryBadge(ThemeData theme) {
    final mastery = context.watch<MasteryService>();
    final note = context.read<NoteProvider>().currentNote;
    
    double averageMastery = 0.0;
    if (note != null && note.topicIds.isNotEmpty) {
      double total = 0;
      for (final id in note.topicIds) {
        total += mastery.getTopicMastery(id);
      }
      averageMastery = total / note.topicIds.length;
    }

    final isStable = averageMastery > 0.7;
    final color = isStable ? Colors.green : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isStable ? Icons.check_circle_outline : Icons.trending_up_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            isStable ? 'STABLE' : 'GROWING',
            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAction(IconData icon, String? label, VoidCallback onTap, ThemeData theme, {bool isActive = false}) {
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? colorScheme.primary : theme.iconTheme.color?.withValues(alpha: 0.7)),
            if (label != null) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13, 
                  fontWeight: FontWeight.w600, 
                  color: isActive ? colorScheme.primary : theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7)
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditorArea(NoteProvider provider, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: _isDrawingMode
          ? HandwritingCanvas(
              strokes: provider.drawingStrokes,
              onStrokeComplete: (stroke) => provider.addDrawingStroke(stroke),
              currentAudioTime: provider.recordingDuration,
              onStrokeTap: (time) => provider.seekAudio(time),
            )
          : Stack(
              children: [
                quill.QuillEditor.basic(
                  controller: _controller,
                  scrollController: _scrollController,
                  config: quill.QuillEditorConfig(
                    autoFocus: true,
                    padding: const EdgeInsets.only(bottom: 200, top: 20),
                    placeholder: 'Capture your thoughts...',
                    customStyles: quill.DefaultStyles(
                      paragraph: quill.DefaultListBlockStyle(
                        GoogleFonts.inter(
                          fontSize: 16, 
                          height: 1.6, 
                          color: theme.textTheme.bodyLarge?.color
                        ),
                        const quill.HorizontalSpacing(0, 0),
                        const quill.VerticalSpacing(0, 0),
                        const quill.VerticalSpacing(0, 0),
                        null,
                        null,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 0,
                  child: GhostLinkIndicator(label: 'Related Concepts', onTap: () {}),
                ),
              ],
            ),
    );
  }

  Widget _buildRightSidebar(NoteProvider provider, ThemeData theme) {
    final sumi = context.watch<SumiProvider>();
    final note = provider.currentNote;
    
    return Container(
      width: 340,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
        color: theme.cardColor.withValues(alpha: 0.5),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          _buildSidebarSection('TOPICS', note?.topicNames ?? [], theme),
          const SizedBox(height: 32),
          if (note != null) _buildFlashcardPreview(note, theme),
          const SizedBox(height: 32),
          _buildSidebarSection('LIVE INSIGHTS', provider.liveInsights, theme),
          const SizedBox(height: 32),
          _buildInsightCard(sumi, theme),
          const SizedBox(height: 32),
          _buildAISummaryCard(sumi, theme),
          const SizedBox(height: 32),
          _buildRecordingsList(provider, theme),
        ],
      ),
    );
  }

  Widget _buildRecordingsList(NoteProvider provider, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AUDIO SESSIONS',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11, 
            fontWeight: FontWeight.bold, 
            color: theme.hintColor, 
            letterSpacing: 1.2
          ),
        ),
        const SizedBox(height: 16),
        ...provider.currentNoteRecordings.map((rec) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: () => provider.playRecording(rec),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recording ${rec.createdAt.day}/${rec.createdAt.month}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${rec.durationSeconds}s • ${rec.createdAt.hour}:${rec.createdAt.minute}',
                      style: GoogleFonts.inter(fontSize: 11, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: () => provider.deleteRecording(rec.id),
                color: theme.colorScheme.error.withValues(alpha: 0.7),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildSidebarSection(String title, List<String> items, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11, 
            fontWeight: FontWeight.bold, 
            color: theme.hintColor, 
            letterSpacing: 1.2
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Text('No data available yet.', style: GoogleFonts.inter(fontSize: 13, color: theme.hintColor, fontStyle: FontStyle.italic)),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.circle, size: 6, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
              const SizedBox(width: 12),
              Expanded(child: Text(item, style: GoogleFonts.inter(fontSize: 14, color: theme.textTheme.bodyMedium?.color))),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildFlashcardPreview(LocalNote note, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STUDY PREVIEW',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11, 
            fontWeight: FontWeight.bold, 
            color: theme.hintColor, 
            letterSpacing: 1.2
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus: ${note.topicNames.isNotEmpty ? note.topicNames.first : "General"}', 
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)
              ),
              const SizedBox(height: 8),
              Text(
                'Hit "Synthesize" to generate personalized study materials from this session.', 
                style: GoogleFonts.inter(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8), height: 1.4)
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(SumiProvider sumi, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                'SUMI ASSIST', 
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sumi.dialogue ?? 'Neural flow is stable. I am monitoring your lecture for key insights.',
            style: GoogleFonts.inter(fontSize: 13, color: theme.textTheme.bodyMedium?.color, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAISummaryCard(SumiProvider sumi, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUMMARY OVERVIEW',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11, 
            fontWeight: FontWeight.bold, 
            color: theme.hintColor, 
            letterSpacing: 1.2
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Text(
            sumi.isStreaming ? (sumi.streamingMessage ?? 'Thinking...') : (sumi.dialogue ?? 'Start recording to generate live summaries.'),
            style: GoogleFonts.inter(fontSize: 13, color: theme.textTheme.bodyMedium?.color, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingButton(NoteProvider provider, UserModel? user, bool isRecording, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (isRecording) {
          provider.stopRecording();
        } else {
          provider.startRecording(user?.uid ?? '');
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isRecording ? Colors.red : theme.colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? Colors.red : theme.colorScheme.primary).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 36),
      ).animate(target: isRecording ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 500.ms, curve: Curves.easeInOut),
    );
  }
}

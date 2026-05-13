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
import '../../theme/cyber_neural_theme.dart';
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
        quill.Attribute.clone(quill.Attribute.color, CyberNeuralColors.gold.toARGB32().toRadixString(16))
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
            backgroundColor: CyberNeuralColors.purple,
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
    final noteProvider = context.watch<NoteProvider>();
    final user = Provider.of<UserModel?>(context);
    final isRecording = noteProvider.state == NoteProcessingState.recording;

    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: CyberNeuralColors.background, 
        body: Center(child: CircularProgressIndicator(color: CyberNeuralColors.cyan))
      );
    }

    return Scaffold(
      backgroundColor: CyberNeuralColors.background,
      body: Stack(
        children: [
          _buildAtmosphericLayer(),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 80),
                    Expanded(
                      child: _buildEditorArea(noteProvider),
                    ),
                  ],
                ),
              ),
              if (_showSidebar)
                _buildRightSidebar(noteProvider),
            ],
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: _buildTopBar(noteProvider, isRecording, user),
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
              child: _buildRecordingButton(noteProvider, user, isRecording),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtmosphericLayer() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [
            CyberNeuralColors.purple.withValues(alpha: 0.02),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(NoteProvider provider, bool isRecording, UserModel? user) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: CyberNeuralColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: CyberNeuralColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Neural Workspace',
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (isRecording)
                _buildCaptureBadge(),
              const SizedBox(width: 12),
              _buildMemoryBadge(),
              const SizedBox(width: 12),
              _buildTopAction(Icons.search, null, () {
                // Implement search logic or show search bar
              }),
              const SizedBox(width: 4),
              _buildTopAction(Icons.auto_awesome, 'Synthesize', () async {
                if (user != null) {
                  await provider.generateStudyMaterials(user.uid);
                }
              }),
              const SizedBox(width: 8),
              _buildTopAction(Icons.grid_view_rounded, null, () {
                setState(() => _showSidebar = !_showSidebar);
              }),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 14,
                backgroundColor: CyberNeuralColors.surfaceAlt,
                backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                child: user?.photoUrl == null ? const Icon(Icons.person, size: 16, color: Colors.white30) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CyberNeuralColors.alert.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CyberNeuralColors.alert.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: CyberNeuralColors.alert, shape: BoxShape.circle),
          ).animate(onPlay: (c) => c.repeat()).fadeIn().fadeOut(),
          const SizedBox(width: 8),
          Text(
            'LIVE CAPTURE',
            style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: CyberNeuralColors.alert),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryBadge() {
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
    final color = isStable ? CyberNeuralColors.success : CyberNeuralColors.cyan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(isStable ? Icons.verified_user : Icons.psychology, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            isStable ? 'STABLE' : 'EVOLVING',
            style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAction(IconData icon, String? label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: label != null ? CyberNeuralColors.cyan.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: label != null ? CyberNeuralColors.cyan : CyberNeuralColors.textSecondary),
            if (label != null) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: CyberNeuralColors.cyan),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditorArea(NoteProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 60),
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
                    padding: const EdgeInsets.only(bottom: 200),
                    placeholder: 'Enter the cognitive flow...',
                    customStyles: quill.DefaultStyles(
                      paragraph: quill.DefaultListBlockStyle(
                        GoogleFonts.inter(fontSize: 16, height: 1.8, color: CyberNeuralColors.textPrimary),
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
                  top: 200,
                  right: 0,
                  child: GhostLinkIndicator(label: 'Cognitive Architecture', onTap: () {}),
                ),
              ],
            ),
    );
  }

  Widget _buildRightSidebar(NoteProvider provider) {
    final sumi = context.watch<SumiProvider>();
    final note = provider.currentNote;
    
    return Container(
      width: 320,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        color: CyberNeuralColors.surface.withValues(alpha: 0.2),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          _buildSidebarSection('CONTEXTUAL NODES', note?.topicNames ?? []),
          const SizedBox(height: 32),
          if (note != null) _buildFlashcardPreview(note),
          const SizedBox(height: 32),
          _buildSidebarSection('ACTIVE INSIGHTS', provider.liveInsights),
          const SizedBox(height: 32),
          _buildInsightCard(sumi),
          const SizedBox(height: 32),
          _buildAISummaryCard(sumi),
          const SizedBox(height: 32),
          _buildRecordingsList(provider),
        ],
      ),
    );
  }

  Widget _buildRecordingsList(NoteProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LECTURE RECORDINGS',
          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: CyberNeuralColors.textTertiary, letterSpacing: 1.5),
        ),
        const SizedBox(height: 16),
        ...provider.currentNoteRecordings.map((rec) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CyberNeuralColors.surfaceAlt.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow_rounded, color: CyberNeuralColors.cyan),
                onPressed: () => provider.playRecording(rec),
              ),
              Expanded(
                child: Text(
                  '${rec.durationSeconds}s • ${rec.createdAt.hour}:${rec.createdAt.minute}',
                  style: GoogleFonts.inter(fontSize: 12, color: CyberNeuralColors.textSecondary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white24),
                onPressed: () => provider.deleteRecording(rec.id),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildSidebarSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: CyberNeuralColors.textTertiary, letterSpacing: 1.5),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 4, color: CyberNeuralColors.cyan),
              const SizedBox(width: 12),
              Text(item, style: GoogleFonts.inter(fontSize: 13, color: CyberNeuralColors.textSecondary)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildFlashcardPreview(LocalNote note) {
    // In a real app, we'd fetch actual flashcards linked to this note's topicIds
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FLASHCARD PREVIEW',
          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: CyberNeuralColors.textTertiary, letterSpacing: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CyberNeuralColors.surfaceAlt.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Topic: ${note.topicNames.isNotEmpty ? note.topicNames.first : "General"}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: CyberNeuralColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Neural mastery will generate cards here once synthesis completes.', style: GoogleFonts.inter(fontSize: 12, color: CyberNeuralColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(SumiProvider sumi) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyberNeuralColors.purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CyberNeuralColors.purple.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 14, color: CyberNeuralColors.purple),
              const SizedBox(width: 8),
              Text('NEURAL ASSIST', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: CyberNeuralColors.purple)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sumi.dialogue ?? 'Neural flow is stable. I am monitoring your lecture for key insights.',
            style: GoogleFonts.inter(fontSize: 12, color: CyberNeuralColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAISummaryCard(SumiProvider sumi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI SUMMARY',
          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: CyberNeuralColors.textTertiary, letterSpacing: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CyberNeuralColors.cyan.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CyberNeuralColors.cyan.withValues(alpha: 0.1)),
          ),
          child: Text(
            sumi.isStreaming ? (sumi.streamingMessage ?? 'Thinking...') : (sumi.dialogue ?? 'Start recording to generate live summaries.'),
            style: GoogleFonts.inter(fontSize: 12, color: CyberNeuralColors.textSecondary, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingButton(NoteProvider provider, UserModel? user, bool isRecording) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (isRecording) {
          provider.stopRecording();
        } else {
          provider.startRecording(user?.uid ?? '');
        }
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isRecording ? CyberNeuralColors.alert : CyberNeuralColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? CyberNeuralColors.alert : CyberNeuralColors.cyan).withValues(alpha: 0.3),
              blurRadius: 20,
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 32),
      ),
    );
  }
}

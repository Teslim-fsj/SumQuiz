import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/note_provider.dart';
import '../../models/user_model.dart';
import '../widgets/handwriting_canvas.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/mastery_service.dart';
import '../../providers/sumi_provider.dart';
import '../../models/sumi_emotion.dart';
import '../../widgets/sumi_mascot.dart';

class NoteEditorScreen extends StatefulWidget {
  final String noteId;
  final String? folderId;
  const NoteEditorScreen({super.key, required this.noteId, this.folderId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late QuillController _controller;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  bool _isDrawingMode = false;
  bool _isInitialized = false;
  StreamSubscription<String>? _transcriptSub;

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
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

    // Listen for live transcription chunks
    _transcriptSub = noteProvider.transcriptChunkStream.listen((text) {
      if (mounted && text.isNotEmpty) {
        _appendLiveText(text);
      }
    });
  }

  void _appendLiveText(String text) {
    final length = _controller.document.length;
    // Insert text at the end, ensuring there's a space or newline if needed
    // Note: Quill document length includes the trailing newline, so we insert at length - 1
    final insertionIndex = length > 0 ? length - 1 : 0;
    
    // Add a space before the new text if the document isn't empty and doesn't end with whitespace
    String textToInsert = text;
    if (insertionIndex > 0) {
      final lastChar = _controller.document.toPlainText().substring(insertionIndex - 1, insertionIndex);
      if (lastChar != ' ' && lastChar != '\n') {
        textToInsert = ' $text';
      }
    }
    
    _controller.document.insert(insertionIndex, textToInsert);
    
    // Smart selection: only move to end if the user was already at the end
    final isAtEnd = _controller.selection.extentOffset >= length - 1;
    if (isAtEnd) {
      _controller.updateSelection(
        TextSelection.collapsed(offset: _controller.document.length - 1),
        ChangeSource.local,
      );

      // Auto-scroll to bottom only if at end
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

      // Send Signal
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
          final doc = Document.fromJson(jsonDecode(note.content));
          _controller = QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
          _controller.addListener(_onContentChanged);
        } catch (e) {
          // Fallback for plain text if JSON fails
          _controller.document.insert(0, note.content);
        }
      }
      setState(() {
        _isInitialized = true;
      });
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
    final noteProvider = context.watch<NoteProvider>();
    final user = Provider.of<UserModel?>(context);

    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Main Editor Content
          Column(
            children: [
              _buildModernHeader(theme),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _isDrawingMode
                      ? HandwritingCanvas(
                          strokes: noteProvider.drawingStrokes,
                          onStrokeComplete: (stroke) =>
                              noteProvider.addDrawingStroke(stroke),
                          currentAudioTime: noteProvider.recordingDuration,
                          onStrokeTap: (time) => noteProvider.seekAudio(time),
                        )
                      : Column(
                          children: [
                            const SizedBox(height: 16),
                            Expanded(
                              child: QuillEditor.basic(
                                controller: _controller,
                                scrollController: _scrollController,
                                config: QuillEditorConfig(
                                  autoFocus: true,
                                  expands: false,
                                  padding: const EdgeInsets.only(bottom: 120),
                                  placeholder: 'Start writing your brilliant thoughts...',
                                  customStyles: DefaultStyles(
                                    paragraph: DefaultListBlockStyle(
                                      theme.textTheme.bodyLarge!.copyWith(
                                        height: 1.6,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                      ),
                                      const HorizontalSpacing(0, 0),
                                      const VerticalSpacing(0, 0),
                                      const VerticalSpacing(0, 0),
                                      null,
                                      null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),

          // Floating Formatting Toolbar (only when keyboard is up or text selected)
          if (!_isDrawingMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20,
              right: 20,
              child: _buildFormattingToolbar(theme),
            ),

          // Floating Action Bar (Recording, AI, Drawing)
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: _buildFloatingActionBar(noteProvider, user, theme),
          ),

          // Recording State Overlay
          if (noteProvider.state == NoteProcessingState.recording)
            _buildLiveTranscriptOverlay(noteProvider, theme),
        ],
      ),
    );
  }

  Widget _buildModernHeader(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(width: 16),
              if (context.watch<NoteProvider>().state == NoteProcessingState.recording)
                _buildLiveBadge(theme),
              const Spacer(),
              Consumer<SumiProvider>(
                builder: (context, sumi, _) {
                  // Ensure Sumi looks focused while recording
                  final isRecording = context.read<NoteProvider>().state == NoteProcessingState.recording;
                  return SumiMascot(
                    state: isRecording ? SumiState.analytical : sumi.currentState,
                    size: 44,
                    dialogue: isRecording ? "I'm listening closely to the lecture..." : sumi.dialogue,
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildMenuButton(theme),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Note Title',
              hintStyle: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                fontWeight: FontWeight.w900,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattingToolbar(ThemeData theme) {
    return _buildGlassContainer(
      theme,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: QuillSimpleToolbar(
        controller: _controller,
        config: QuillSimpleToolbarConfig(
          showSearchButton: false,
          showFontFamily: false,
          showFontSize: false,
          showUndo: true,
          showRedo: true,
          showListCheck: true,
          showCodeBlock: true,
          showLink: true,
          multiRowsDisplay: false,
          buttonOptions: QuillSimpleToolbarButtonOptions(
            base: QuillToolbarBaseButtonOptions(
              iconTheme: QuillIconTheme(
                iconButtonSelectedData: IconButtonData(
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionBar(NoteProvider noteProvider, UserModel? user, ThemeData theme) {
    final isRecording = noteProvider.state == NoteProcessingState.recording;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildGlassContainer(
          theme,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: BorderRadius.circular(32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drawing Toggle
              _buildToolbarIcon(
                icon: _isDrawingMode ? Icons.text_fields_rounded : Icons.gesture_rounded,
                color: Colors.purple,
                onPressed: () => setState(() => _isDrawingMode = !_isDrawingMode),
                tooltip: 'Drawing Mode',
              ),
              _buildDivider(theme),
              // Main Recording Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (isRecording) {
                    noteProvider.stopRecording();
                  } else {
                    noteProvider.startRecording(user?.uid ?? '');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isRecording ? Colors.red : theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: (isRecording ? Colors.red : theme.colorScheme.primary).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                        color: Colors.white,
                      ),
                      if (isRecording) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(noteProvider.recordingDuration),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _buildDivider(theme),
              // AI Actions
              _buildToolbarIcon(
                icon: Icons.auto_awesome_rounded,
                color: Colors.amber[700]!,
                onPressed: () => _showGenerateDialog(context, user),
                tooltip: 'AI Tools',
              ),
              _buildDivider(theme),
              // Insights Panel (Recordings & Links)
              _buildToolbarIcon(
                icon: Icons.bubble_chart_rounded,
                color: theme.colorScheme.primary,
                onPressed: () => _showInsightsPanel(context, noteProvider),
                tooltip: 'Note Insights',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbarIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.dividerColor.withValues(alpha: 0.1),
    );
  }

  Widget _buildGlassContainer(ThemeData theme, {
    required Widget child, 
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.7),
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  void _showInsightsPanel(BuildContext context, NoteProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildGlassContainer(
        Theme.of(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Note Insights', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildBackLinksSection(provider),
              const SizedBox(height: 16),
              Text('Recordings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildRecordingList(provider, Theme.of(context)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(ThemeData theme) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (val) {
        if (val == 'delete') _confirmDelete(context);
        if (val == 'analyze') _analyzeDiagram(context, null);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'analyze',
          child: Row(children: [Icon(Icons.image_search, size: 20), SizedBox(width: 12), Text('Analyze Diagram')]),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [Icon(Icons.delete_outline, size: 20, color: Colors.red), SizedBox(width: 12), Text('Delete Note', style: TextStyle(color: Colors.red))]),
        ),
      ],
    );
  }

  Widget _buildLiveBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 500.ms).fadeOut(delay: 500.ms),
          const SizedBox(width: 8),
          Text(
            'LIVE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildRecordingList(NoteProvider provider, ThemeData theme) {
    if (provider.currentNoteRecordings.isEmpty) {
      return const Center(child: Text('No recordings yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)));
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: provider.currentNoteRecordings.length,
        itemBuilder: (context, index) {
          final rec = provider.currentNoteRecordings[index];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mic_rounded, size: 16, color: Colors.blue),
                    const Spacer(),
                    if (rec.isTranscribed)
                      const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                  ],
                ),
                const Spacer(),
                Text('Session ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${rec.durationSeconds}s', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveTranscriptOverlay(NoteProvider provider, ThemeData theme) {
    return Positioned(
      bottom: 110,
      left: 24,
      right: 24,
      child: _buildGlassContainer(
        theme,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildPulsatingRecordIcon(),
                const SizedBox(width: 12),
                Text(
                  'NEURAL CAPTURE ACTIVE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.redAccent,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDuration(provider.recordingDuration),
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                provider.liveTranscript.isEmpty ? 'Waiting for neural signals...' : provider.liveTranscript,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: provider.liveTranscript.isEmpty 
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                      : theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildPulsatingRecordIcon() {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
     .scale(duration: 600.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2))
     .boxShadow(
       duration: 600.ms, 
       begin: const BoxShadow(color: Colors.transparent, blurRadius: 0),
       end: BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 8),
     );
  }

  Widget _buildBackLinksSection(NoteProvider provider) {
    final backLinks = provider.currentNote?.backLinks ?? [];
    if (backLinks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connected Notes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: backLinks.map((id) => Chip(
            label: const Text('Related Knowledge'),
            avatar: const Icon(Icons.link_rounded, size: 14),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          )).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _analyzeDiagram(BuildContext context, UserModel? user) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analyzing diagram...')));
  }

  void _showGenerateDialog(BuildContext context, UserModel? user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassContainer(
        Theme.of(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 48, color: Colors.amber),
              const SizedBox(height: 24),
              Text('Neural Synthesis', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Let Sumi transform your notes into study materials.', textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.read<NoteProvider>().generateStudyMaterials(user?.uid ?? '');
                      },
                      child: const Text('Synthesize'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase Knowledge?'),
        content: const Text('This action will permanently delete this note and its neural recordings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<NoteProvider>().deleteNote(widget.noteId);
              context.pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}


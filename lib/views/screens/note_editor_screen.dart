import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/note_provider.dart';
import '../../models/user_model.dart';
import '../widgets/handwriting_canvas.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/mastery_service.dart';
import '../../providers/sumi_provider.dart';
import '../../widgets/sumi_mascot.dart';

class NoteEditorScreen extends StatefulWidget {
  final String noteId;
  const NoteEditorScreen({super.key, required this.noteId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late QuillController _controller;
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  bool _isInitialized = false;
  bool _isDrawingMode = false;

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
    final noteProvider = context.read<NoteProvider>();
    final user = Provider.of<UserModel?>(context, listen: false);

    if (widget.noteId == 'new') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final note = await noteProvider.createNewNote(user?.uid ?? '');
        if (mounted) {
          final uri = GoRouterState.of(context).uri;
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
  }

  Future<void> _loadNote() async {
    final provider = context.read<NoteProvider>();
    await provider.loadNote(widget.noteId);
    final note = provider.currentNote;

    if (note != null) {
      _titleController.text = note.title;

      // Send Signal
      final user = Provider.of<UserModel?>(context, listen: false);
      if (user != null && note.topicIds.isNotEmpty) {
        final mastery = Provider.of<MasteryService>(context, listen: false);
        for (final topicId in note.topicIds) {
          mastery.processSignal(LearningSignal(
            topicId: topicId,
            userId: user.uid,
            type: SignalType.noteReread,
            context: 'note_editor',
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
    _editorFocusNode.dispose();
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
      appBar: AppBar(
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Note Title',
            border: InputBorder.none,
          ),
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Sumi Body Doubling
          Consumer<SumiProvider>(
            builder: (context, sumi, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: SumiMascot(
                  state: sumi.currentState,
                  size: 40,
                  dialogue: sumi.dialogue,
                ),
              );
            },
          ),
          if (noteProvider.state == NoteProcessingState.recording) ...[
            Center(
              child: Text(
                _formatDuration(noteProvider.recordingDuration),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: Colors.red),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              tooltip: 'Stop Recording',
              onPressed: () => noteProvider.stopRecording(),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.mic_rounded, color: Colors.blue),
              tooltip: 'Start Recording',
              onPressed: () => noteProvider.startRecording(user?.uid ?? ''),
            ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Generate Study Materials',
            onPressed: () => _showGenerateDialog(context, user),
          ),
          IconButton(
            icon: Icon(_isDrawingMode ? Icons.text_fields : Icons.gesture,
                color: Colors.purple),
            tooltip: 'Toggle Handwriting',
            onPressed: () => setState(() => _isDrawingMode = !_isDrawingMode),
          ),
          IconButton(
            icon: const Icon(Icons.image_search, color: Colors.orange),
            tooltip: 'Analyze Diagram',
            onPressed: () => _analyzeDiagram(context, user),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Column(
        children: [
          QuillSimpleToolbar(
            controller: _controller,
            config: const QuillSimpleToolbarConfig(
              showSearchButton: false,
              showFontFamily: false,
              showFontSize: false,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: theme.scaffoldBackgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _isDrawingMode
                      ? HandwritingCanvas(
                          strokes: noteProvider.drawingStrokes,
                          onStrokeComplete: (stroke) =>
                              noteProvider.addDrawingStroke(stroke),
                          currentAudioTime: noteProvider.recordingDuration,
                          onStrokeTap: (time) => noteProvider.seekAudio(time),
                        )
                      : QuillEditor.basic(
                          controller: _controller,
                          config: const QuillEditorConfig(
                            autoFocus: true,
                            expands: false,
                            padding: EdgeInsets.only(top: 16, bottom: 100),
                          ),
                        ),
                ),
                if (noteProvider.state == NoteProcessingState.recording)
                  _buildLiveTranscriptOverlay(noteProvider),
              ],
            ),
          ),
          _buildBackLinksSection(noteProvider),
          _buildRecordingList(noteProvider),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildRecordingList(NoteProvider provider) {
    if (provider.currentNoteRecordings.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: provider.currentNoteRecordings.length,
        itemBuilder: (context, index) {
          final rec = provider.currentNoteRecordings[index];
          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Theme.of(context).dividerColor.withAlpha(26)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.audiotrack, size: 16, color: Colors.blue),
                    const Spacer(),
                    if (provider.state == NoteProcessingState.transcribing)
                      const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else if (rec.isTranscribed)
                      const Icon(Icons.check_circle,
                          size: 16, color: Colors.green)
                    else
                      IconButton(
                        icon: const Icon(Icons.translate, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => provider.transcribeRecording(rec),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Recording ${index + 1}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${rec.durationSeconds}s',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveTranscriptOverlay(NoteProvider provider) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(180),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.mic, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text('Live Transcript',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              provider.liveTranscript.isEmpty
                  ? 'Listening...'
                  : provider.liveTranscript,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackLinksSection(NoteProvider provider) {
    final backLinks = provider.currentNote?.backLinks ?? [];
    if (backLinks.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withAlpha(13),
        border: Border(
            top: BorderSide(
                color: Theme.of(context).dividerColor.withAlpha(26))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Linked from:',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: backLinks
                .map((id) => ActionChip(
                      label: Text(
                          'Referenced in Note'), // In real app, fetch title
                      onPressed: () => provider.toggleBackLink(id),
                      avatar: const Icon(Icons.link, size: 14),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeDiagram(BuildContext context, UserModel? user) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Analyzing diagram and creating "Label the Image" quiz...')));

    // In real app, call generateDiagramLabeledQuiz and show results
  }

  void _showGenerateDialog(BuildContext context, UserModel? user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Study Materials'),
        content: const Text(
            'Generate summaries, quizzes, and flashcards from this note?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context
                  .read<NoteProvider>()
                  .generateStudyMaterials(user?.uid ?? '');
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
            'Are you sure you want to delete this note and all associated recordings?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
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

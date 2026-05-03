import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/note_provider.dart';
import '../../models/local_note.dart';
import '../../models/user_model.dart';
import '../widgets/recording_bar_widget.dart';

class NoteEditorScreen extends StatefulWidget {
  final String noteId;
  final String? folderId;
  // Force IDE re-analysis
  const NoteEditorScreen({super.key, required this.noteId, this.folderId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late QuillController _controller;
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNote();
    });

    _titleController.addListener(_onTitleChanged);
    _controller.addListener(_onContentChanged);
  }

  Future<void> _loadNote() async {
    final provider = context.read<NoteProvider>();
    final user = context.read<UserModel?>();
    
    if (widget.noteId == 'new') {
      if (user != null) {
        await provider.createNewNote(user.uid, folderId: widget.folderId);
      }
    } else if (widget.noteId == 'new_recording') {
       if (user != null) {
        await provider.startRecording(user.uid, folderId: widget.folderId);
      }
    } else {
      await provider.loadNote(widget.noteId);
    }
    
    final note = provider.currentNote;
    
    if (note != null) {
      _titleController.text = note.title;
      
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
  }

  void _onContentChanged() {
    if (!_isInitialized) return;
    final content = jsonEncode(_controller.document.toDelta().toJson());
    context.read<NoteProvider>().updateNoteContent(content);
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
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Generate Study Materials',
            onPressed: () => _showGenerateDialog(context, user),
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
            config: const QuillSimpleToolbarConfig(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: QuillEditor.basic(
                controller: _controller,
                config: const QuillEditorConfig(
                  autoFocus: false,
                  expands: true,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          _buildRecordingList(noteProvider),
          const RecordingBarWidget(),
        ],
      ),
    );
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
              border: Border.all(color: Theme.of(context).dividerColor.withAlpha(26)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.audiotrack, size: 16, color: Colors.blue),
                    const Spacer(),
                    if (provider.state == NoteProcessingState.transcribing)
                      const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    else if (rec.isTranscribed)
                      const Icon(Icons.check_circle, size: 16, color: Colors.green)
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
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

  void _showGenerateDialog(BuildContext context, UserModel? user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Study Materials'),
        content: const Text('Generate summaries, quizzes, and flashcards from this note?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<NoteProvider>().generateStudyMaterials(user?.uid ?? '');
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
        content: const Text('Are you sure you want to delete this note and all associated recordings?'),
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

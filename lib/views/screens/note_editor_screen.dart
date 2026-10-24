import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/note_provider.dart';
import '../../models/user_model.dart';
import '../../services/mastery_service.dart';
import '../widgets/handwriting_canvas.dart';
import '../../services/transcript_recovery_service.dart';
import '../widgets/aura_alert_banner.dart';
import '../widgets/notes/live_recording_view.dart';
import '../widgets/notes/split_document_viewer.dart';
import '../widgets/upgrade_dialog.dart';

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

  bool _isInitialized = false;
  bool _showSidebar = false;
  bool _showSplitDocument = false;
  bool _isSketchMode = false;
  bool _isEraserMode = false;
  bool _showFullScreenRecording = false;

  String _attachedDocumentName = 'Attached Document';
  String? _attachedDocumentContent;

  int get _wordCount {
    final text = _controller.document.toPlainText().trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }

  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<String>? _cleanupSub;

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController.basic();
    final noteProvider = context.read<NoteProvider>();
    final user = Provider.of<UserModel?>(context, listen: false);

    if (widget.noteId == 'new') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final uri = GoRouterState.of(context).uri;
        final newNote = await noteProvider.createNewNote(user?.uid ?? '');
        if (mounted) {
          _titleController.text = newNote.title;
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

    _transcriptSub = noteProvider.transcriptChunkStream.listen((text) {
      if (mounted && text.isNotEmpty) {
        _appendLiveText(text);
      }
    });

    _cleanupSub = noteProvider.cleanedUpNotesStream.listen((deltaJson) {
      if (mounted) {
        try {
          final doc = quill.Document.fromJson(jsonDecode(deltaJson));
          setState(() {
            final oldController = _controller;
            _controller = quill.QuillController(
              document: doc,
              selection: const TextSelection.collapsed(offset: 0),
            );
            _controller.addListener(_onContentChanged);
            oldController.dispose();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sumi organized your lecture notes! ✨'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          debugPrint('Failed to apply cleaned notes: $e');
        }
      }
    });
  }

  void _appendLiveText(String text) {
    if (text.isEmpty) return;

    final length = _controller.document.length;
    final insertionIndex = length > 0 ? length - 1 : 0;

    String textToInsert = text;
    if (insertionIndex > 0) {
      final textStr = _controller.document.toPlainText();
      if (textStr.length >= insertionIndex) {
        final lastChar = textStr.substring(insertionIndex - 1, insertionIndex);
        if (lastChar != ' ' && lastChar != '\n') {
          textToInsert = ' $text';
        }
      }
    }

    final currentSelection = _controller.selection;
    final isAtEnd = currentSelection.extentOffset >= insertionIndex;

    _controller.document.insert(insertionIndex, textToInsert);

    if (isAtEnd) {
      final newLength = _controller.document.length;
      _controller.updateSelection(
        TextSelection.collapsed(offset: newLength > 0 ? newLength - 1 : 0),
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
        } catch (e) {
          _controller.document.insert(0, note.content);
        }
      }
      setState(() {
        _isInitialized = true;
      });

      final recovered =
          await TranscriptRecoveryService().getRecoveredTranscript(note.id);
      if (recovered != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Found unsaved transcript from previous session.'),
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
      _controller.replaceText(
          index, length, quill.BlockEmbed.image(path), null);
    }
  }

  Future<void> _pickDocumentForSplitView() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String? previewText;
        if (file.bytes != null && file.extension?.toLowerCase() == 'txt') {
          previewText = utf8.decode(file.bytes!);
        }
        setState(() {
          _attachedDocumentName = file.name;
          _attachedDocumentContent = previewText ??
              'Document "${file.name}" loaded (${(file.size / 1024).toStringAsFixed(1)} KB).\nUse alongside your notes.';
          _showSplitDocument = true;
        });
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _editorFocusNode.dispose();
    _transcriptSub?.cancel();
    _cleanupSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final noteProvider = context.watch<NoteProvider>();
    final user = Provider.of<UserModel?>(context);
    final isRecording = noteProvider.state == NoteProcessingState.recording;

    if (noteProvider.limitReached) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          noteProvider.clearError();
          UpgradeDialog.show(context, featureName: 'Live Lecture Notes');
        }
      });
    }

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    // Fullscreen dedicated Live Lecture Recording view (expandable)
    if (_showFullScreenRecording) {
      return LiveRecordingView(
        noteProvider: noteProvider,
        title: _titleController.text.isNotEmpty
            ? _titleController.text
            : 'Lecture Recording',
        topic: 'Live Session',
        onStopRecording: () async {
          await noteProvider.stopRecording();
          setState(() {
            _showFullScreenRecording = false;
          });
        },
        onBack: () {
          setState(() {
            _showFullScreenRecording = false;
          });
        },
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          final noteProv = context.read<NoteProvider>();
          if (noteProv.state == NoteProcessingState.recording) {
            await noteProv.stopRecording();
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              if (noteProvider.errorMessage.isNotEmpty)
                AuraAlertBanner(
                  title: "Notice",
                  description: noteProvider.errorMessage,
                  onIgnore: () => noteProvider.clearError(),
                  actionLabel: "DISMISS",
                  onAction: () => noteProvider.clearError(),
                ),

              // 1. Sleek Top Bar
              _buildTopBar(noteProvider, user, theme),

              // 2. Active Lecture Recording Banner Island (when recording is running in note)
              if (isRecording) _buildActiveRecordingIsland(noteProvider, theme),

              // 3. Main Note Workspace
              Expanded(
                child: Stack(
                  children: [
                    // Note Editor with optional Document Split Pane
                    Positioned.fill(
                      child: _showSplitDocument
                          ? SplitDocumentViewer(
                              documentName: _attachedDocumentName,
                              documentContent: _attachedDocumentContent,
                              onClose: () =>
                                  setState(() => _showSplitDocument = false),
                              onPickDocument: _pickDocumentForSplitView,
                              child: _buildEditorContent(isDark, theme),
                            )
                          : _buildEditorContent(isDark, theme),
                    ),

                    // Sketch Drawing Canvas Overlay
                    if (_isSketchMode)
                      Positioned.fill(
                        child: Container(
                          color: (isDark ? Colors.black : Colors.white)
                              .withValues(alpha: 0.85),
                          child: Stack(
                            children: [
                              HandwritingCanvas(
                                strokes: noteProvider.drawingStrokes,
                                onStrokeComplete: (stroke) =>
                                    noteProvider.addDrawingStroke(stroke),
                                currentAudioTime:
                                    noteProvider.recordingDuration,
                                onStrokeTap: (time) =>
                                    noteProvider.seekAudio(time),
                                isEraserMode: _isEraserMode,
                              ),
                              Positioned(
                                top: 16,
                                right: 16,
                                child: _buildSketchControlBar(
                                    noteProvider, isDark),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Right Sidebar (Entities & Audio Sessions)
                    if (_showSidebar) ...[
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _showSidebar = false),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildRightSidebar(noteProvider, theme),
                      ),
                    ],
                  ],
                ),
              ),

              // 4. Keyboard-Docked Formatting Toolbar (replaces obtrusive dock)
              if (!_isSketchMode) _buildKeyboardToolbar(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────
  Widget _buildTopBar(
      NoteProvider noteProvider, UserModel? user, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final isRecording = noteProvider.state == NoteProcessingState.recording;
    final isGenerating =
        noteProvider.state == NoteProcessingState.generating ||
            noteProvider.state == NoteProcessingState.cleaning_up;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              size: 22,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Back to Notes',
          ),
          const SizedBox(width: 8),

          // Title TextField
          Expanded(
            child: TextField(
              controller: _titleController,
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Note Title...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),

          // Cloud Saved badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done_rounded,
                  size: 15,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Saved',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // 🎙️ Record Lecture Toggle
          IconButton(
            onPressed: () async {
              if (isRecording) {
                await noteProvider.stopRecording();
              } else {
                noteProvider.startRecording(user?.uid ?? '');
              }
            },
            icon: Icon(
              isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
              size: 24,
              color: isRecording
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF6B5CE7),
            ),
            tooltip: isRecording ? 'Stop Lecture Recording' : 'Record Lecture',
          ),

          // ✨ One-Tap Study Pack Synthesis
          FilledButton.icon(
            onPressed: user == null || isGenerating
                ? null
                : () async {
                    if (isRecording) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please finish recording before generating study pack.'),
                          backgroundColor: Colors.orangeAccent,
                        ),
                      );
                      return;
                    }

                    final folderId =
                        await noteProvider.generateStudyMaterials(user.uid);
                    if (folderId != null && mounted) {
                      context.pushNamed('results-view',
                          pathParameters: {'folderId': folderId});
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6B5CE7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: isGenerating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 15),
            label: Text(
              isGenerating ? 'Studying...' : 'Study',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),

          // Options Menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              size: 22,
            ),
            tooltip: 'More Options',
            onSelected: (value) async {
              switch (value) {
                case 'split_doc':
                  if (_showSplitDocument) {
                    setState(() => _showSplitDocument = false);
                  } else {
                    _pickDocumentForSplitView();
                  }
                  break;
                case 'sketch':
                  setState(() => _isSketchMode = !_isSketchMode);
                  break;
                case 'fullscreen_recording':
                  setState(() => _showFullScreenRecording = true);
                  break;
                case 'sidebar':
                  setState(() => _showSidebar = !_showSidebar);
                  break;
                case 'share':
                  final text = _controller.document.toPlainText();
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Note copied to clipboard! 📋'),
                      backgroundColor: Color(0xFF6B5CE7),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  break;
                case 'delete':
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Note?'),
                      content: const Text(
                          'Are you sure you want to delete this note? This action cannot be undone.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    final targetId =
                        noteProvider.currentNote?.id ?? widget.noteId;
                    await noteProvider.deleteNote(targetId);
                    if (mounted) context.pop();
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'split_doc',
                child: Row(
                  children: [
                    Icon(Icons.vertical_split_rounded,
                        size: 18, color: const Color(0xFF6B5CE7)),
                    const SizedBox(width: 10),
                    Text(_showSplitDocument
                        ? 'Hide Document Pane'
                        : 'Attach Document (Split View)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sketch',
                child: Row(
                  children: [
                    Icon(Icons.draw_rounded,
                        size: 18, color: const Color(0xFF8B5CF6)),
                    const SizedBox(width: 10),
                    Text(_isSketchMode ? 'Exit Sketch Mode' : 'Sketch / Draw'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'fullscreen_recording',
                child: Row(
                  children: [
                    Icon(Icons.fullscreen_rounded,
                        size: 18, color: const Color(0xFFEC4899)),
                    const SizedBox(width: 10),
                    const Text('Full-Screen Lecture View'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sidebar',
                child: Row(
                  children: [
                    Icon(Icons.menu_open_rounded,
                        size: 18, color: const Color(0xFF3B82F6)),
                    const SizedBox(width: 10),
                    const Text('Topics & Audio History'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    const Icon(Icons.copy_rounded, size: 18),
                    const SizedBox(width: 10),
                    const Text('Copy Note Text'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.red),
                    const SizedBox(width: 10),
                    const Text('Delete Note',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Active Lecture Recording Banner Island ─────────────────────────────
  Widget _buildActiveRecordingIsland(
      NoteProvider provider, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final minutes = provider.recordingDuration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = provider.recordingDuration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.08),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFEF4444).withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          // Red dot indicator
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (c) => c.repeat()).fadeIn().fadeOut(),
          const SizedBox(width: 8),

          // Status & Elapsed Time
          Text(
            'RECORDING LECTURE • $minutes:$seconds',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFEF4444),
            ),
          ),
          const Spacer(),

          // Expand to full-screen view
          IconButton(
            icon: const Icon(Icons.fullscreen_rounded, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            tooltip: 'Expand to Fullscreen Recording',
            onPressed: () => setState(() => _showFullScreenRecording = true),
          ),

          // Pause / Resume
          IconButton(
            icon: Icon(
              provider.isRecordingPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            onPressed: () {
              if (provider.isRecordingPaused) {
                provider.resumeRecording();
              } else {
                provider.pauseRecording();
              }
            },
          ),

          // Stop Button
          IconButton(
            icon: const Icon(Icons.stop_circle_rounded,
                size: 22, color: Color(0xFFEF4444)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => provider.stopRecording(),
            tooltip: 'Stop & Finish',
          ),
        ],
      ),
    );
  }

  // ── Editor Content Canvas ──────────────────────────────────────────────
  Widget _buildEditorContent(bool isDark, ThemeData theme) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          quill.QuillEditor.basic(
            controller: _controller,
            config: quill.QuillEditorConfig(
              autoFocus: false,
              padding: EdgeInsets.zero,
              placeholder: 'Start writing your notes or record a lecture...',
              embedBuilders: [
                ImageEmbedBuilder(),
              ],
              customStyles: quill.DefaultStyles(
                paragraph: quill.DefaultTextBlockStyle(
                  GoogleFonts.inter(
                    fontSize: 16,
                    height: 1.8,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF334155),
                  ),
                  const quill.HorizontalSpacing(0, 0),
                  const quill.VerticalSpacing(0, 0),
                  const quill.VerticalSpacing(0, 0),
                  null,
                ),
                h1: quill.DefaultTextBlockStyle(
                  GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  const quill.HorizontalSpacing(0, 0),
                  const quill.VerticalSpacing(16, 0),
                  const quill.VerticalSpacing(0, 0),
                  null,
                ),
                h2: quill.DefaultTextBlockStyle(
                  GoogleFonts.outfit(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  const quill.HorizontalSpacing(0, 0),
                  const quill.VerticalSpacing(12, 0),
                  const quill.VerticalSpacing(0, 0),
                  null,
                ),
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Word Count Indicator
          Center(
            child: Text(
              '$_wordCount words',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color:
                    isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Keyboard-Docked Formatting Toolbar ──────────────────────────────────
  Widget _buildKeyboardToolbar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // H1
            _textFormatButton('H1', () {
              final isH1 = _controller
                  .getSelectionStyle()
                  .attributes
                  .containsKey(quill.Attribute.h1.key);
              _controller.formatSelection(isH1
                  ? quill.Attribute.clone(quill.Attribute.h1, null)
                  : quill.Attribute.h1);
            }, isDark),
            const SizedBox(width: 4),

            // H2
            _textFormatButton('H2', () {
              final isH2 = _controller
                  .getSelectionStyle()
                  .attributes
                  .containsKey(quill.Attribute.h2.key);
              _controller.formatSelection(isH2
                  ? quill.Attribute.clone(quill.Attribute.h2, null)
                  : quill.Attribute.h2);
            }, isDark),
            const SizedBox(width: 6),

            // Bold
            _iconFormatButton(Icons.format_bold_rounded, () {
              final isBold = _controller
                  .getSelectionStyle()
                  .attributes
                  .containsKey(quill.Attribute.bold.key);
              _controller.formatSelection(isBold
                  ? quill.Attribute.clone(quill.Attribute.bold, null)
                  : quill.Attribute.bold);
            }, isDark),
            const SizedBox(width: 4),

            // Italic
            _iconFormatButton(Icons.format_italic_rounded, () {
              final isItalic = _controller
                  .getSelectionStyle()
                  .attributes
                  .containsKey(quill.Attribute.italic.key);
              _controller.formatSelection(isItalic
                  ? quill.Attribute.clone(quill.Attribute.italic, null)
                  : quill.Attribute.italic);
            }, isDark),
            const SizedBox(width: 8),

            Container(
              height: 16,
              width: 1,
              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
            ),
            const SizedBox(width: 8),

            // Bullets
            _iconFormatButton(Icons.format_list_bulleted_rounded, () {
              final isUl = _controller
                  .getSelectionStyle()
                  .attributes
                  .containsKey(quill.Attribute.ul.key);
              _controller.formatSelection(isUl
                  ? quill.Attribute.clone(quill.Attribute.ul, null)
                  : quill.Attribute.ul);
            }, isDark),
            const SizedBox(width: 4),

            // Numbered List
            _iconFormatButton(Icons.format_list_numbered_rounded, () {
              final isOl = _controller
                  .getSelectionStyle()
                  .attributes
                  .containsKey(quill.Attribute.ol.key);
              _controller.formatSelection(isOl
                  ? quill.Attribute.clone(quill.Attribute.ol, null)
                  : quill.Attribute.ol);
            }, isDark),
            const SizedBox(width: 8),

            Container(
              height: 16,
              width: 1,
              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
            ),
            const SizedBox(width: 8),

            // Insert Image
            _iconFormatButton(Icons.image_rounded, _insertImage, isDark,
                tooltip: 'Insert Image'),
            const SizedBox(width: 4),

            // Sketch / Draw
            _iconFormatButton(
              Icons.draw_rounded,
              () => setState(() => _isSketchMode = !_isSketchMode),
              isDark,
              tooltip: 'Sketch Canvas',
            ),
          ],
        ),
      ),
    );
  }

  Widget _textFormatButton(String label, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _iconFormatButton(IconData icon, VoidCallback onTap, bool isDark,
      {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 19,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  // ── Sketch Canvas Top Bar ──────────────────────────────────────────────
  Widget _buildSketchControlBar(NoteProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit_rounded,
                size: 20,
                color: !_isEraserMode
                    ? const Color(0xFF6B5CE7)
                    : (isDark ? Colors.white60 : Colors.black54)),
            onPressed: () => setState(() => _isEraserMode = false),
            tooltip: 'Pen',
          ),
          IconButton(
            icon: Icon(Icons.cleaning_services_rounded,
                size: 20,
                color: _isEraserMode
                    ? const Color(0xFF6B5CE7)
                    : (isDark ? Colors.white60 : Colors.black54)),
            onPressed: () => setState(() => _isEraserMode = true),
            tooltip: 'Eraser',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, size: 20),
            color: Colors.redAccent,
            onPressed: () => provider.clearStrokes(),
            tooltip: 'Clear All Strokes',
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => setState(() => _isSketchMode = false),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6B5CE7),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Done',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Right Sidebar (Entities & Audio Sessions) ──────────────────────────
  Widget _buildRightSidebar(NoteProvider provider, ThemeData theme) {
    final note = provider.currentNote;
    final colorScheme = theme.colorScheme;

    return Material(
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            left: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Note Insights',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _showSidebar = false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCollapsibleSidebarSection(
                    theme: theme,
                    title: 'TOPICS & ENTITIES',
                    child: _buildTopicsContent(note?.topicNames ?? [], theme),
                  ),
                  const SizedBox(height: 12),
                  _buildCollapsibleSidebarSection(
                    theme: theme,
                    title: 'AUDIO SESSIONS',
                    child: _buildRecordingsContent(provider, theme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleSidebarSection({
    required ThemeData theme,
    required String title,
    required Widget child,
  }) {
    final colorScheme = theme.colorScheme;
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        iconColor: colorScheme.onSurfaceVariant,
        collapsedIconColor: colorScheme.onSurfaceVariant,
        title: Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        children: [child],
      ),
    );
  }

  Widget _buildTopicsContent(List<String> items, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    if (items.isEmpty) {
      return Text(
        'Sumi will detect topics automatically.',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.tag_rounded,
                          size: 10, color: colorScheme.tertiary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildRecordingsContent(NoteProvider provider, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    if (provider.currentNoteRecordings.isEmpty) {
      return Text(
        'No recordings yet. Tap 🎙️ to record a lecture.',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: provider.currentNoteRecordings
          .map((rec) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.1)),
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
                            'Session ${rec.createdAt.day}/${rec.createdAt.month}',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface),
                          ),
                          Text(
                            '${rec.durationSeconds}s',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant),
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
              ))
          .toList(),
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
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, size: 50, color: Colors.red),
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
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, size: 50, color: Colors.red),
          ),
        ),
      );
    }
  }
}

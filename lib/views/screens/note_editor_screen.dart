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
import '../../models/user_model.dart';
import '../../services/mastery_service.dart';
import '../widgets/handwriting_canvas.dart';
import '../../services/transcript_recovery_service.dart';
import '../widgets/recording_bar_widget.dart';
import '../widgets/aura_alert_banner.dart';

enum NoteEditorMode { write, capture, draw, generate }

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

  NoteEditorMode _mode = NoteEditorMode.write;
  bool _isInitialized = false;
  bool _showSidebar = false;
  Offset? _lensPosition;

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
            _controller.onSelectionChanged = _handleSelectionChanged;
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

    // Highlight keywords
    final List<String> keywords = [
      'mitochondria',
      'energy',
      'atp',
      'cell',
      'nucleus',
      'important',
      'exam'
    ];
    final lowerText = textToInsert.toLowerCase();
    for (final keyword in keywords) {
      int idx = lowerText.indexOf(keyword);
      while (idx != -1) {
        _controller.formatText(
            insertionIndex + idx,
            keyword.length,
            quill.Attribute.clone(quill.Attribute.color,
                Colors.orangeAccent.toARGB32().toRadixString(16)));
        idx = lowerText.indexOf(keyword, idx + keyword.length);
      }
    }

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
          _controller.onSelectionChanged = _handleSelectionChanged;
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
    final noteProvider = context.watch<NoteProvider>();
    final user = Provider.of<UserModel?>(context);
    final isRecording = noteProvider.state == NoteProcessingState.recording;

    // Show subscription screen if limit reached
    if (noteProvider.limitReached) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          noteProvider.clearError(); // resets limitReached to false
          context.push('/settings/subscription');
        }
      });
    }

    if (!_isInitialized) {
      return Scaffold(
          backgroundColor: colorScheme.surface,
          body: Center(
              child: CircularProgressIndicator(color: colorScheme.primary)));
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
              _buildTopBar(isRecording, theme),
              if (_mode == NoteEditorMode.write) _buildQuillToolbar(theme),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: _buildEditorArea(noteProvider, theme, isRecording),
                    ),
                    if (isRecording)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: RecordingBarWidget(),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: isRecording ? 96 : 16,
                      child: _buildWorkspaceDock(noteProvider, user, theme),
                    ),
                    if (_showSidebar) ...[
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _showSidebar = false),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.18),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isRecording, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
            bottom:
                BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF1F5F9),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _titleController,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Untitled Note',
                border: InputBorder.none,
                hintStyle: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          if (isRecording) _buildCaptureBadge(theme),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () => setState(() => _showSidebar = !_showSidebar),
            tooltip:
                _showSidebar ? 'Hide context panel' : 'Topics & recordings',
            icon: Icon(
                _showSidebar
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_rounded,
                size: 18,
                color: isDark ? Colors.white70 : const Color(0xFF475569)),
            style: IconButton.styleFrom(
              backgroundColor: _showSidebar
                  ? const Color(0xFF6B5CE7).withValues(alpha: 0.15)
                  : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceDock(
      NoteProvider noteProvider, UserModel? user, ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _buildModePanel(noteProvider, user, theme),
        ),
        const SizedBox(height: 10),
        Material(
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          color: colorScheme.surface.withValues(alpha: 0.96),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.08)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showLabels = constraints.maxWidth >= 360;
                return Row(
                  children: [
                    _buildModeButton(
                      mode: NoteEditorMode.write,
                      icon: Icons.edit_note_rounded,
                      label: 'Write',
                      theme: theme,
                      showLabel: showLabels,
                    ),
                    _buildModeButton(
                      mode: NoteEditorMode.capture,
                      icon: Icons.mic_rounded,
                      label: 'Capture',
                      theme: theme,
                      showLabel: showLabels,
                    ),
                    _buildModeButton(
                      mode: NoteEditorMode.draw,
                      icon: Icons.draw_rounded,
                      label: 'Draw',
                      theme: theme,
                      showLabel: showLabels,
                    ),
                    _buildModeButton(
                      mode: NoteEditorMode.generate,
                      icon: Icons.auto_awesome_rounded,
                      label: 'Generate',
                      theme: theme,
                      showLabel: showLabels,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required NoteEditorMode mode,
    required IconData icon,
    required String label,
    required ThemeData theme,
    required bool showLabel,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final isActive = _mode == mode;

    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: () => setState(() => _mode = mode),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF6B5CE7).withValues(alpha: isDark ? 0.25 : 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF6B5CE7).withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive
                      ? const Color(0xFF6B5CE7)
                      : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        color: isActive
                            ? const Color(0xFF6B5CE7)
                            : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModePanel(
      NoteProvider noteProvider, UserModel? user, ThemeData theme) {
    switch (_mode) {
      case NoteEditorMode.capture:
        return _buildCapturePanel(noteProvider, user, theme);
      case NoteEditorMode.draw:
        return _buildDrawPanel(noteProvider, theme);
      case NoteEditorMode.generate:
        return _buildGeneratePanel(noteProvider, user, theme);
      case NoteEditorMode.write:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCapturePanel(
      NoteProvider provider, UserModel? user, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isRecording = provider.state == NoteProcessingState.recording;

    return _buildFloatingPanel(
      theme: theme,
      child: Row(
        children: [
          Icon(
            isRecording ? Icons.hearing_rounded : Icons.graphic_eq_rounded,
            color: isRecording ? colorScheme.error : colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isRecording
                  ? (provider.liveTranscript.isNotEmpty
                      ? provider.liveTranscript
                      : 'Listening for lecture audio...')
                  : 'Capture lecture speech, upload diagrams, or add an image.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Upload diagram',
            onPressed: _insertImage,
            icon: const Icon(Icons.add_photo_alternate_rounded),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: isRecording ? 'Stop recording' : 'Start live lecture',
            onPressed: () {
              if (isRecording) {
                provider.stopRecording();
              } else {
                provider.startRecording(user?.uid ?? '');
              }
            },
            icon: Icon(isRecording ? Icons.stop_rounded : Icons.mic_rounded),
            style: IconButton.styleFrom(
              backgroundColor:
                  isRecording ? colorScheme.error : colorScheme.primary,
              foregroundColor:
                  isRecording ? colorScheme.onError : colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawPanel(NoteProvider provider, ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return _buildFloatingPanel(
      theme: theme,
      child: Row(
        children: [
          Icon(Icons.gesture_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Draw directly over this note. Strokes can stay synced to lecture time.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Undo drawing stroke',
            onPressed: provider.drawingStrokes.isEmpty
                ? null
                : () => provider.undoLastStroke(),
            icon: const Icon(Icons.undo_rounded),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Clear drawing',
            onPressed: provider.drawingStrokes.isEmpty
                ? null
                : () => provider.clearStrokes(),
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratePanel(
      NoteProvider provider, UserModel? user, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isGenerating = provider.state == NoteProcessingState.generating;
    final isCleaning = provider.state == NoteProcessingState.cleaning_up;

    return _buildFloatingPanel(
      theme: theme,
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: colorScheme.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCleaning
                  ? 'Organizing your lecture notes...'
                  : isGenerating
                      ? 'Building your study pack...'
                      : 'Create summary, quiz, and flashcards from this note.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: user == null || isGenerating || isCleaning
                ? null
                : () async {
                    if (provider.state == NoteProcessingState.recording) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please stop recording before synthesizing study materials.'),
                          backgroundColor: Colors.orangeAccent,
                        ),
                      );
                      return;
                    }

                    final folderId =
                        await provider.generateStudyMaterials(user.uid);
                    if (folderId != null && mounted) {
                      context.pushNamed('results-view',
                          pathParameters: {'folderId': folderId});
                    }
                  },
            icon: isGenerating || isCleaning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bolt_rounded),
            label: Text(isCleaning
                ? 'Organizing'
                : isGenerating
                    ? 'Generating'
                    : 'Generate'),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingPanel({
    required ThemeData theme,
    required Widget child,
  }) {
    final colorScheme = theme.colorScheme;
    return Material(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(24),
      color: colorScheme.surface.withValues(alpha: 0.98),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
        ),
        child: child,
      ),
    );
  }

  Widget _buildCaptureBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(100),
        border:
            Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: theme.colorScheme.error, shape: BoxShape.circle),
          ).animate(onPlay: (c) => c.repeat()).fadeIn().fadeOut(),
          const SizedBox(width: 8),
          Text(
            'LIVE RECORDING',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }

  Widget _buildQuillToolbar(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(
          bottom:
              BorderSide(color: colorScheme.outline.withValues(alpha: 0.08)),
        ),
      ),
      child: quill.QuillSimpleToolbar(
        controller: _controller,
        config: quill.QuillSimpleToolbarConfig(
          showFontFamily: false,
          showFontSize: false,
          showBackgroundColorButton: false,
          showClearFormat: true,
          showColorButton: true,
          showCodeBlock: false,
          showInlineCode: false,
          showSubscript: false,
          showSuperscript: false,
          showHeaderStyle: true,
          showListCheck: true,
          showQuote: true,
          showIndent: true,
          showLink: false,
          showSearchButton: false,
          toolbarSize: 44,
        ),
      ),
    );
  }

  Widget _buildEditorArea(NoteProvider provider, ThemeData theme,
      [bool isRecording = false]) {
    final colorScheme = theme.colorScheme;
    final bottomInset = switch (_mode) {
      NoteEditorMode.write => isRecording ? 172.0 : 112.0,
      _ => isRecording ? 244.0 : 172.0,
    };

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
                padding: EdgeInsets.fromLTRB(
                  40,
                  40,
                  40,
                  bottomInset,
                ),
                placeholder: 'Start typing, recording, or sketching...',
                embedBuilders: [
                  ImageEmbedBuilder(),
                ],
                customStyles: quill.DefaultStyles(
                  paragraph: quill.DefaultTextBlockStyle(
                    GoogleFonts.inter(
                        fontSize: 16,
                        height: 1.8,
                        color: colorScheme.onSurface),
                    const quill.HorizontalSpacing(0, 0),
                    const quill.VerticalSpacing(0, 0),
                    const quill.VerticalSpacing(0, 0),
                    null,
                  ),
                  h1: quill.DefaultTextBlockStyle(
                    GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface),
                    const quill.HorizontalSpacing(0, 0),
                    const quill.VerticalSpacing(16, 0),
                    const quill.VerticalSpacing(0, 0),
                    null,
                  ),
                  h2: quill.DefaultTextBlockStyle(
                    GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface),
                    const quill.HorizontalSpacing(0, 0),
                    const quill.VerticalSpacing(12, 0),
                    const quill.VerticalSpacing(0, 0),
                    null,
                  ),
                ),
              ),
            ),
          ),
          if (_mode == NoteEditorMode.draw)
            Positioned.fill(
              child: HandwritingCanvas(
                strokes: provider.drawingStrokes,
                onStrokeComplete: (stroke) => provider.addDrawingStroke(stroke),
                currentAudioTime: provider.recordingDuration,
                onStrokeTap: (time) => provider.seekAudio(time),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRightSidebar(NoteProvider provider, ThemeData theme) {
    final note = provider.currentNote;
    final colorScheme = theme.colorScheme;

    return Material(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          border: Border(
              left: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.12))),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildCollapsibleSidebarSection(
              theme: theme,
              title: 'TOPICS & ENTITIES',
              child: _buildTopicsContent(note?.topicNames ?? [], theme),
            ),
            const SizedBox(height: 4),
            _buildCollapsibleSidebarSection(
              theme: theme,
              title: 'AUDIO SESSIONS',
              child: _buildRecordingsContent(provider, theme),
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
        initiallyExpanded: false,
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
        'Extracting context...',
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
                padding: const EdgeInsets.only(bottom: 12),
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
                    const SizedBox(width: 12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provider.currentNoteRecordings.isEmpty)
          Text('No recordings yet.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic)),
        ...provider.currentNoteRecordings.map((rec) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.1)),
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
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface),
                        ),
                        Text(
                          '${rec.durationSeconds}s • ${rec.createdAt.hour}:${rec.createdAt.minute.toString().padLeft(2, '0')}',
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
            )),
      ],
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

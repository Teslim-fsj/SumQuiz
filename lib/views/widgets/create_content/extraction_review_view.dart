import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/create_content_provider.dart';
import '../../../models/user_model.dart';
import '../../../utils/youtube_pro_gate.dart';
import '../../../widgets/sumi_mascot.dart';
import '../../../models/sumi_emotion.dart';

class ExtractionReviewView extends StatefulWidget {
  const ExtractionReviewView({super.key});

  @override
  State<ExtractionReviewView> createState() => _ExtractionReviewViewState();
}

class _ExtractionReviewViewState extends State<ExtractionReviewView> {
  late TextEditingController _textController;
  late TextEditingController _titleController;
  bool _isSavingNote = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<CreateContentProvider>(context, listen: false);
    _textController = TextEditingController(text: provider.textContent);
    _titleController =
        TextEditingController(text: provider.fileName ?? 'Untitled Creation');

    // Keep provider in sync as the user edits
    _textController.addListener(() {
      provider.updateExtractedText(_textController.text);
    });
    _titleController.addListener(() {
      provider.updateTitle(_titleController.text);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _onContinue(BuildContext context) async {
    final provider = Provider.of<CreateContentProvider>(context, listen: false);
    final user = Provider.of<UserModel?>(context, listen: false);

    // Flush any pending title edit to the provider
    provider.updateTitle(_titleController.text.trim().isEmpty
        ? 'Untitled Study Pack'
        : _titleController.text.trim());

    // Save the note immediately if the toggle is on —
    // this guarantees the note is stored regardless of generation outcome.
    if (provider.saveAsNote && user != null) {
      setState(() => _isSavingNote = true);
      try {
        await provider.saveNoteNow(user.uid);
      } catch (_) {
        // Non-fatal — log but continue to generation
      } finally {
        if (mounted) setState(() => _isSavingNote = false);
      }
    }

    if (!mounted) return;

    // Skip the config step and go straight to generation.
    if (user != null) {
      provider.startGeneration(
        user.uid,
        allowYouTubeImport: userMayImportFromYouTube(user),
        allowPdfImport: userMayImportFromPdf(user),
        allowWebImport: userMayImportFromWeb(user),
      );
    } else {
      // Fallback: proceed to config if user is somehow null
      provider.proceedToConfig();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = Provider.of<CreateContentProvider>(context);

    final bool isBusy = _isSavingNote || provider.progressMessage.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            children: [
              const SumiMascot(
                state: SumiState.focused,
                size: 60,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Extracted Content',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Edit the text if needed, then continue to generate your study pack.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // AI clean-up button
              IconButton.filledTonal(
                onPressed: isBusy ? null : () => provider.refineExtractedText(),
                icon: provider.progressMessage.contains('cleaning')
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_rounded, size: 20),
                tooltip: 'Clean up with AI',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Title field ───────────────────────────────────────────────────
          Text(
            'Study Pack Title',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Enter title...',
              filled: true,
              fillColor: theme.cardColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Extracted text ────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    height: 1.6,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'No text extracted...',
                    contentPadding: const EdgeInsets.all(20),
                    border: InputBorder.none,
                    filled: true,
                    fillColor: theme.cardColor,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Save-as-note toggle ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.description_rounded,
                    color: colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Save as Study Note',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Keeps the extracted text in your library for later',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: provider.saveAsNote,
                  onChanged: (v) => provider.toggleSaveAsNote(v),
                  activeTrackColor: colorScheme.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Continue button ───────────────────────────────────────────────
          ElevatedButton(
            onPressed: isBusy ? null : () => _onContinue(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 4,
              shadowColor: colorScheme.primary.withValues(alpha: 0.3),
              disabledBackgroundColor:
                  colorScheme.primary.withValues(alpha: 0.4),
            ),
            child: isBusy
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 12),
                      Text(
                        _isSavingNote ? 'Saving note...' : 'Preparing...',
                        style: GoogleFonts.poppins(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Generate Study Pack',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: isBusy ? null : provider.backToSource,
            child: Text(
              'Discard & Change Source',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.error,
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

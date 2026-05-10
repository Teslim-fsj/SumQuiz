import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/create_content_provider.dart';

class ExtractionReviewView extends StatefulWidget {
  const ExtractionReviewView({super.key});

  @override
  State<ExtractionReviewView> createState() => _ExtractionReviewViewState();
}

class _ExtractionReviewViewState extends State<ExtractionReviewView> {
  late TextEditingController _textController;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<CreateContentProvider>(context, listen: false);
    _textController = TextEditingController(text: provider.textContent);
    _titleController =
        TextEditingController(text: provider.fileName ?? 'Untitled Creation');

    _textController.addListener(() {
      provider.updateExtractedText(_textController.text);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = Provider.of<CreateContentProvider>(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_stories_rounded,
                    color: colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Extracted Content',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'AI extracted this from your source. Review and edit if needed.',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: provider.progressMessage.isNotEmpty
                    ? null
                    : () => provider.refineExtractedText(),
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
          const SizedBox(height: 24),
          Text(
            'Source Title',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: GoogleFonts.outfit(
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
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    height: 1.6,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'No text extracted...',
                    contentPadding: const EdgeInsets.all(24),
                    border: InputBorder.none,
                    filled: true,
                    fillColor: theme.cardColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- OPTIONS ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
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
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Add this to your library for future reference',
                        style: GoogleFonts.outfit(
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
                  activeColor: colorScheme.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              provider.updateTitle(_titleController.text);
              provider.proceedToConfig();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 4,
              shadowColor: colorScheme.primary.withOpacity(0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Confirm & Continue',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: provider.backToSource,
            child: Text(
              'Discard & Change Source',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/editable_content.dart';
import 'package:sumquiz/models/flashcard.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/services/firestore_service.dart';

class EditFlashcardsScreen extends StatefulWidget {
  final EditableContent content;

  const EditFlashcardsScreen({super.key, required this.content});

  @override
  State<EditFlashcardsScreen> createState() => _EditFlashcardsScreenState();
}

class _EditFlashcardsScreenState extends State<EditFlashcardsScreen> {
  late TextEditingController _titleController;
  late List<Flashcard> _flashcards;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.content.title);
    _flashcards = List.from(widget.content.flashcards ?? []);
  }

  Future<void> _save() async {
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to save.')));
      return;
    }

    try {
      await firestoreService.updateFlashcardSet(
          user.uid, widget.content.id, _titleController.text, _flashcards);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Flashcards saved successfully')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving flashcards: $e')));
      }
    }
  }

  void _addFlashcard() {
    setState(() {
      _flashcards.add(Flashcard(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Temp ID
        question: 'New Question',
        answer: 'New Answer',
      ));
    });
  }

  void _deleteFlashcard(int index) {
    setState(() {
      _flashcards.removeAt(index);
    });
  }

  void _updateFlashcard(int index, String question, String answer) {
    setState(() {
      _flashcards[index] = Flashcard(
        id: _flashcards[index].id,
        question: question,
        answer: answer,
      );
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _titleController.text.isEmpty ? 'Edit Set' : _titleController.text,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: theme.colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: theme.colorScheme.primary),
            onPressed: _save,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated Background
          Animate(
            onPlay: (controller) => controller.repeat(reverse: true),
            effects: [
              CustomEffect(
                duration: 10.seconds,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                theme.colorScheme.surface,
                                Color.lerp(theme.colorScheme.surface,
                                    theme.colorScheme.primaryContainer, value)!,
                              ]
                            : [
                                const Color(0xFFE8EAF6), // Indigo 50
                                Color.lerp(
                                    const Color(0xFFE8EAF6),
                                    const Color(0xFFC5CAE9),
                                    value)!, // Indigo 100
                              ],
                      ),
                    ),
                    child: child,
                  );
                },
              )
            ],
            child: Container(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  _buildGlassSection(
                    theme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Set Title',
                            style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7))),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titleController,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: theme.cardColor.withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) => setState(() {}),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.1),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _flashcards.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildFlashcardEditor(index, theme)
                            .animate(delay: (100 * index).ms)
                            .fadeIn()
                            .slideX();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBottomBar(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Text('${_flashcards.length} cards',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addFlashcard,
              icon: const Icon(Icons.add),
              label: const Text('Add Flashcard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcardEditor(int index, ThemeData theme) {
    final card = _flashcards[index];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Front Input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor.withValues(alpha: 0.3),
                  border: Border(
                      bottom: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.1))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Front',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: theme.colorScheme.error
                                  .withValues(alpha: 0.8),
                              size: 20),
                          onPressed: () => _deleteFlashcard(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    TextFormField(
                      initialValue: card.question,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter question',
                        hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (val) =>
                          _updateFlashcard(index, val, card.answer),
                      maxLines: null,
                    ),
                  ],
                ),
              ),
              // Back Input
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Back',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold)),
                    TextFormField(
                      initialValue: card.answer,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter answer',
                        hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (val) =>
                          _updateFlashcard(index, card.question, val),
                      maxLines: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSection(ThemeData theme, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

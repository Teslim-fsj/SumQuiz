import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/local_note.dart';
import '../../providers/note_provider.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NoteProvider>().watchNotes(user.uid);
      });
    }
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteProvider = context.watch<NoteProvider>();
    final user = Provider.of<UserModel?>(context);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final filteredNotes = noteProvider.allNotes.where((note) {
      return note.title.toLowerCase().contains(_searchQuery) ||
          note.content.toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Notes',
            style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background decorations could go here
          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(theme),
                Expanded(
                  child: filteredNotes.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = filteredNotes[index];
                            return _buildNoteCard(note, theme, noteProvider);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newNote = await noteProvider.createNewNote(user.uid);
          if (mounted) {
            context.push('/notes/${newNote.id}');
          }
        },
        child: const Icon(Icons.add_comment_rounded),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.7),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search notes...',
            prefixIcon: const Icon(Icons.search),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildNoteCard(LocalNote note, ThemeData theme, NoteProvider provider) {
    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => provider.deleteNote(note.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                note.title.isEmpty ? 'Untitled Note' : note.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    note.content.isEmpty ? 'No content' : note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: theme.colorScheme.primary.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, h:mm a').format(note.updatedAt),
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary.withOpacity(0.6)),
                      ),
                      const Spacer(),
                      if (note.tags.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '#${note.tags.first}',
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              onTap: () {
                context.push('/notes/${note.id}');
              },
            ),
          ),
        ),
      ).animate().fadeIn().slideX(begin: 0.1),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_alt_outlined, size: 80, color: theme.colorScheme.primary.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No notes found',
            style: TextStyle(fontSize: 18, color: theme.colorScheme.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first note',
            style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.4)),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

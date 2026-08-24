import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/teacher_service.dart';
import 'package:sumquiz/theme/web_theme.dart';

/// A teacher's shared study packs and exams. These are the learning units
/// students use, keeping sharing, participation, and results in one workflow.
class TeacherClassroomsListScreen extends StatefulWidget {
  const TeacherClassroomsListScreen({super.key});

  @override
  State<TeacherClassroomsListScreen> createState() =>
      _TeacherClassroomsListScreenState();
}

class _TeacherClassroomsListScreenState
    extends State<TeacherClassroomsListScreen> {
  final _teacherService = TeacherService();
  late Future<List<PublicDeck>> _content;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserModel?>();
    _content = user == null
        ? Future.value([])
        : _teacherService.getTeacherContent(user.uid);
  }

  Future<void> _refresh() async {
    final user = context.read<UserModel?>();
    setState(() {
      _content = user == null
          ? Future.value([])
          : _teacherService.getTeacherContent(user.uid);
    });
    await _content;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Teaching materials',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: foreground,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Create material',
            onPressed: () => context.push('/create-content'),
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: WebColors.purplePrimary,
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<PublicDeck>>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final decks = snapshot.data ?? [];
          if (decks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      size: 52,
                      color: WebColors.purplePrimary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Start with a study pack or exam',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share it with students to track participation and results.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => context.push('/create-content'),
                      icon: const Icon(Icons.add),
                      label: const Text('Create study pack'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: decks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final deck = decks[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: WebColors.purplePrimary.withValues(
                        alpha: .12,
                      ),
                      child: Icon(
                        deck.isExam
                            ? Icons.quiz_outlined
                            : Icons.menu_book_outlined,
                        color: WebColors.purplePrimary,
                      ),
                    ),
                    title: Text(
                      deck.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${deck.isExam ? 'Exam' : 'Study pack'} · '
                      '${deck.startedCount} started · ${deck.completedCount} completed',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/teacher/classroom/${deck.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

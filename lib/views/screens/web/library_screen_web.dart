import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/models/library_item.dart';
import 'package:sumquiz/models/folder.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:sumquiz/models/editable_content.dart';
import 'package:sumquiz/models/quiz_question.dart';
import 'package:sumquiz/models/flashcard.dart';
import 'package:sumquiz/views/screens/edit_summary_screen.dart';
import 'package:sumquiz/views/screens/edit_quiz_screen.dart';
import 'package:sumquiz/views/screens/edit_flashcards_screen.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/view_models/library_view_model.dart';
import 'package:sumquiz/view_models/quiz_view_model.dart';
import 'package:sumquiz/services/sync_service.dart';
import 'package:intl/intl.dart';
import 'package:sumquiz/views/widgets/enter_code_dialog.dart';
import 'package:sumquiz/views/widgets/web/web_library_header.dart';
import 'package:sumquiz/views/widgets/web/web_library_empty_state.dart';
import 'package:sumquiz/views/widgets/web/web_feature_info_cards.dart';

class LibraryScreenWeb extends StatefulWidget {
  const LibraryScreenWeb({super.key});

  @override
  LibraryScreenWebState createState() => LibraryScreenWebState();
}

class LibraryScreenWebState extends State<LibraryScreenWeb> {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  LibraryViewModel? _viewModel;
  bool _isNavigating = false;
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _localDb.init();
  }

  void _initViewModel(UserModel user) {
    _viewModel ??= LibraryViewModel(
      localDb: _localDb,
      firestoreService: context.read<FirestoreService>(),
      syncService: context.read<SyncService>(),
      userId: user.uid,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<UserModel?>(context);
    if (user != null) {
      _initViewModel(user);
      if (mounted) {
        Provider.of<QuizViewModel>(context, listen: false)
            .initializeForUser(user.uid);
      }
    }
  }

  void _onSearchChanged() =>
      setState(() => _searchQuery = _searchController.text.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final viewModel = _viewModel;

    if (user == null) {
      return _buildLoginPrompt();
    }

    if (viewModel == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Consumer<LibraryViewModel>(
        builder: (context, viewModel, child) {
          return Stack(
            children: [
              Container(
                color: const Color(0xFFF8FAFC),
                child: Column(
                  children: [
                    WebLibraryHeader(
                      searchController: _searchController,
                      onImport: () {
                        showDialog(
                          context: context,
                          builder: (context) => const EnterCodeDialog(),
                        );
                      },
                      onNotifications: () {},
                      onProfile: () => context.push('/profile'),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeroSection(viewModel),
                            const SizedBox(height: 8),
                            _buildCategoryFilters(),
                            const SizedBox(height: 12),
                            _buildDynamicContent(user.uid, viewModel),
                            const SizedBox(height: 24),
                            const WebFeatureInfoCards(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isNavigating)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Preparing Content...',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoginPrompt() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_person,
              size: 60,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          Text("Please Log In to View Library",
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/auth'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(LibraryViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Generated badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: WebColors.purplePrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'AI GENERATED CONTENT',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: WebColors.purplePrimary,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'Content Library',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            if (viewModel.isSyncing) ...[
              const SizedBox(width: 24),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: WebColors.purplePrimary),
              ).animate().fadeIn(),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Manage and access your AI-generated learning materials. Everything you\'ve researched, synthesized, and mastered in one place.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters() {
    final categories = [
      {'label': 'All Content', 'icon': Icons.grid_view_rounded},
      {'label': 'Notes', 'icon': Icons.note_alt_rounded},
      {'label': 'Study Packs', 'icon': Icons.folder_copy_rounded},
      {'label': 'Quizzes', 'icon': Icons.quiz_rounded},
      {'label': 'Exams', 'icon': Icons.assignment_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(categories.length, (index) {
          final isSelected = _selectedFilter == index;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                setState(() => _selectedFilter = index);
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? WebColors.purplePrimary
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: WebColors.purplePrimary
                                  .withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      categories[index]['icon'] as IconData,
                      size: 18,
                      color: isSelected
                          ? WebColors.purplePrimary
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      categories[index]['label'] as String,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isSelected
                          ? WebColors.purplePrimary
                          : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDynamicContent(String userId, LibraryViewModel viewModel) {
    // Map filter index to the correct stream matching mobile library
    final stream = switch (_selectedFilter) {
      1 => viewModel.allNotes$,
      2 => viewModel.studyPack$,
      3 => viewModel.allQuizzes$,
      4 => viewModel.allExams$,
      0 || _ => viewModel.allItems$,
    };

    return StreamBuilder<List<LibraryItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(100.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final items = snapshot.data ?? [];
        final filtered = items
            .where((i) => i.title.toLowerCase().contains(_searchQuery))
            .toList();
        if (filtered.isEmpty) {
          return WebLibraryEmptyState(
            onBuildPack: () => context.push('/create-content'),
            onCreateNew: () => context.push('/create-content'),
          );
        }

        return _buildContentGrid(filtered, userId, viewModel);
      },
    );
  }

  Widget _buildContentGrid(
      List<LibraryItem> items, String userId, LibraryViewModel viewModel) {
    final cardData = items.map((item) {
      IconData icon;
      Color bgColor;
      Color textColor;
      String typeName;
      String badge;

      switch (item.type) {
        case LibraryItemType.summary:
          icon = Icons.description_outlined;
          bgColor = WebColors.secondary.withValues(alpha: 0.1);
          textColor = WebColors.secondary;
          typeName = 'SUMMARY';
          badge = item.itemCount != null
              ? '${item.itemCount} Sections'
              : 'Detailed Analysis';
          break;
        case LibraryItemType.quiz:
          icon = Icons.quiz_outlined;
          bgColor = WebColors.accentOrange.withValues(alpha: 0.1);
          textColor = WebColors.accentOrange;
          typeName = 'QUIZ';
          badge = item.score != null
              ? 'Score: ${(item.score! * 100).round()}%'
              : '${item.itemCount ?? 0} Questions';
          break;
        case LibraryItemType.flashcards:
          icon = Icons.style_outlined;
          bgColor = WebColors.pinkAccent.withValues(alpha: 0.1);
          textColor = WebColors.pinkAccent;
          typeName = 'FLASHCARDS';
          badge = '${item.itemCount ?? 0} Cards';
          break;
        case LibraryItemType.exam:
          icon = Icons.assignment_outlined;
          bgColor = WebColors.purplePrimary.withValues(alpha: 0.1);
          textColor = WebColors.purplePrimary;
          typeName = 'EXAM';
          badge = item.score != null
              ? 'Score: ${(item.score! * 100).round()}%'
              : '${item.itemCount ?? 0} Questions';
          break;
        case LibraryItemType.note:
          icon = Icons.note_alt_outlined;
          bgColor = WebColors.secondary.withValues(alpha: 0.1);
          textColor = WebColors.secondary;
          typeName = 'NOTE';
          badge = 'Smart Note';
          break;
        case LibraryItemType.folder:
          icon = Icons.folder_open_outlined;
          bgColor = Colors.deepPurple.withValues(alpha: 0.1);
          textColor = Colors.deepPurple;
          typeName = 'STUDY PACK';
          badge = 'Folder';
          break;
      }

      return _LibraryCardData(
        title: item.title,
        subtitle: _getDescriptionForType(item),
        icon: icon,
        bgColor: bgColor,
        textColor: textColor,
        typeName: typeName,
        badge: badge,
        date: DateFormat('MMM dd, yyyy').format(item.timestamp.toDate()),
        onTap: () => _navigateToContent(item),
        onEdit: () => _navigateToEdit(item),
      );
    }).toList();

    // Add the "New Resource" card
    cardData.add(_LibraryCardData(
      title: 'New Resource',
      subtitle: 'Upload a PDF or link',
      icon: Icons.add_outlined,
      bgColor: Theme.of(context).cardColor,
      textColor: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
      typeName: '',
      badge: '',
      date: '',
      isAddCard: true,
      onTap: () => context.push('/create-content'),
    ));

    return _buildMasonryGrid(cardData);
  }

  String _getDescriptionForType(LibraryItem item) {
    if (item.description != null && item.description!.isNotEmpty) {
      return item.description!;
    }
    switch (item.type) {
      case LibraryItemType.summary:
        return 'Detailed summary generated from your source content.';
      case LibraryItemType.quiz:
        return 'Practice quiz with ${item.itemCount ?? 0} questions to test your knowledge.';
      case LibraryItemType.flashcards:
        return 'Study deck with ${item.itemCount ?? 0} flashcards for spaced repetition.';
      case LibraryItemType.exam:
        return 'Formal exam paper with ${item.itemCount ?? 0} questions.';
      case LibraryItemType.note:
        return 'Personal study notes and lecture transcriptions.';
      case LibraryItemType.folder:
        return 'Collection of related study materials and notes.';
    }
  }

  Widget _buildMasonryGrid(List<_LibraryCardData> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 900) crossAxisCount = 2;
        if (constraints.maxWidth < 600) crossAxisCount = 1;

        return GridView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return _buildLibraryCard(card: card, delay: index * 40);
          },
        );
      },
    );
  }

  Widget _buildLibraryCard({
    required _LibraryCardData card,
    required int delay,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: WebColors.glassDecoration(
          blur: 15,
          opacity: 0.05,
          color: WebColors.surface,
          borderRadius: 16,
        ).copyWith(
          boxShadow: WebColors.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: card.onTap,
              hoverColor: card.textColor.withValues(alpha: 0.05),
              splashColor: card.textColor.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: card.textColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              Icon(card.icon, color: card.textColor, size: 24),
                        ),
                        if (card.typeName.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: card.textColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  card.typeName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: card.textColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (card.onEdit != null) ...[
                                const SizedBox(width: 6),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded,
                                      color:
                                          card.textColor.withValues(alpha: 0.7),
                                      size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      card.onEdit!();
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit_rounded,
                                              size: 16),
                                          const SizedBox(width: 8),
                                          Text('Edit',
                                              style: GoogleFonts.outfit(
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      card.title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: WebColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.date,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: WebColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          card.typeName == 'QUIZ'
                              ? Icons.emoji_events_outlined
                              : (card.typeName == 'FLASHCARDS'
                                  ? Icons.layers_outlined
                                  : Icons.read_more_outlined),
                          size: 14,
                          color: card.textColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          card.badge,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: card.textColor,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward,
                            size: 16,
                            color: card.textColor.withValues(alpha: 0.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
          duration: 400.ms,
        );
  }

  Future<void> _navigateToContent(LibraryItem item) async {
    debugPrint(
        '🔍 Navigating to content: ${item.type} - ${item.title} (ID: ${item.id})');
    setState(() => _isNavigating = true);

    try {
      if (!mounted) {
        debugPrint('⚠️ Widget not mounted, aborting navigation');
        setState(() => _isNavigating = false);
        return;
      }

      final db = LocalDatabaseService();
      switch (item.type) {
        case LibraryItemType.note:
          context.push('/notes/${item.id}');
          return;
        case LibraryItemType.folder:
          _viewModel?.selectFolder(Folder(
            id: item.id,
            name: item.title,
            userId: item.userId ?? '',
            createdAt: item.timestamp.toDate(),
            updatedAt: item.timestamp.toDate(),
          ));
          return;
        case LibraryItemType.summary:
        case LibraryItemType.quiz:
        case LibraryItemType.exam:
        case LibraryItemType.flashcards:
          break;
      }

      final tab = switch (item.type) {
        LibraryItemType.summary => 0,
        LibraryItemType.quiz || LibraryItemType.exam => 1,
        LibraryItemType.flashcards => 2,
        _ => 0,
      };

      final parentFolderId = await db.getParentFolderId(item.id);
      if (parentFolderId != null) {
        context.pushNamed(
          'results-view',
          pathParameters: {'folderId': parentFolderId},
          queryParameters: {'tab': tab.toString()},
        );
        return;
      }

      switch (item.type) {
        case LibraryItemType.summary:
          context.push('/library/summary/${item.id}');
          break;
        case LibraryItemType.quiz:
        case LibraryItemType.exam:
          context.push('/library/quiz/${item.id}');
          break;
        case LibraryItemType.flashcards:
          context.push('/library/flashcards/${item.id}');
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  void _navigateToEdit(LibraryItem item) async {
    final db = LocalDatabaseService();
    if (item.type == LibraryItemType.summary) {
      final localSummary = await db.getSummary(item.id);
      if (localSummary != null && mounted) {
        final editable = EditableContent.fromSummary(
          localSummary.id,
          localSummary.title,
          localSummary.content,
          localSummary.tags,
          Timestamp.fromDate(localSummary.timestamp),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => EditSummaryScreen(content: editable)),
        );
      }
    } else if (item.type == LibraryItemType.quiz ||
        item.type == LibraryItemType.exam) {
      final localQuiz = await db.getQuiz(item.id);
      if (localQuiz != null && mounted) {
        final questions = localQuiz.questions
            .map((q) => QuizQuestion(
                  question: q.question,
                  options: q.options,
                  correctAnswer: q.correctAnswer,
                  explanation: q.explanation,
                  questionType: q.questionType,
                ))
            .toList();
        final editable = EditableContent.fromQuiz(
          localQuiz.id,
          localQuiz.title,
          questions,
          Timestamp.fromDate(localQuiz.timestamp),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => EditQuizScreen(content: editable)),
        );
      }
    } else if (item.type == LibraryItemType.flashcards) {
      final localSet = await db.getFlashcardSet(item.id);
      if (localSet != null && mounted) {
        final flashcards = localSet.flashcards
            .map((f) => Flashcard(
                  id: f.id,
                  question: f.question,
                  answer: f.answer,
                ))
            .toList();
        final editable = EditableContent.fromFlashcardSet(
          localSet.id,
          localSet.title,
          flashcards,
          Timestamp.fromDate(localSet.timestamp),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => EditFlashcardsScreen(content: editable)),
        );
      }
    } else if (item.type == LibraryItemType.note) {
      context.push('/notes/${item.id}');
    } else if (item.type == LibraryItemType.folder) {
      _showRenameFolderDialog(item);
    }
  }

  void _showRenameFolderDialog(LibraryItem item) {
    final controller = TextEditingController(text: item.title);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Rename Study Pack',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter name...',
              labelText: 'Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  final db = LocalDatabaseService();
                  final folder = Folder(
                    id: item.id,
                    name: newName,
                    userId: item.userId ?? '',
                    createdAt: item.timestamp.toDate(),
                    updatedAt: DateTime.now(),
                  );
                  await db.saveFolder(folder);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Study pack renamed successfully!')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _LibraryCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bgColor;
  final Color textColor;
  final String typeName;
  final String badge;
  final String date;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final bool isAddCard;

  _LibraryCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bgColor,
    required this.textColor,
    required this.typeName,
    required this.badge,
    required this.date,
    required this.onTap,
    this.onEdit,
    this.isAddCard = false,
  });
}

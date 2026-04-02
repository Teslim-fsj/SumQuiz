import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/models/library_item.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/view_models/library_view_model.dart';
import 'package:sumquiz/view_models/quiz_view_model.dart';
import 'package:sumquiz/services/sync_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sumquiz/views/widgets/enter_code_dialog.dart';

class LibraryScreenWeb extends StatefulWidget {
  const LibraryScreenWeb({super.key});

  @override
  LibraryScreenWebState createState() => LibraryScreenWebState();
}

class LibraryScreenWebState extends State<LibraryScreenWeb>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  final String _activeSidebarSection = 'All Content';
  LibraryViewModel? _viewModel;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
    final theme = Theme.of(context);
    final viewModel = _viewModel;

    if (user == null) {
      return Scaffold(body: _buildLoginPrompt());
    }

    if (viewModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Stack(
        children: [
          Consumer<LibraryViewModel>(
            builder: (context, viewModel, child) {
              return Scaffold(
                backgroundColor: theme.colorScheme.surface,
                body: Column(
                  children: [
                    _buildModernHeader(user, viewModel),
                    Expanded(
                      child: _buildMainContent(user, viewModel),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_isNavigating)
            Container(
              color: Colors.black.withOpacity(0.3),
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
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
              color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(height: 20),
          Text(
            "Please Log In to View Library",
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
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

  Widget _buildModernHeader(UserModel user, LibraryViewModel viewModel) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        border: const Border(bottom: BorderSide(color: WebColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildHeader(viewModel),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {},
                style: IconButton.styleFrom(
                  backgroundColor: WebColors.backgroundAlt,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: WebColors.AccentGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: WebColors.subtleShadow,
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(UserModel user, LibraryViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLibraryTabs(),
          const SizedBox(height: 24),
          Expanded(
            child: _activeSidebarSection == 'Recently Viewed'
                ? _buildRecentlyViewedGrid(user.uid, viewModel)
                : _activeSidebarSection == 'Favorites'
                    ? _buildEmptyState('No Favorites yet',
                        'Tap the heart icon on any item to save it here')
                    : TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildCombinedGrid(user.uid, viewModel),
                          _buildLibraryGrid(user.uid, 'summaries', viewModel),
                          _buildQuizGrid(user.uid, viewModel),
                          _buildLibraryGrid(user.uid, 'exams', viewModel),
                          _buildLibraryGrid(user.uid, 'flashcards', viewModel),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(LibraryViewModel viewModel) {
    final selectedFolder = viewModel.selectedFolder;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _activeSidebarSection == 'Recently Viewed'
                    ? 'Recently Viewed'
                    : _activeSidebarSection == 'Favorites'
                        ? 'Favorites'
                        : selectedFolder != null
                            ? selectedFolder.name
                            : 'Content Library',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _activeSidebarSection == 'Recently Viewed'
                    ? 'Your most recent activity across all categories.'
                    : _activeSidebarSection == 'Favorites'
                        ? 'Keep your most important materials here for quick access.'
                        : selectedFolder != null
                            ? 'Viewing contents of ${selectedFolder.name}'
                            : 'Manage and access your generated learning materials.',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            if (viewModel.isSyncing)
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            IconButton(
              icon: Icon(Icons.sync,
                  color: Theme.of(context).colorScheme.primary),
              onPressed: viewModel.syncAllData,
              tooltip: 'Sync Data',
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const EnterCodeDialog(),
                );
              },
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Import'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.1),
                foregroundColor: Theme.of(context).colorScheme.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Library...',
                  prefixIcon: Icon(Icons.search,
                      color: Theme.of(context).colorScheme.primary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Grid Builders ---

  Widget _buildCombinedGrid(String userId, LibraryViewModel viewModel) {
    final stream = viewModel.selectedFolder == null
        ? viewModel.allItems$
        : viewModel.getFolderItemsStream(viewModel.selectedFolder!.id);
    return StreamBuilder<List<LibraryItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoading();
        final items = snapshot.data ?? [];
        final filtered = items
            .where((i) => i.title.toLowerCase().contains(_searchQuery))
            .toList();

        if (filtered.isEmpty) {
          if (_searchQuery.isNotEmpty) {
            return _buildEmptyState(
                'No results found', 'Try adjusting your search query');
          }
          return _buildEmptyState('Your library is empty',
              'Start creating content to populate your library');
        }

        return _buildContentGrid(filtered, userId, viewModel);
      },
    );
  }

  Widget _buildLibraryGrid(
      String userId, String type, LibraryViewModel viewModel) {
    final selectedFolder = viewModel.selectedFolder;
    late Stream<List<LibraryItem>> stream;

    if (type == 'summaries') {
      stream = selectedFolder == null
          ? viewModel.allSummaries$
          : viewModel.getFolderSummariesStream(selectedFolder.id);
    } else if (type == 'exams') {
      stream = selectedFolder == null
          ? viewModel.allExams$
          : viewModel.getFolderExamsStream(selectedFolder.id);
    } else {
      stream = selectedFolder == null
          ? viewModel.allFlashcards$
          : viewModel.getFolderFlashcardsStream(selectedFolder.id);
    }

    return StreamBuilder<List<LibraryItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoading();
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _buildEmptyState(
              'No $type yet', 'Create your first $type now');
        }
        return _buildContentGrid(items, userId, viewModel);
      },
    );
  }

  Widget _buildQuizGrid(String userId, LibraryViewModel viewModel) {
    final selectedFolder = viewModel.selectedFolder;
    final stream = selectedFolder == null
        ? viewModel.allQuizzes$
        : viewModel.getFolderQuizzesStream(selectedFolder.id);

    return StreamBuilder<List<LibraryItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoading();
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _buildEmptyState(
              'No quizzes yet', 'Generate a quiz from any content');
        }
        return _buildContentGrid(items, userId, viewModel);
      },
    );
  }

  Widget _buildRecentlyViewedGrid(String userId, LibraryViewModel viewModel) {
    return StreamBuilder<List<LibraryItem>>(
      stream: viewModel.allRecentlyViewed$,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _buildEmptyState('No Recent Items',
              'The materials you viewed recently will appear here');
        }
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.4,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildRecentlyViewedItem(items[index]),
        );
      },
    );
  }

  Widget _buildRecentlyViewedItem(LibraryItem item) {
    IconData icon;
    Color bgColor;
    Color textColor;
    String typeName;
    String badge;

    switch (item.type) {
      case LibraryItemType.summary:
        icon = Icons.article_rounded;
        bgColor = const Color(0xFF6366F1).withValues(alpha: 0.1);
        textColor = const Color(0xFF6366F1);
        typeName = 'Summary';
        badge = 'Refined';
        break;
      case LibraryItemType.quiz:
        icon = Icons.quiz_rounded;
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.1);
        textColor = const Color(0xFF10B981);
        typeName = 'Quiz';
        badge = '${((item.score ?? 0) * 100).round()}% Score';
        break;
      case LibraryItemType.flashcards:
        icon = Icons.style_rounded;
        bgColor = const Color(0xFFEC4899).withValues(alpha: 0.1);
        textColor = const Color(0xFFEC4899);
        typeName = 'Flashcards';
        badge = '${item.itemCount ?? 0} Cards';
        break;
      case LibraryItemType.exam:
        icon = Icons.assignment_rounded;
        bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.1);
        textColor = const Color(0xFFF59E0B);
        typeName = 'Exam';
        badge = '${item.itemCount ?? 0} Questions';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: textColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.outfit(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                typeName,
                style: GoogleFonts.outfit(
                  color: WebColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: WebColors.border,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getRelativeTime(item.timestamp),
                style: GoogleFonts.outfit(
                  color: WebColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(child: CircularProgressIndicator(color: WebColors.primary));
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/web/empty_library.png',
            width: 200,
            height: 200,
          ).animate().scale(duration: 400.ms),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 16, color: WebColors.textSecondary),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => context.push('/create'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              side: BorderSide(color: WebColors.primary),
            ),
            child:
                Text('Create New', style: TextStyle(color: WebColors.primary)),
          ),
        ],
      ).animate().fadeIn(delay: 200.ms),
    );
  }

  Widget _buildLibraryTabs() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: WebColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebColors.border),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: WebColors.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: WebColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: WebColors.textSecondary,
        labelStyle:
            GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: 'All Items', icon: Icon(Icons.grid_view, size: 18)),
          Tab(
              text: 'Summaries',
              icon: Icon(Icons.description_outlined, size: 18)),
          Tab(text: 'Quizzes', icon: Icon(Icons.quiz_outlined, size: 18)),
          Tab(text: 'Exams', icon: Icon(Icons.assignment_outlined, size: 18)),
          Tab(text: 'Flashcards', icon: Icon(Icons.style_outlined, size: 18)),
        ],
      ),
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
          bgColor = WebColors.secondary.withOpacity(0.1);
          textColor = WebColors.secondary;
          typeName = 'SUMMARY';
          badge = item.itemCount != null
              ? '${item.itemCount} Sections'
              : 'Detailed Analysis';
          break;
        case LibraryItemType.quiz:
          icon = Icons.quiz_outlined;
          bgColor = WebColors.accentOrange.withOpacity(0.1);
          textColor = WebColors.accentOrange;
          typeName = 'QUIZ';
          badge = item.score != null
              ? 'Score: ${(item.score! * 100).round()}%'
              : '${item.itemCount ?? 0} Questions';
          break;
        case LibraryItemType.flashcards:
          icon = Icons.style_outlined;
          bgColor = WebColors.pinkAccent.withOpacity(0.1);
          textColor = WebColors.pinkAccent;
          typeName = 'FLASHCARDS';
          badge = '${item.itemCount ?? 0} Cards';
          break;
        case LibraryItemType.exam:
          icon = Icons.assignment_outlined;
          bgColor = WebColors.purplePrimary.withOpacity(0.1);
          textColor = WebColors.purplePrimary;
          typeName = 'EXAM';
          badge = item.score != null
              ? 'Score: ${(item.score! * 100).round()}%'
              : '${item.itemCount ?? 0} Questions';
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

  String _getRelativeTime(Timestamp timestamp) {
    final difference = DateTime.now().difference(timestamp.toDate());
    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
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
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 32,
            mainAxisSpacing: 32,
            childAspectRatio: 1.3,
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
          borderRadius: 24,
        ).copyWith(
          boxShadow: WebColors.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: card.onTap,
              hoverColor: card.textColor.withOpacity(0.05),
              splashColor: card.textColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: card.textColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              Icon(card.icon, color: card.textColor, size: 24),
                        ),
                        if (card.typeName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: card.textColor.withOpacity(0.1),
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
                      ],
                    ),
                    const Spacer(),
                    Text(
                      card.title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
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
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
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
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: card.textColor.withValues(alpha: 0.5),
                        ),
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

      // Navigate to ResultsViewScreenWeb for all content types
      debugPrint('🚀 Navigating to results view screen...');
      context.pushNamed(
        'results-view',
        pathParameters: {'folderId': item.id},
      );
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

  @override
  void dispose() {
    _tabController.dispose();
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
    this.isAddCard = false,
  });
}

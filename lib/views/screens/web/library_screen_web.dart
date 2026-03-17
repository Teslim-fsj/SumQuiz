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
import 'package:sumquiz/models/folder.dart';

import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard.dart';
import 'package:sumquiz/models/flashcard_set.dart';
import 'package:sumquiz/models/flashcard.dart';
import 'package:sumquiz/services/auth_service.dart';
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
  String _activeSidebarSection = 'All Content';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _localDb.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<UserModel?>(context);
    if (user != null) {
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

    if (user == null) {
      return Scaffold(body: _buildLoginPrompt());
    }

    return ChangeNotifierProvider(
      create: (context) => LibraryViewModel(
        localDb: context.read<LocalDatabaseService>(),
        firestoreService: context.read<FirestoreService>(),
        syncService: context.read<SyncService>(),
        userId: user.uid,
      ),
      child: Consumer<LibraryViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            body: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Row(
                children: [
                  _buildSidebar(viewModel),
                  Expanded(
                    child: _buildMainContent(user, viewModel),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_person, size: 60, color: WebColors.textSecondary),
          const SizedBox(height: 20),
          Text(
            "Please Log In to View Library",
            style: TextStyle(
              color: WebColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/auth'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WebColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(LibraryViewModel viewModel) {
    final selectedFolder = viewModel.selectedFolder;
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      decoration: BoxDecoration(
        color: WebColors.surface,
        border: Border(right: BorderSide(color: WebColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WebColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: WebColors.cardShadow,
                ),
                child:
                    const Icon(Icons.menu_book, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'SumQuiz Vault',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Main Sections
          _buildSidebarSection([
            GestureDetector(
                onTap: () {
                  viewModel.selectFolder(null);
                  setState(() => _activeSidebarSection = 'All Content');
                },
                child: _buildSidebarItem(
                    'All Content',
                    Icons.grid_view_rounded,
                    _activeSidebarSection == 'All Content' &&
                        selectedFolder == null)),
            const SizedBox(height: 12),
            GestureDetector(
                onTap: () =>
                    setState(() => _activeSidebarSection = 'Recently Viewed'),
                child: _buildSidebarItem(
                    'Recently Viewed',
                    Icons.access_time_filled,
                    _activeSidebarSection == 'Recently Viewed')),
            GestureDetector(
                onTap: () =>
                    setState(() => _activeSidebarSection = 'Favorites'),
                child: _buildSidebarItem('Favorites', Icons.star_border,
                    _activeSidebarSection == 'Favorites')),
            _buildSubItem('Collections', Icons.folder_outlined, onTap: () {}),
          ]),

          const SizedBox(height: 32),

          // Collections List
          Text(
            'COLLECTIONS',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: WebColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Folder>>(
              stream: viewModel.allFolders$,
              builder: (context, snapshot) {
                final folders = snapshot.data ?? [];
                return ListView.builder(
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    final isSelected = selectedFolder?.id == folder.id;
                    return GestureDetector(
                      onTap: () {
                        viewModel.selectFolder(folder);
                        setState(() => _activeSidebarSection = 'Folder');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.folder_open,
                                size: 18,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withAlpha(128)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                folder.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          GestureDetector(
            onTap: () => context.push('/create'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Create New',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSection(List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  Widget _buildSidebarItem(String title, IconData icon, bool isSelected) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary.withAlpha(128),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItem(String title, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 36),
        child: Row(
          children: [
            Icon(icon,
                color: Theme.of(context).colorScheme.primary.withAlpha(153),
                size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(UserModel user, LibraryViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(viewModel),
          const SizedBox(height: 32),
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
                    .withValues(alpha: 0.1),
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
        if (!snapshot.hasData) return _buildLoading();
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _buildEmptyState('No recent activity',
              'Things you view or create will appear here');
        }
        return _buildContentGrid(items, userId, viewModel);
      },
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
              color: WebColors.primary.withValues(alpha: 0.3),
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
          icon = Icons.article_outlined;
          bgColor = WebColors.secondary.withValues(alpha: 0.1);
          textColor = WebColors.secondary;
          typeName = 'SUMMARY';
          badge =
              item.description != null ? 'Details available' : 'No description';
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
      child: GestureDetector(
        onTap: card.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: WebColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: WebColors.border),
            boxShadow: WebColors.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!card.isAddCard)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: card.textColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(card.icon,
                                  color: card.textColor, size: 24),
                            )
                          else
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Theme.of(context).dividerColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Icon(Icons.add,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                  size: 24),
                            ),
                          if (card.typeName.isNotEmpty)
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
                        ],
                      ),
                      const Spacer(),
                      Text(
                        card.title,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: WebColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card.subtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: WebColors.textSecondary,
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      if (!card.isAddCard)
                        Row(
                          children: [
                            Text(
                              card.date,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            if (card.badge.isNotEmpty)
                              Row(
                                children: [
                                  Icon(
                                    card.typeName == 'QUIZ'
                                        ? Icons.emoji_events_outlined
                                        : (card.typeName == 'FLASHCARDS'
                                            ? Icons.layers_outlined
                                            : Icons.visibility_outlined),
                                    size: 14,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    card.badge,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            if (card.typeName != 'SUMMARY')
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
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
    final viewModel = context.read<LibraryViewModel>();

    try {
      dynamic contentData;
      switch (item.type) {
        case LibraryItemType.summary:
          contentData = await viewModel.localDb.getSummary(item.id);
          break;
        case LibraryItemType.quiz:
          contentData = await viewModel.localDb.getQuiz(item.id);
          break;
        case LibraryItemType.flashcards:
          contentData = await viewModel.localDb.getFlashcardSet(item.id);
          break;
        case LibraryItemType.exam:
          contentData = await viewModel.localDb.getQuiz(item.id);
          break;
      }

      if (contentData == null) {
        // Fallback to Firestore for Web
        final userId = context.read<AuthService>().currentUser?.uid;
        if (userId != null) {
          final firestoreService = FirestoreService();
          try {
            switch (item.type) {
              case LibraryItemType.summary:
                final fsDoc =
                    await firestoreService.getSummary(userId, item.id);
                if (fsDoc != null) {
                  contentData = LocalSummary(
                    id: fsDoc.id,
                    title: fsDoc.title,
                    content: fsDoc.content,
                    timestamp: fsDoc.timestamp.toDate(),
                    userId: userId,
                  );
                }
                break;
              case LibraryItemType.quiz:
              case LibraryItemType.exam:
                final fsDoc = await firestoreService.getQuiz(userId, item.id);
                if (fsDoc != null) {
                  contentData = LocalQuiz(
                    id: fsDoc.id,
                    title: fsDoc.title,
                    timestamp: fsDoc.timestamp.toDate(),
                    userId: userId,
                    questions: fsDoc.questions
                        .map((q) => q.toLocalQuizQuestion())
                        .toList(),
                  );
                }
                break;
              case LibraryItemType.flashcards:
                final fsDoc =
                    await firestoreService.getFlashcardSet(userId, item.id);
                if (fsDoc != null) {
                  contentData = LocalFlashcardSet(
                    id: fsDoc.id,
                    title: fsDoc.title,
                    timestamp: fsDoc.timestamp.toDate(),
                    userId: userId,
                    flashcards: fsDoc.flashcards
                        .map((f) => LocalFlashcard(
                              question: f.question,
                              answer: f.answer,
                            ))
                        .toList(),
                  );
                }
                break;
            }
          } catch (e) {
            debugPrint('Firestore fallback error: $e');
          }
        }
      }
      if (!mounted) return;

      if (contentData == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Content not found. Please try again later.'),
              backgroundColor: WebColors.error,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      if (contentData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Could not load content.')),
        );
        return;
      }

      switch (item.type) {
        case LibraryItemType.summary:
          context.pushNamed('library-summary', extra: contentData);
          break;
        case LibraryItemType.quiz:
          context.pushNamed('library-quiz', extra: contentData);
          break;
        case LibraryItemType.flashcards:
          final localSet = contentData as LocalFlashcardSet;
          final flashcardSet = FlashcardSet(
            id: localSet.id,
            title: localSet.title,
            flashcards: localSet.flashcards
                .map((f) => Flashcard(
                      id: f.id,
                      question: f.question,
                      answer: f.answer,
                    ))
                .toList(),
            timestamp: Timestamp.fromDate(localSet.timestamp),
          );
          context.pushNamed('library-flashcards', extra: flashcardSet);
          break;
        case LibraryItemType.exam:
          context.pushNamed('library-quiz', extra: contentData);
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
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

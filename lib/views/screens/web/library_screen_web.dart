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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Icon(Icons.lock_person, size: 60, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(height: 20),
          Text("Please Log In to View Library",
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w700)),
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
            color: WebColors.purplePrimary.withOpacity(0.1),
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
                child: CircularProgressIndicator(strokeWidth: 2, color: WebColors.purplePrimary),
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
      {'label': 'All Items', 'icon': Icons.grid_view_rounded},
      {'label': 'Summaries', 'icon': Icons.description_rounded},
      {'label': 'Quizzes', 'icon': Icons.quiz_rounded},
      {'label': 'Exams', 'icon': Icons.assignment_rounded},
      {'label': 'Flashcards', 'icon': Icons.style_rounded},
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? WebColors.purplePrimary : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: WebColors.purplePrimary.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      categories[index]['icon'] as IconData,
                      size: 18,
                      color: isSelected ? WebColors.purplePrimary : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      categories[index]['label'] as String,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isSelected ? WebColors.purplePrimary : const Color(0xFF64748B),
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
    // Map filter index to the correct stream
    final stream = switch (_selectedFilter) {
      0 => viewModel.allItems$,
      1 => viewModel.allSummaries$,
      2 => viewModel.allQuizzes$,
      3 => viewModel.allExams$,
      4 => viewModel.allFlashcards$,
      _ => viewModel.allItems$,
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
            onBuildPack: () => context.push('/create'),
            onCreateNew: () => context.push('/create-content'),
          );
        }

        return _buildContentGrid(filtered, userId, viewModel);
      },
    );
  }

  Widget _buildContentGrid(List<LibraryItem> items, String userId, LibraryViewModel viewModel) {
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
          badge = item.itemCount != null ? '${item.itemCount} Sections' : 'Detailed Analysis';
          break;
        case LibraryItemType.quiz:
          icon = Icons.quiz_outlined;
          bgColor = WebColors.accentOrange.withOpacity(0.1);
          textColor = WebColors.accentOrange;
          typeName = 'QUIZ';
          badge = item.score != null ? 'Score: ${(item.score! * 100).round()}%' : '${item.itemCount ?? 0} Questions';
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
          badge = item.score != null ? 'Score: ${(item.score! * 100).round()}%' : '${item.itemCount ?? 0} Questions';
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
              hoverColor: card.textColor.withOpacity(0.05),
              splashColor: card.textColor.withOpacity(0.1),
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
                            color: card.textColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(card.icon, color: card.textColor, size: 24),
                        ),
                        if (card.typeName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                              : (card.typeName == 'FLASHCARDS' ? Icons.layers_outlined : Icons.read_more_outlined),
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
                        Icon(Icons.arrow_forward, size: 16, color: card.textColor.withOpacity(0.5)),
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
    debugPrint('🔍 Navigating to content: ${item.type} - ${item.title} (ID: ${item.id})');
    setState(() => _isNavigating = true);

    try {
      if (!mounted) {
        debugPrint('⚠️ Widget not mounted, aborting navigation');
        setState(() => _isNavigating = false);
        return;
      }

      debugPrint('🚀 Navigating to results view screen...');
      int tab = 0;
      switch (item.type) {
        case LibraryItemType.summary: tab = 0; break;
        case LibraryItemType.quiz:
        case LibraryItemType.exam: tab = 1; break;
        case LibraryItemType.flashcards: tab = 2; break;
      }

      context.pushNamed(
        'results-view',
        pathParameters: {'folderId': item.id},
        queryParameters: {'tab': tab.toString()},
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

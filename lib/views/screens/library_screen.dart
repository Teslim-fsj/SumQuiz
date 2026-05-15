import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_model.dart';
import '../../models/library_item.dart';
import '../../models/folder.dart';
import '../../services/firestore_service.dart';
import '../../services/local_database_service.dart';
import '../../services/sync_service.dart';
import '../../view_models/library_view_model.dart';
import '../widgets/enter_code_dialog.dart';
import '../../utils/library_share_helper.dart';
import '../../widgets/sumi_mascot.dart';
import '../../models/sumi_emotion.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final theme = Theme.of(context);

    if (user == null) {
      return _buildLoggedOutView(theme);
    }

    return ChangeNotifierProvider(
      create: (context) => LibraryViewModel(
        localDb: context.read<LocalDatabaseService>(),
        firestoreService: context.read<FirestoreService>(),
        syncService: context.read<SyncService>(),
        userId: user.uid,
      ),
      child: const _LibraryView(),
    );
  }

  Widget _buildLoggedOutView(ThemeData theme) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              const SizedBox(height: 24),
              Text(
                'Please Log In',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary
                )
              ),
              const SizedBox(height: 12),
              Text(
                'Log in to access your synchronized library across all your devices.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: theme.hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryView extends StatefulWidget {
  const _LibraryView();

  @override
  _LibraryViewState createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _folderTabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 4, vsync: this);
    _folderTabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _folderTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<LibraryViewModel>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context, theme, viewModel),
      floatingActionButton: viewModel.selectedFolder != null
          ? FloatingActionButton.extended(
              onPressed: () => _showAddContentOptions(context, viewModel),
              icon: const Icon(Icons.add_rounded),
              label: Text('Add Content', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ).animate().scale()
          : null,
      body: Column(
        children: [
          _buildHeader(context, theme, viewModel),
          Expanded(
            child: StreamBuilder<Folder?>(
              stream: viewModel.selectedFolderStream,
              builder: (context, snapshot) {
                final selectedFolder = snapshot.data;
                if (selectedFolder == null) {
                  return TabBarView(
                    controller: _mainTabController,
                    children: [
                      _buildContentList(viewModel.allItems$, theme, viewModel),
                      _buildFolderList(viewModel, theme),
                      _buildContentList(viewModel.allNotes$, theme, viewModel),
                      _buildContentList(viewModel.allExams$, theme, viewModel),
                    ],
                  );
                } else {
                  return TabBarView(
                    controller: _folderTabController,
                    children: [
                      _buildContentList(viewModel.getFolderStudyPackStream(selectedFolder.id), theme, viewModel),
                      _buildContentList(viewModel.getFolderNotesStream(selectedFolder.id), theme, viewModel),
                      _buildContentList(viewModel.getFolderExamsStream(selectedFolder.id), theme, viewModel),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, ThemeData theme, LibraryViewModel viewModel) {
    final selectedFolder = viewModel.selectedFolder;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: selectedFolder != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => viewModel.selectFolder(null),
            )
          : null,
      title: Text(
        selectedFolder?.name ?? 'Library',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          fontSize: 22
        ),
      ),
      centerTitle: true,
      actions: [
        if (viewModel.isSyncing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          IconButton(
              icon: const Icon(Icons.sync_rounded), 
              onPressed: viewModel.syncAllData,
              tooltip: 'Sync data',
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, LibraryViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search through your library...',
                      hintStyle: GoogleFonts.inter(color: theme.hintColor, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: theme.hintColor, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: () {
                   showDialog(
                    context: context,
                    builder: (_) => const EnterCodeDialog(),
                  );
                },
                icon: const Icon(Icons.add_link_rounded, size: 20),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ).animate().fadeIn().slideY(begin: -0.1),
          const SizedBox(height: 20),
          _buildTabBar(context, theme, viewModel),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, ThemeData theme, LibraryViewModel viewModel) {
    final selectedFolder = viewModel.selectedFolder;
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 48,
      child: TabBar(
        controller: selectedFolder == null ? _mainTabController : _folderTabController,
        isScrollable: true,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: colorScheme.primary,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
        labelColor: colorScheme.onPrimary,
        unselectedLabelColor: theme.hintColor,
        dividerColor: Colors.transparent,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
        tabs: selectedFolder == null
            ? const [
                Tab(text: '  All Content  '),
                Tab(text: '  Study Packs  '),
                Tab(text: '  Observations  '),
                Tab(text: '  Exams  '),
              ]
            : const [
                Tab(text: '  Study Pack  '),
                Tab(text: '  Notes  '),
                Tab(text: '  Exams  '),
              ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildFolderList(LibraryViewModel viewModel, ThemeData theme) {
    return StreamBuilder<List<Folder>>(
      stream: viewModel.allFolders$,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.inter()));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoContentState('folders', theme);
        }

        final folders = snapshot.data!;
        final filteredFolders = _searchQuery.isEmpty
            ? folders
            : folders.where((folder) => folder.name.toLowerCase().contains(_searchQuery)).toList();

        if (filteredFolders.isEmpty && _searchQuery.isNotEmpty) {
          return _buildNoSearchResultsState(theme);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredFolders.length,
          itemBuilder: (context, index) {
            final folder = filteredFolders[index];
            return _buildLibraryItemCard(
              title: folder.name,
              subtitle: '${DateFormat('MMM d, yyyy').format(folder.createdAt)}',
              icon: Icons.folder_copy_rounded,
              iconColor: Colors.deepPurpleAccent,
              theme: theme,
              onTap: () => viewModel.selectFolder(folder),
            ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1, end: 0);
          },
        );
      },
    );
  }

  Widget _buildContentList(Stream<List<LibraryItem>> stream, ThemeData theme, LibraryViewModel viewModel) {
    return StreamBuilder<List<LibraryItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.inter()));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoContentState(viewModel.selectedFolder == null ? 'content' : 'folder content', theme);
        }

        final items = snapshot.data!
            .where((item) => item.title.toLowerCase().contains(_searchQuery))
            .toList();

        if (items.isEmpty && _searchQuery.isNotEmpty) {
          return _buildNoSearchResultsState(theme);
        }

        return RefreshIndicator(
          onRefresh: viewModel.syncAllData,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildLibraryItemCard(
                title: item.title,
                subtitle: item.type.name.toUpperCase(),
                icon: _getIconForType(item.type),
                iconColor: _getColorForType(item.type),
                theme: theme,
                trailing: _buildItemActions(context, item, viewModel, theme),
                onTap: () => _navigateToContent(context, item, viewModel),
              ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1, end: 0);
            },
          ),
        );
      },
    );
  }

  Widget _buildLibraryItemCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required ThemeData theme,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? 'Untitled' : title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.displayLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.hintColor,
                          letterSpacing: 0.5
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing else Icon(Icons.chevron_right_rounded, color: theme.hintColor, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemActions(BuildContext context, LibraryItem item, LibraryViewModel viewModel, ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: theme.hintColor, size: 20),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        if (value == 'share') {
          final user = context.read<UserModel?>();
          if (user != null) {
            await LibraryShareHelper.shareLibraryItem(context, item, user);
          }
        } else if (value == 'edit') {
          _navigateToEdit(context, item);
        } else if (value == 'delete') {
          _confirmDelete(context, item, viewModel);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_rounded, size: 18),
              const SizedBox(width: 12),
              Text('Edit', style: GoogleFonts.inter(fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              const Icon(Icons.share_rounded, size: 18),
              const SizedBox(width: 12),
              Text('Share', style: GoogleFonts.inter(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
              const SizedBox(width: 12),
              Text('Delete', style: GoogleFonts.inter(fontSize: 14, color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, LibraryItem item, LibraryViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Item?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove "${item.title}"?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              viewModel.deleteItem(item);
              Navigator.pop(context);
            },
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(LibraryItemType type) {
    switch (type) {
      case LibraryItemType.summary: return Icons.article_rounded;
      case LibraryItemType.quiz: return Icons.quiz_rounded;
      case LibraryItemType.flashcards: return Icons.style_rounded;
      case LibraryItemType.exam: return Icons.assignment_rounded;
      case LibraryItemType.note: return Icons.edit_note_rounded;
    }
  }

  Color _getColorForType(LibraryItemType type) {
    switch (type) {
      case LibraryItemType.summary: return const Color(0xFF0D9488);
      case LibraryItemType.quiz: return const Color(0xFFF59E0B);
      case LibraryItemType.flashcards: return const Color(0xFFEC4899);
      case LibraryItemType.exam: return const Color(0xFF6366F1);
      case LibraryItemType.note: return const Color(0xFF8B5CF6);
    }
  }

  void _showAddContentOptions(BuildContext context, LibraryViewModel viewModel) {
    // Show options to add content to a folder
  }

  Widget _buildNoContentState(String type, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SumiMascot(state: SumiState.confused, size: 100),
            const SizedBox(height: 24),
            Text(
              'Your library is quiet',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: theme.hintColor),
            ),
            const SizedBox(height: 12),
            Text(
              'Start by creating a new Study Pack or Note to fill this space.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: theme.hintColor.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildNoSearchResultsState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: theme.hintColor.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'No results for "$_searchQuery"',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  // Navigation methods
  void _navigateToContent(BuildContext context, LibraryItem item, LibraryViewModel viewModel) {
     if (item.type == LibraryItemType.note) {
      context.push('/notes/${item.id}');
    } else {
      // Handle other types
    }
  }

  void _navigateToEdit(BuildContext context, LibraryItem item) {
    // Handle editing
  }
}

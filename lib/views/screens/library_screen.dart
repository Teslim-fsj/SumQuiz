import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_model.dart';
import '../../models/library_item.dart';
import '../../services/firestore_service.dart';
import '../../services/local_database_service.dart';
import '../../services/sync_service.dart';
import '../../view_models/library_view_model.dart';
import '../widgets/enter_code_dialog.dart';
import '../../utils/library_share_helper.dart';

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
              Icon(Icons.cloud_off_rounded,
                  size: 80,
                  color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              const SizedBox(height: 24),
              Text(
                'Please Log In',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
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

class _LibraryViewState extends State<_LibraryView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: All, 1: Notes, 2: Study Packs, 3: Quizzes, 4: Exams

  final List<String> _filters = [
    'All',
    'Notes',
    'Study Packs',
    'Quizzes',
    'Exams',
  ];

  @override
  void initState() {
    super.initState();
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

  Stream<List<LibraryItem>> _getActiveStream(LibraryViewModel viewModel) {
    switch (_selectedFilterIndex) {
      case 1:
        return viewModel.allNotes$;
      case 2:
        return viewModel.studyPack$;
      case 3:
        return viewModel.allQuizzes$;
      case 4:
        return viewModel.allExams$;
      case 0:
      default:
        return viewModel.allItems$;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewModel = context.watch<LibraryViewModel>();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header Area ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Library',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Everything you're learning, in one place.",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (viewModel.isSyncing)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.sync_rounded, size: 22),
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      onPressed: viewModel.syncAllData,
                      tooltip: 'Sync library',
                    ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const EnterCodeDialog(),
                      );
                    },
                    tooltip: 'Enter Share Code',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Prominent Search Bar ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search notes, study packs, quizzes...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            color: const Color(0xFF94A3B8),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Lightweight Filter Chips Bar ──────────────────────────────
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = _selectedFilterIndex == index;
                  return _buildFilterChip(
                    label: _filters[index],
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () {
                      setState(() {
                        _selectedFilterIndex = index;
                      });
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ── Main Content List ─────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<LibraryItem>>(
                stream: _getActiveStream(viewModel),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading library: ${snapshot.error}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    );
                  }

                  final allItems = snapshot.data ?? [];
                  final filteredItems = _searchQuery.isEmpty
                      ? allItems
                      : allItems
                          .where((item) =>
                              item.title.toLowerCase().contains(_searchQuery))
                          .toList();

                  if (filteredItems.isEmpty) {
                    if (_searchQuery.isNotEmpty) {
                      return _buildNoSearchResults(isDark);
                    }
                    return _buildEmptyState(isDark);
                  }

                  return RefreshIndicator(
                    onRefresh: viewModel.syncAllData,
                    color: const Color(0xFF6B5CE7),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                      itemCount: filteredItems.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _buildContentRow(
                          context: context,
                          item: item,
                          viewModel: viewModel,
                          isDark: isDark,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    const activeColor = Color(0xFF6B5CE7);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentRow({
    required BuildContext context,
    required LibraryItem item,
    required LibraryViewModel viewModel,
    required bool isDark,
  }) {
    final typeDetails = _getTypeDetails(item.type);
    final formattedDate = _formatTimestamp(item.timestamp);
    final metadataString = _buildMetadataString(item, typeDetails.label, formattedDate);

    return InkWell(
      onTap: () => _navigateToContent(context, item, viewModel),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Minimalist Content Type Badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeDetails.badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                typeDetails.icon,
                color: typeDetails.badgeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Title & Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isNotEmpty ? item.title : 'Untitled',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metadataString,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Overflow Action Menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF94A3B8),
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onSelected: (value) =>
                  _handleAction(context, value, item, viewModel),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 18),
                      SizedBox(width: 12),
                      Text('Share'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 12),
                      Text('Rename / Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: Color(0xFFEF4444)),
                      SizedBox(width: 12),
                      Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildMetadataString(
      LibraryItem item, String typeLabel, String date) {
    final buffer = StringBuffer();
    buffer.write(typeLabel);

    if (item.itemCount != null && item.itemCount! > 0) {
      if (item.type == LibraryItemType.flashcards) {
        buffer.write(' · ${item.itemCount} cards');
      } else if (item.type == LibraryItemType.quiz ||
          item.type == LibraryItemType.exam) {
        buffer.write(' · ${item.itemCount} items');
      } else {
        buffer.write(' · ${item.itemCount} items');
      }
    }

    if (item.score != null) {
      buffer.write(' · ${(item.score! * 100).round()}% score');
    }

    buffer.write(' · $date');
    return buffer.toString();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dt;
    if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      try {
        dt = timestamp.toDate();
      } catch (e) {
        return '';
      }
    }

    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }

  _TypeDetails _getTypeDetails(LibraryItemType type) {
    switch (type) {
      case LibraryItemType.note:
        return _TypeDetails(
          label: 'Note',
          icon: Icons.edit_note_rounded,
          badgeColor: const Color(0xFF8B5CF6),
        );
      case LibraryItemType.summary:
        return _TypeDetails(
          label: 'Study Pack',
          icon: Icons.auto_awesome_rounded,
          badgeColor: const Color(0xFF0D9488),
        );
      case LibraryItemType.quiz:
        return _TypeDetails(
          label: 'Quiz',
          icon: Icons.quiz_rounded,
          badgeColor: const Color(0xFFF59E0B),
        );
      case LibraryItemType.flashcards:
        return _TypeDetails(
          label: 'Flashcards',
          icon: Icons.style_rounded,
          badgeColor: const Color(0xFF2563EB),
        );
      case LibraryItemType.exam:
        return _TypeDetails(
          label: 'Exam',
          icon: Icons.timer_outlined,
          badgeColor: const Color(0xFF6B5CE7),
        );
      case LibraryItemType.folder:
        return _TypeDetails(
          label: 'Folder',
          icon: Icons.folder_outlined,
          badgeColor: const Color(0xFF64748B),
        );
    }
  }

  void _navigateToContent(
      BuildContext context, LibraryItem item, LibraryViewModel viewModel) async {
    switch (item.type) {
      case LibraryItemType.note:
        context.push('/notes/${item.id}');
        break;
      case LibraryItemType.summary:
        final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
        final summary = await localDb.getSummary(item.id);
        if (context.mounted) {
          context.push('/library/summary/${item.id}', extra: summary);
        }
        break;
      case LibraryItemType.quiz:
      case LibraryItemType.exam:
        final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
        final quiz = await localDb.getQuiz(item.id);
        if (context.mounted) {
          context.push('/library/quiz/${item.id}', extra: quiz);
        }
        break;
      case LibraryItemType.flashcards:
        final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
        final set = await localDb.getFlashcardSet(item.id);
        if (context.mounted) {
          context.push('/library/flashcards/${item.id}', extra: set);
        }
        break;
      case LibraryItemType.folder:
        break;
    }
  }

  void _handleAction(BuildContext context, String action, LibraryItem item,
      LibraryViewModel viewModel) async {
    switch (action) {
      case 'share':
        final user = Provider.of<UserModel?>(context, listen: false);
        if (user != null) {
          LibraryShareHelper.shareLibraryItem(context, item, user);
        }
        break;
      case 'edit':
        _showEditDialog(context, item, viewModel);
        break;
      case 'delete':
        _confirmDelete(context, item, viewModel);
        break;
    }
  }

  void _showEditDialog(
      BuildContext context, LibraryItem item, LibraryViewModel viewModel) {
    final titleController = TextEditingController(text: item.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rename Item',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(ctx);
                await viewModel.renameItem(item, newTitle);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B5CE7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, LibraryItem item, LibraryViewModel viewModel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Item?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${item.title}"? This cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await viewModel.deleteItem(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF6B5CE7).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFF6B5CE7),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Library is empty',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to create a note, study pack, quiz, or formal exam.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              'No items match your search',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search keyword or clear the filter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeDetails {
  final String label;
  final IconData icon;
  final Color badgeColor;

  _TypeDetails({
    required this.label,
    required this.icon,
    required this.badgeColor,
  });
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/theme/web_theme.dart';
// Removed unnecessary import 'dart:ui'

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  bool _isLoading = true;
  List<PublicDeck> _decks = [];

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    final user = context.read<UserModel?>();
    if (user == null) return;

    final decks = await FirestoreService().fetchCreatorDecks(user.uid);
    if (mounted) {
      setState(() {
        _decks = decks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<UserModel?>();
    final isCreator = user?.role == UserRole.creator;
    final isPro = user?.isPro ?? false;
    final canAccess = isPro || isCreator;

    return Scaffold(
      backgroundColor: WebColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Teacher Dashboard',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: WebColors.textPrimary,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: WebColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WebColors.border),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: WebColors.primary),
              onPressed: canAccess
                  ? () {
                      setState(() => _isLoading = true);
                      _loadDecks();
                    }
                  : null,
            ),
          )
        ],
      ),
      body: !canAccess
          ? _buildProTeaser(theme)
          : _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: WebColors.primary))
              : Column(
                  children: [
                    if (!isPro && isCreator) _buildFreeTierBanner(theme),
                    Expanded(
                      child: _decks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: WebColors.primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.dashboard_outlined,
                                        size: 64, color: WebColors.primary),
                                  ).animate().scale(duration: 400.ms),
                                  const SizedBox(height: 24),
                                  Text('No published decks yet.',
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        color: WebColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      )).animate().fadeIn(delay: 100.ms),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Share your knowledge by publishing a deck to the library.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: WebColors.textSecondary,
                                    ),
                                  ).animate().fadeIn(delay: 200.ms),
                                  const SizedBox(height: 32),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => context.go('/library'),
                                        icon: const Icon(Icons.library_books),
                                        label: const Text('Visit Library'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: WebColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      ElevatedButton.icon(
                                        onPressed: () => context.go(
                                            '/library'), // This route now maps to ExamCreation for teachers
                                        icon: const Icon(Icons.school_rounded),
                                        label: const Text(
                                            'Create Your First Exam'),
                                      ),
                                    ],
                                  ).animate().fadeIn(delay: 300.ms)
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadDecks,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _decks.length,
                                itemBuilder: (context, index) {
                                  final deck = _decks[index];
                                  return Container(
                                    margin: const EdgeInsets.only(
                                        bottom: 24, left: 16, right: 16),
                                    decoration: BoxDecoration(
                                      color: WebColors.surface,
                                      borderRadius: BorderRadius.circular(24),
                                      border:
                                          Border.all(color: WebColors.border),
                                      boxShadow: WebColors.cardShadow,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            // Future: Open detail view or analytics
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      decoration: BoxDecoration(
                                                        color: WebColors.primary
                                                            .withValues(
                                                                alpha: 0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                      ),
                                                      child: Icon(
                                                          Icons
                                                              .auto_awesome_mosaic,
                                                          color: WebColors
                                                              .primary),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            deck.title,
                                                            style: theme
                                                                .textTheme
                                                                .titleLarge
                                                                ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color: WebColors
                                                                  .textPrimary,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            'Published on ${DateFormat.yMMMd().format(deck.publishedAt)}',
                                                            style: theme
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                              color: WebColors
                                                                  .textSecondary,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: WebColors
                                                            .backgroundAlt,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                            color: WebColors
                                                                .border),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.share,
                                                              size: 16,
                                                              color: WebColors
                                                                  .textSecondary),
                                                          const SizedBox(
                                                              width: 8),
                                                          Text(
                                                            deck.shareCode,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color: WebColors
                                                                  .primary,
                                                              letterSpacing:
                                                                  1.5,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 24),
                                                const Divider(
                                                    color: WebColors.border),
                                                const SizedBox(height: 24),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: [
                                                    _buildMetric(
                                                      context,
                                                      Icons.play_circle_outline,
                                                      'Started',
                                                      deck.startedCount
                                                          .toString(),
                                                      WebColors.blueInfo,
                                                    ),
                                                    _buildMetric(
                                                      context,
                                                      Icons
                                                          .check_circle_outline,
                                                      'Completed',
                                                      deck.completedCount
                                                          .toString(),
                                                      WebColors.success,
                                                    ),
                                                    _buildMetric(
                                                      context,
                                                      Icons.star_outline,
                                                      'Rating',
                                                      '4.8', // Mock data for premium feel
                                                      WebColors.accent,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(delay: (index * 50).ms)
                                      .slideY(begin: 0.1);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFreeTierBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You are on the Free Educator plan. Upgrade to unlock unlimited exams and analytics.',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push('/settings/subscription'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: const Text('Upgrade',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildProTeaser(ThemeData theme) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.workspace_premium_rounded,
                  size: 64, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 32),
            Text(
              'Creator Mode is Pro',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Upgrade to SumQuiz Pro to publish your decks, share them with the world, and track student analytics.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/settings/subscription'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Upgrade to Pro'),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale(delay: 200.ms);
  }

  Widget _buildMetric(BuildContext context, IconData icon, String label,
      String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: WebColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

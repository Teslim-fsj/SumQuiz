import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/firestore_service.dart';

class CreatorDashboardScreen extends StatefulWidget {
  const CreatorDashboardScreen({super.key});

  @override
  State<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends State<CreatorDashboardScreen> {
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
    final isPro = user?.isPro ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isPro
                ? () {
                    setState(() => _isLoading = true);
                    _loadDecks();
                  }
                : null,
          )
        ],
      ),
      body: !isPro
          ? _buildProTeaser(theme)
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _decks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dashboard_outlined,
                              size: 64, color: theme.disabledColor),
                          const SizedBox(height: 16),
                          Text('No published decks yet.',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(color: theme.disabledColor)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => context.go('/library'),
                            child: const Text('Go to Library to Publish'),
                          )
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
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            clipBehavior: Clip.antiAlias,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                    color: theme.dividerColor
                                        .withValues(alpha: 0.1))),
                            child: InkWell(
                              onTap: () {
                                // Future: Open detail view or analytics
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            deck.title,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme.primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            deck.shareCode,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme
                                                  .onPrimaryContainer,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Published on ${DateFormat.yMMMd().format(deck.publishedAt)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: theme.disabledColor),
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildMetric(
                                          context,
                                          Icons.play_circle_outline,
                                          'Started',
                                          deck.startedCount.toString(),
                                          Colors.blue,
                                        ),
                                        _buildMetric(
                                          context,
                                          Icons.check_circle_outline,
                                          'Completed',
                                          deck.completedCount.toString(),
                                          Colors.green,
                                        ),
                                      ],
                                    ),
                                  ],
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
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
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
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.disabledColor,
          ),
        ),
      ],
    );
  }
}

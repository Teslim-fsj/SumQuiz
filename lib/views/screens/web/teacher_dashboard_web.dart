import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/services/auth_service.dart';

class TeacherDashboardWeb extends StatefulWidget {
  const TeacherDashboardWeb({super.key});

  @override
  State<TeacherDashboardWeb> createState() => _TeacherDashboardWebState();
}

class _TeacherDashboardWebState extends State<TeacherDashboardWeb> {
  bool _isLoading = true;
  List<PublicDeck> _decks = [];

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
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
    final userModel = context.watch<UserModel?>();
    final isPro = userModel?.isPro ?? false;

    if (!isPro) {
      return _buildUpgradeView(theme);
    }

    return Scaffold(
      backgroundColor: WebColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(theme, userModel),
          SliverPadding(
            padding: const EdgeInsets.all(40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildWelcomeHeader(theme, userModel),
                const SizedBox(height: 40),
                _buildQuickActions(context),
                const SizedBox(height: 60),
                _buildSectionHeader(theme, 'Live Analytics', Icons.analytics_outlined),
                const SizedBox(height: 24),
                _buildAnalyticsGrid(),
                const SizedBox(height: 60),
                _buildSectionHeader(theme, 'Recent Teaching Assets', Icons.inventory_2_outlined),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_decks.isEmpty)
                  _buildEmptyState(theme)
                else
                  _buildDecksGrid(context, theme),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme, UserModel? user) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WebColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Text(
            'SumQuiz Educator',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: WebColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: WebColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'PRO',
              style: TextStyle(
                color: WebColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: WebColors.textSecondary),
          onPressed: () {},
        ),
        const SizedBox(width: 16),
        CircleAvatar(
          radius: 18,
          backgroundColor: WebColors.backgroundAlt,
          backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
          child: user?.photoUrl == null ? const Icon(Icons.person_outline, size: 20) : null,
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _buildWelcomeHeader(ThemeData theme, UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good day, ${user?.displayName.split(' ').first ?? 'Educator'}! 👋',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: WebColors.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your curriculum and track student performance in real-time.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: WebColors.textSecondary,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            'Generate New Exam',
            'Turn documents into professional test papers instantly.',
            Icons.assignment_add,
            WebColors.purplePrimary,
            () => context.go('/create'),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildActionCard(
            context,
            'Question Bank',
            'Manage and organize your generated question sets.',
            Icons.folder_copy_outlined,
            WebColors.accentOrange,
            () => context.go('/library'),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildActionCard(
            context,
            'Import Resources',
            'Upload syllabus or textbooks to start building.',
            Icons.cloud_upload_outlined,
            WebColors.secondary,
            () => context.go('/create'),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: WebColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: WebColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Get Started',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 16, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: WebColors.textSecondary, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: WebColors.textPrimary,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {},
          child: const Text('View All'),
        ),
      ],
    );
  }

  Widget _buildAnalyticsGrid() {
    return Row(
      children: [
        _buildStatCard('Total Students', '1,284', Icons.people_outline, WebColors.blueInfo),
        const SizedBox(width: 24),
        _buildStatCard('Exam Completions', '3,421', Icons.check_circle_outline, WebColors.greenSuccess),
        const SizedBox(width: 24),
        _buildStatCard('Avg. Engagement', '84%', Icons.speed_outlined, WebColors.accentOrange),
        const SizedBox(width: 24),
        _buildStatCard('Teaching Hours Saved', '120h', Icons.timer_outlined, WebColors.purplePrimary),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WebColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: WebColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: WebColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecksGrid(BuildContext context, ThemeData theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.4,
      ),
      itemCount: _decks.length > 6 ? 6 : _decks.length,
      itemBuilder: (context, index) {
        final deck = _decks[index];
        return _buildDeckCard(context, theme, deck);
      },
    );
  }

  Widget _buildDeckCard(BuildContext context, ThemeData theme, PublicDeck deck) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: WebColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.description_outlined, color: WebColors.primary, size: 20),
                      ),
                      const Spacer(),
                      _buildStatusBadge('Published'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    deck.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: WebColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${DateFormat.yMMMd().format(deck.publishedAt)} • Code: ${deck.shareCode}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: WebColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSmallMetric(Icons.play_arrow_outlined, deck.startedCount.toString()),
                      const SizedBox(width: 16),
                      _buildSmallMetric(Icons.check_circle_outlined, deck.completedCount.toString()),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Published',
        style: TextStyle(
          color: Color(0xFF166534),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSmallMetric(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: WebColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: WebColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: WebColors.border, style: BorderStyle.none), // Using a border for spacing
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: WebColors.backgroundAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_outlined, size: 48, color: WebColors.primary),
          ),
          const SizedBox(height: 32),
          Text(
            'Your Teaching Hub is Empty',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'Publish your first exam or study pack to see student insights here.',
            style: TextStyle(color: WebColors.textSecondary),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () => context.go('/create'),
            icon: const Icon(Icons.add),
            label: const Text('Create First Asset'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeView(ThemeData theme) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000),
        padding: const EdgeInsets.all(40),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: WebColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'CREATOR MODE',
                      style: TextStyle(
                        color: WebColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Unlock the Educator Toolkit',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: WebColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildFeatureRow(Icons.check_circle, 'Publish interactive exams to the public library'),
                  _buildFeatureRow(Icons.check_circle, 'Advanced PDF exports with marking schemes'),
                  _buildFeatureRow(Icons.check_circle, 'Detailed student performance analytics'),
                  _buildFeatureRow(Icons.check_circle, 'Curriculum-aligned question generation'),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 250,
                    child: ElevatedButton(
                      onPressed: () => context.push('/settings/subscription'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Upgrade to Pro Now'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Continue as Student'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 60),
            Expanded(
              child: Container(
                height: 500,
                decoration: BoxDecoration(
                  color: WebColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(32),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/web/teacher_preview.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: WebColors.primary, size: 24),
          const SizedBox(width: 16),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: WebColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

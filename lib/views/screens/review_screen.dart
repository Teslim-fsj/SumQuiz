import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../providers/sync_provider.dart';
import '../../services/local_database_service.dart';
import '../../models/flashcard_set.dart';
import '../../models/user_model.dart';
import '../../models/daily_mission.dart';
import '../../services/mission_service.dart';
import '../../services/user_service.dart';
import 'spaced_repetition_screen.dart';
import 'package:sumquiz/view_models/mastery_view_model.dart';

import '../widgets/dashboard/retention_health_card.dart';
import '../widgets/dashboard/live_tutor_card.dart';
import '../widgets/dashboard/learning_momentum_card.dart';
import '../widgets/dashboard/daily_mission_card.dart';

class ReviewScreen extends StatefulWidget {
  final bool autoStartMission;
  const ReviewScreen({super.key, this.autoStartMission = false});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  DailyMission? _dailyMission;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(ReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoStartMission && !oldWidget.autoStartMission) {
      _startMission();
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
    await localDb.init();

    if (mounted) {
      await Provider.of<SyncProvider>(context, listen: false).syncData();
    }

    await _loadMission();

    if (widget.autoStartMission) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startMission();
      });
    }
  }

  Future<void> _loadMission() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final missionService =
          Provider.of<MissionService>(context, listen: false);
      final mission = await missionService.generateDailyMission(userId);
      setState(() {
        _dailyMission = mission;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startMission() async {
    if (_dailyMission == null) return;
    setState(() => _isLoading = true);

    try {
      final userId =
          Provider.of<AuthService>(context, listen: false).currentUser?.uid;
      final missionService =
          Provider.of<MissionService>(context, listen: false);
      final cards = await missionService.fetchMissionCards(
          userId!, _dailyMission!.flashcardIds);

      if (cards.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No flashcards found for mission.')),
          );
        }
        return;
      }

      setState(() => _isLoading = false);
      if (!mounted) return;

      final reviewSet = FlashcardSet(
        id: 'mission_session',
        title: 'Daily Mission',
        flashcards: cards,
        timestamp: Timestamp.now(),
      );

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlashcardsScreen(flashcardSet: reviewSet),
        ),
      );

      if (result != null && result is double && mounted) {
        await missionService.completeMission(userId, _dailyMission!, result);
        final userService = UserService();
        await userService.incrementItemsCompleted(userId);
        _loadDashboardData();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Neural Weak Topic Detector',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SpacedRepetitionScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<MasteryViewModel>(
          builder: (context, masteryVm, _) {
            if (masteryVm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: () async {
                await _loadDashboardData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(user, theme),
                    const SizedBox(height: 24),
                    RetentionHealthCard(
                      score: masteryVm.overallMastery,
                      onTap: () {},
                    ),
                    const SizedBox(height: 24),
                    DailyMissionCard(
                      mission: _dailyMission,
                      isLoading: _isLoading,
                      onStart: _startMission,
                    ),
                    const SizedBox(height: 24),
                    const LiveTutorCard(),
                    const SizedBox(height: 24),
                    LearningMomentumCard(user: user),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel? user, ThemeData theme) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello,',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.displayName ?? 'Learner',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Colors.orange, size: 20),
              const SizedBox(width: 4),
              Text(
                '${user?.missionCompletionStreak ?? 0}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

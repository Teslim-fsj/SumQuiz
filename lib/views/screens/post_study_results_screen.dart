import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/sumi_mascot.dart';
import '../../models/sumi_emotion.dart';

class PostStudyResultsScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final int timeSpentSeconds; // In seconds
  final String title;
  final String type; // 'quiz' or 'flashcards'

  const PostStudyResultsScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.timeSpentSeconds,
    required this.title,
    this.type = 'quiz',
  });

  double get accuracy => (score / totalQuestions) * 100;
  String get timeFormatted {
    final minutes = timeSpentSeconds ~/ 60;
    final seconds = timeSpentSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  SumiState get _mascotState {
    if (accuracy >= 80) return SumiState.celebrating;
    if (accuracy >= 50) return SumiState.idle;
    return SumiState.incorrect; // Sad/Disappointed
  }

  String get _sumiMessage {
    if (accuracy >= 90) {
      return "Masterful! You've practically absorbed this knowledge. Sumi is impressed!";
    }
    if (accuracy >= 75) {
      return "Great job! Your neural pathways are strengthening. Let's keep this momentum!";
    }
    if (accuracy >= 50) {
      return "Solid effort! A bit more review and you'll have this mastered. Ready for another round?";
    }
    return "This was a tough one. Don't worry, even Sumi has off-days. Let's review the summary together!";
  }

  void _shareResult(BuildContext context) {
    final message =
        "🔥 Just crushed my $type on '$title' with ${accuracy.toStringAsFixed(0)}% accuracy! \n\nLearning is faster with Sumi. Try it on SumQuiz! #SumQuiz #AI #StudySmart";
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    theme.colorScheme.surface,
                    theme.colorScheme.surface.withValues(alpha: 0.8)
                  ]
                : [
                    theme.colorScheme.primary.withValues(alpha: 0.05),
                    Colors.white
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Sumi Mascot Reaction
              SumiMascot(
                state: _mascotState,
                size: 200,
                dialogue: _sumiMessage,
              )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(begin: const Offset(0.8, 0.8)),

              const SizedBox(height: 40),

              // Title & Type
              Text(
                type.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

              const SizedBox(height: 40),

              // Metrics Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    _buildMetricCard(
                      context,
                      "Accuracy",
                      "${accuracy.toStringAsFixed(0)}%",
                      Icons.insights,
                      theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    _buildMetricCard(
                      context,
                      "Time",
                      timeFormatted,
                      Icons.timer_outlined,
                      Colors.orange,
                    ),
                    const SizedBox(width: 16),
                    _buildMetricCard(
                      context,
                      "Score",
                      "$score/$totalQuestions",
                      Icons.star_outline,
                      Colors.amber,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),

              const Spacer(),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _shareResult(context),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text("SHARE MY SUCCESS"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ).animate().fadeIn(delay: 1000.ms),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text("Back to Library"),
                    ).animate().fadeIn(delay: 1100.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

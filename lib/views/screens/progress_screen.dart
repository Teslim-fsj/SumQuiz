import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/cyber_neural_theme.dart';

import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/spaced_repetition_service.dart';
import 'package:sumquiz/widgets/activity_chart.dart';
import 'package:sumquiz/services/user_service.dart';
import 'package:sumquiz/views/screens/spaced_repetition_screen.dart';
import '../../widgets/sumi_mascot.dart';
import '../../models/sumi_emotion.dart';
import '../../view_models/mastery_view_model.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Future<Map<String, dynamic>>? _statsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<UserModel?>(context);
    if (user != null) {
      _statsFuture = _loadStats(user.uid);
    }
  }

  Future<Map<String, dynamic>> _loadStats(String userId) async {
    try {
      final dbService = LocalDatabaseService();
      await dbService.init();
      final srsService =
          SpacedRepetitionService(dbService.getSpacedRepetitionBox());

      // Fetch Local Data
      final srsStats = await srsService.getStatistics(userId);
      final summaries = await dbService.getAllSummaries(userId);
      final quizzes = await dbService.getAllQuizzes(userId);
      final flashcards = await dbService.getAllFlashcardSets(userId);

      // Calculate Quiz Stats Locally
      double totalAccuracy = 0.0;
      int quizCountWithscores = 0;
      int totalTimeSpent = 0;

      for (var quiz in quizzes) {
        if (quiz.scores.isNotEmpty) {
          // Average score for this quiz
          final avgQuizScore =
              quiz.scores.reduce((a, b) => a + b) / quiz.scores.length;
          totalAccuracy += avgQuizScore;
          quizCountWithscores++;
        }
        totalTimeSpent += quiz.timeSpent;
      }

      final averageAccuracy =
          quizCountWithscores > 0 ? totalAccuracy / quizCountWithscores : 0.0;

      final result = {
        ...srsStats,
        'summariesCount': summaries.length,
        'quizzesCount': quizzes.length,
        'flashcardsCount': flashcards.length,
        'averageAccuracy': averageAccuracy,
        'totalTimeSpent': totalTimeSpent,
      };
      developer.log('Stats loaded successfully from LOCAL DB: $result',
          name: 'ProgressScreen');
      return result;
    } catch (e, s) {
      developer.log('Error loading stats',
          name: 'ProgressScreen', error: e, stackTrace: s);
      // Return default stats instead of rethrowing
      return {
        'summariesCount': 0,
        'quizzesCount': 0,
        'flashcardsCount': 0,
        'averageAccuracy': 0.0,
        'totalTimeSpent': 0,
        'dueForReviewCount': 0,
        'upcomingReviews': <MapEntry<DateTime, int>>[],
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Unauthorized access. Link neural profile.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)));
            }

            final stats = snapshot.data ?? {};

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _statsFuture = _loadStats(user.uid);
                });
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTerminalHeader(),
                    const SizedBox(height: 24),
                    _buildModuleAlert(theme),
                    const SizedBox(height: 32),
                    _buildStabilityModule(theme),
                    const SizedBox(height: 32),
                    _buildKnowledgeMatrix(theme),
                    const SizedBox(height: 32),
                    _buildTelemetryPanel(theme, stats),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTerminalHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.terminal_rounded, color: Color(0xFF22D3EE), size: 24),
            const SizedBox(width: 12),
            Text(
              "SYS_ALPS_v2.4",
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF22D3EE).withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const Icon(Icons.settings_input_component_rounded, size: 14, color: Color(0xFF22D3EE)),
              const SizedBox(width: 8),
              Text(
                "CYCLES: 12",
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF22D3EE),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModuleAlert(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
              ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 500.ms).fadeOut(delay: 500.ms),
              const SizedBox(width: 12),
              Text(
                "ALERT: KNOWLEDGE DECAY DETECTED",
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text("T-MINUS 05:00", style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "MODULE: QUANTUM_PHYSICS.SYS",
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _buildTerminalLine("Scanning comprehension nodes..."),
          _buildTerminalLine("Risk assessed: 40% structural fading."),
          _buildTerminalLine("Recommendation: Immediate shielding protocol."),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildTerminalButton("Rapid Shielding", isPrimary: true),
              const SizedBox(width: 12),
              _buildTerminalButton("Deep Reinforcement", isPrimary: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        "> $text",
        style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 11),
      ),
    );
  }

  Widget _buildTerminalButton(String label, {required bool isPrimary}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF1E293B) : Colors.transparent,
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: isPrimary ? Colors.white : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStabilityModule(ThemeData theme) {
    return Consumer<MasteryViewModel>(
      builder: (context, masteryVm, _) {
        final score = masteryVm.overallMastery;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("STABILITY_IDX", style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 12)),
                Text("OK", style: GoogleFonts.jetBrainsMono(color: const Color(0xFF22D3EE), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(score.toStringAsFixed(3), style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text("+0.042", style: GoogleFonts.jetBrainsMono(color: const Color(0xFF22D3EE), fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: score,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF22D3EE), Color(0xFFA855F7)]),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKnowledgeMatrix(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("KNOWLEDGE MATRIX", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
            Text("SECTORS: 6x4", style: GoogleFonts.jetBrainsMono(color: const Color(0xFF22D3EE), fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: 24,
          itemBuilder: (context, index) {
            // Simulated stability colors
            final colors = [
              const Color(0xFF22D3EE),
              const Color(0xFF0F172A),
              const Color(0xFF1E293B),
              const Color(0xFF7F1D1D),
              const Color(0xFF334155),
              const Color(0xFFA855F7).withValues(alpha: 0.5),
            ];
            final color = colors[index % colors.length];
            return Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .shimmer(delay: (index * 100).ms, duration: 2.seconds, color: Colors.white12);
          },
        ),
        const SizedBox(height: 16),
        Text(
          ">> SYS.ANALYSIS: Retention velocity +15% pre-1000HRS. Prioritize Sector 4,2.",
          style: GoogleFonts.jetBrainsMono(color: Colors.orangeAccent.withValues(alpha: 0.8), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildTelemetryPanel(ThemeData theme, Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("TELEMETRY", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            const Icon(Icons.circle, size: 8, color: Color(0xFF22D3EE)),
          ],
        ),
        const SizedBox(height: 16),
        _buildTelemetryRow("SYNC_RATE", "94.2%"),
        _buildTelemetryRow("NODE_LATENCY", "12ms", color: const Color(0xFF22D3EE)),
        _buildTelemetryRow("DECAY_VOL", "1.4μ", color: Colors.redAccent.withValues(alpha: 0.8)),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              "VIEW FULL LOGS",
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 12)),
          Text(value, style: GoogleFonts.jetBrainsMono(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getMasteryColor(double score) {
    if (score < 0.3) return Colors.redAccent;
    if (score < 0.7) return Colors.orangeAccent;
    return const Color(0xFF22D3EE);
  }
}



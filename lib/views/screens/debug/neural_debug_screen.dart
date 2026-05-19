import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/mastery/topic_node.dart';
import 'package:sumquiz/services/mastery_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NeuralDebugScreen extends StatefulWidget {
  const NeuralDebugScreen({super.key});

  @override
  State<NeuralDebugScreen> createState() => _NeuralDebugScreenState();
}

class _NeuralDebugScreenState extends State<NeuralDebugScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final masteryService = Provider.of<MasteryService>(context);
    final user = Provider.of<UserModel?>(context);

    if (user == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
            child: Text('Please login to use neural debug.',
                style: GoogleFonts.inter())),
      );
    }

    final topics = masteryService.getUserTopics(user.uid);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('System Analytics',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.hintColor),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGlobalStats(theme, masteryService, user.uid),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'TOPIC NODES',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: theme.hintColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${topics.length} TOTAL',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.hintColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: topics.length,
              itemBuilder: (context, index) {
                final topic = topics[index];
                return _buildTopicCard(theme, topic, masteryService)
                    .animate()
                    .fadeIn(delay: (index * 50).ms)
                    .slideY(begin: 0.1, end: 0);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalStats(
      ThemeData theme, MasteryService service, String userId) {
    final avg = service.getAverageMastery(userId);
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(
              theme, 'Average Mastery', '${(avg * 100).toStringAsFixed(1)}%'),
          Container(
              width: 1,
              height: 40,
              color: theme.dividerColor.withValues(alpha: 0.1)),
          _statItem(theme, 'Active Clusters',
              '${service.getUserTopics(userId).length}'),
        ],
      ),
    );
  }

  Widget _statItem(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: theme.hintColor,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.outfit(
                color: theme.textTheme.displayLarge?.color,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTopicCard(
      ThemeData theme, TopicNode topic, MasteryService service) {
    final alps = service.calculateALPS(topic);
    final lastSeen = DateFormat('MMM d, HH:mm').format(topic.lastInteraction);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(topic.name,
            style:
                GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(
          'Mastery: ${(topic.masteryScore * 100).toStringAsFixed(0)}% • Risk: ${(topic.forgettingRisk * 100).toStringAsFixed(0)}%',
          style: GoogleFonts.inter(fontSize: 12, color: theme.hintColor),
        ),
        trailing: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: alps,
                backgroundColor: theme.dividerColor.withValues(alpha: 0.05),
                color: theme.colorScheme.primary,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
              ),
              Text(
                (alps * 10).toStringAsFixed(0),
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(color: theme.dividerColor.withValues(alpha: 0.05)),
                const SizedBox(height: 12),
                _detailRow(theme, 'Stability', topic.stabilityScore),
                _detailRow(theme, 'Confidence', topic.confidenceScore),
                _detailRow(theme, 'Priority', alps),
                const SizedBox(height: 12),
                Text('Telemetry Sync: $lastSeen',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 10, color: theme.hintColor)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _debugAction(
                          theme,
                          'Success',
                          Icons.check_circle_outline,
                          () => _injectSignal(
                              topic.id, SignalType.quizCorrect, service)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _debugAction(
                          theme,
                          'Fail',
                          Icons.error_outline,
                          () => _injectSignal(
                              topic.id, SignalType.quizWrong, service),
                          isRed: true),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _debugAction(
                          theme,
                          '+Day',
                          Icons.fast_forward_rounded,
                          () => _fastForward(topic, service)),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _debugAction(
      ThemeData theme, String label, IconData icon, VoidCallback onTap,
      {bool isRed = false}) {
    final color = isRed ? const Color(0xFFEF4444) : theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.hintColor))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: theme.dividerColor.withValues(alpha: 0.05),
                minHeight: 6,
                valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary.withValues(alpha: 0.6)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(value.toStringAsFixed(2),
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _injectSignal(
      String topicId, SignalType type, MasteryService service) async {
    await service.processSignal(LearningSignal(
      topicId: topicId,
      type: type,
      timestamp: DateTime.now(),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _fastForward(TopicNode topic, MasteryService service) async {
    topic.lastInteraction =
        topic.lastInteraction.subtract(const Duration(days: 1));
    await topic.save();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time shifted back by 1 day.')));
    }
  }
}

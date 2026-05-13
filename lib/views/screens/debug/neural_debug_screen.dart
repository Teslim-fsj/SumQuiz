import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/mastery/topic_node.dart';
import 'package:sumquiz/services/mastery_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:intl/intl.dart';

class NeuralDebugScreen extends StatefulWidget {
  const NeuralDebugScreen({super.key});

  @override
  State<NeuralDebugScreen> createState() => _NeuralDebugScreenState();
}

class _NeuralDebugScreenState extends State<NeuralDebugScreen> {
  @override
  Widget build(BuildContext context) {
    final masteryService = Provider.of<MasteryService>(context);
    final user = Provider.of<UserModel?>(context);
    
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login to use neural debug.')));
    }

    final topics = masteryService.getUserTopics(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neural Debug Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGlobalStats(masteryService, user.uid),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: topics.length,
              itemBuilder: (context, index) {
                final topic = topics[index];
                return _buildTopicCard(topic, masteryService);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalStats(MasteryService service, String userId) {
    final avg = service.getAverageMastery(userId);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: Colors.blueGrey[900],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('Avg Mastery', '${(avg * 100).toStringAsFixed(1)}%'),
              _statItem('Total Topics', '${service.getUserTopics(userId).length}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTopicCard(TopicNode topic, MasteryService service) {
    final alps = service.calculateALPS(topic);
    final lastSeen = DateFormat('MMM d, HH:mm').format(topic.lastInteraction);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(topic.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Mastery: ${(topic.masteryScore * 100).toStringAsFixed(0)}% | Risk: ${(topic.forgettingRisk * 100).toStringAsFixed(0)}%'),
        trailing: CircularProgressIndicator(
          value: alps,
          backgroundColor: Colors.grey[200],
          color: Colors.orange,
          strokeWidth: 4,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Stability', topic.stabilityScore),
                _detailRow('Confidence', topic.confidenceScore),
                _detailRow('ALPS Priority', alps),
                Text('Last Interaction: $lastSeen', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () => _injectSignal(topic.id, SignalType.quizCorrect, service),
                      child: const Text('Sim Success'),
                    ),
                    ElevatedButton(
                      onPressed: () => _injectSignal(topic.id, SignalType.quizWrong, service),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100]),
                      child: const Text('Sim Failure'),
                    ),
                    ElevatedButton(
                      onPressed: () => _fastForward(topic, service),
                      child: const Text('+1 Day'),
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

  Widget _detailRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey[200],
              minHeight: 8,
            ),
          ),
          const SizedBox(width: 8),
          Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _injectSignal(String topicId, SignalType type, MasteryService service) async {
    await service.processSignal(LearningSignal(
      topicId: topicId,
      type: type,
      timestamp: DateTime.now(),
    ));
    setState(() {});
  }

  Future<void> _fastForward(TopicNode topic, MasteryService service) async {
    // Manually manipulate timestamp for testing forgetting risk
    topic.lastInteraction = topic.lastInteraction.subtract(const Duration(days: 1));
    await topic.save();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time shifted back by 1 day. Refresh to see risk update.')));
  }
}

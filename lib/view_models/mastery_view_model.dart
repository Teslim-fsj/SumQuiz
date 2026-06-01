import 'package:flutter/material.dart';
import '../services/mastery_service.dart';
import '../models/mastery/topic_node.dart';

class MasteryViewModel extends ChangeNotifier {
  final MasteryService _masteryService;
  final String userId;

  List<TopicNode> _topics = [];
  bool _isLoading = false;

  MasteryViewModel(this._masteryService, this.userId) {
    _loadMasteryData();
    _masteryService.addListener(_onMasteryServiceChanged);
  }

  List<TopicNode> get topics => _topics;
  bool get isLoading => _isLoading;

  double get overallMastery => _masteryService.getAverageMastery(userId);

  double get retentionHealth => _masteryService.getRetentionHealthScore(userId);

  List<TopicNode> get weakZones => _masteryService.getWeakZones(userId);

  List<TopicNode> get highRiskTopics =>
      _topics.where((t) => t.forgettingRisk > 0.6).toList()
        ..sort((a, b) => b.forgettingRisk.compareTo(a.forgettingRisk));

  List<TopicNode> get priorityTopics =>
      _masteryService.getPriorityTopics(userId, limit: 3);

  void _onMasteryServiceChanged() {
    _loadMasteryData();
  }

  Future<void> _loadMasteryData() async {
    _isLoading = true;
    notifyListeners();

    _topics = _masteryService.getUserTopics(userId);

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _masteryService.removeListener(_onMasteryServiceChanged);
    super.dispose();
  }
}

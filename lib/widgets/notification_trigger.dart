import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/notification_service.dart';
import 'package:sumquiz/services/notification_manager.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/user_model.dart';

/// Widget to integrate notification scheduling throughout the app
/// Add this to screens where you want to trigger notifications
class NotificationTrigger extends StatelessWidget {
  final Widget child;
  final VoidCallback? onInit;

  const NotificationTrigger({
    super.key,
    required this.child,
    this.onInit,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }

  /// Schedule notifications after user registration
  static Future<void> onUserRegistered(
    BuildContext context,
    UserModel user,
  ) async {
    final notificationManager = NotificationManager(
      context.read<NotificationService>(),
      context.read<LocalDatabaseService>(),
    );

    await notificationManager.scheduleWelcomeNotification(user);
    await notificationManager.scheduleAllNotifications(user);
  }

  /// Schedule notifications after content generation
  static Future<void> onContentGenerated(
    BuildContext context,
    UserModel user,
    String topic,
  ) async {
    final notificationManager = NotificationManager(
      context.read<NotificationService>(),
      context.read<LocalDatabaseService>(),
    );

    await notificationManager.scheduleDailyLearningReminder(user);
    await notificationManager.scheduleTopicRecommendation(topic, topic);
  }

  /// Schedule notifications after quiz completion
  static Future<void> onQuizCompleted(
    BuildContext context,
    String topic,
  ) async {
    final notificationManager = NotificationManager(
      context.read<NotificationService>(),
      context.read<LocalDatabaseService>(),
    );

    await notificationManager.schedulePostQuizNudge(topic);
  }

  /// Schedule notifications when usage limit is hit
  static Future<void> onUsageLimitHit(BuildContext context) async {
    final notificationManager = NotificationManager(
      context.read<NotificationService>(),
      context.read<LocalDatabaseService>(),
    );

    await notificationManager.scheduleProUpgradeReminder();
  }

  /// Schedule daily mission notifications
  static Future<void> onDailyMissionGenerated(
    BuildContext context, {
    required String userId,
    required String preferredStudyTime,
    required int cardCount,
    required int estimatedMinutes,
  }) async {
    final notificationManager = NotificationManager(
      context.read<NotificationService>(),
      context.read<LocalDatabaseService>(),
    );

    await notificationManager.scheduleDailyMissionPriming(
      userId: userId,
      preferredStudyTime: preferredStudyTime,
      cardCount: cardCount,
      estimatedMinutes: estimatedMinutes,
    );
  }

  /// Schedule notifications after mission completion
  static Future<void> onMissionCompleted(
    BuildContext context, {
    required int momentumGain,
    required int currentStreak,
  }) async {
    final notificationManager = NotificationManager(
      context.read<NotificationService>(),
      context.read<LocalDatabaseService>(),
    );

    await notificationManager.scheduleMissionRecall(
      momentumGain: momentumGain,
    );
  }

  /// Schedule streak saver notification
  static Future<void> onMissionIncomplete(
    BuildContext context, {
    required int currentStreak,
    required int remainingCards,
  }) async {
    final notificationManager = NotificationManager(
      context.read<NotificationService>(),
      context.read<LocalDatabaseService>(),
    );

    await notificationManager.scheduleStreakSaver(
      currentStreak: currentStreak,
      remainingCards: remainingCards,
    );
  }

  /// Test notification (for debugging)
  static Future<void> testNotification(BuildContext context) async {
    final notificationService = context.read<NotificationService>();
    await notificationService.showTestNotification();
  }
}

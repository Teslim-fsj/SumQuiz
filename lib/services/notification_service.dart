import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

final didReceiveLocalNotificationSubject =
    BehaviorSubject<ReceivedNotification>();

class ReceivedNotification {
  final int id;
  final String? title;
  final String? body;
  final String? payload;

  ReceivedNotification({
    required this.id,
    this.title,
    this.body,
    this.payload,
  });
}

class NotificationService {
  late final FlutterLocalNotificationsPlugin _localNotifications;
  late final FirebaseMessaging _firebaseMessaging;
  Map<String, dynamic> _notificationTemplates = {};
  static const String notificationEnabledKey = 'notifications_enabled';

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  Future<void> initialize() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    _firebaseMessaging = FirebaseMessaging.instance;
    tz.initializeTimeZones();

    // Set local time zone
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneName = timeZoneInfo.identifier; // The standard getter
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    await _loadNotificationTemplates();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationResponse(response);
      },
    );

    // Handle initial notification if app was closed
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final response = notificationAppLaunchDetails!.notificationResponse;
      if (response != null) {
        _handleNotificationResponse(response);
      }
    }

    await _setupPushNotifications();
    await requestPermissions();
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      didReceiveLocalNotificationSubject.add(
        ReceivedNotification(
          id: response.id ?? 0,
          title: response.notificationResponseType ==
                  NotificationResponseType.selectedNotification
              ? response.payload
              : null,
          body: response.notificationResponseType ==
                  NotificationResponseType.selectedNotification
              ? response.payload
              : null,
          payload: response.payload,
        ),
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
    debugPrint('🚫 Cancelled notification: $id');
  }

  Future<void> cancelWorkManagerTask(String tag) async {
    try {
      await Workmanager().cancelByUniqueName(tag);
      debugPrint('🚫 Cancelled WorkManager task: $tag');
    } catch (e) {
      debugPrint('Error cancelling WorkManager task $tag: $e');
    }
  }

  Future<void> _loadNotificationTemplates() async {
    final String response =
        await rootBundle.loadString('assets/notification_templates.json');
    _notificationTemplates = await json.decode(response);
  }

  String _getPersonalizedMessage(String category, Map<String, String> data) {
    final List<dynamic> messages = _notificationTemplates[category] ?? [];
    if (messages.isEmpty) {
      return 'Welcome to SumQuiz!'; // Fallback message
    }
    final String message = messages[Random().nextInt(messages.length)];
    String personalizedMessage = message;
    data.forEach((key, value) {
      personalizedMessage = personalizedMessage.replaceAll('{$key}', value);
    });
    return personalizedMessage;
  }

  Future<void> _setupPushNotifications() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotificationFromMessage(message);
    });

    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
          'Opened from terminated state with message: ${initialMessage.data}');
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Opened from background state with message: ${message.data}');
    });
  }

  Future<void> requestPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(notificationEnabledKey) ?? true) {
      // Request Android notification permission (required for Android 13+)
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('🔔 Android notification permission granted: $granted');
      }

      // Request iOS notification permissions
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      // Request Firebase Messaging permissions (for push notifications)
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    }
  }

  void _showNotificationFromMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'general_channel',
            'General Notifications',
            channelDescription: 'General app notifications',
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: json.encode(message.data),
      );
    }
  }

  Future<void> showTestNotification() async {
    await scheduleNotification(
      99,
      'Test Notification',
      'system_and_updates',
      {},
      payloadRoute: '/',
      days: 0, // Schedule for a few seconds from now for testing
    );
  }

  Future<void> scheduleNotification(
    int id,
    String title,
    String category,
    Map<String, String> data, {
    required String payloadRoute,
    int days = 1,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(notificationEnabledKey) ?? true)) return;

    final String message = _getPersonalizedMessage(category, data);
    final tz.TZDateTime scheduledDate = _getScheduledDateTime(days: days);

    final Duration delay = scheduledDate.isAfter(tz.TZDateTime.now(tz.local))
        ? scheduledDate.difference(tz.TZDateTime.now(tz.local))
        : const Duration(seconds: 5);

    if (!kIsWeb) {
      await Workmanager().registerOneOffTask(
        id.toString(),
        'notification_task',
        initialDelay: delay,
        inputData: {
          'id': id,
          'title': title,
          'message': message,
          'payload': json.encode({'route': payloadRoute}),
          'category': category,
        },
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      debugPrint('⏰ Scheduled notification $id via WorkManager with delay: $delay');
    } else {
      debugPrint('🔔 Skipping WorkManager notification $id on Web platform');
    }
  }

  /// Helper to show a notification immediately (called by WorkManager)
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String message,
    required String payload,
    required String category,
  }) async {
    await _localNotifications.show(
      id,
      title,
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          '${category}_channel',
          '$category Notifications',
          channelDescription: 'Notifications for $category',
          importance: Importance.max,
          priority: Priority.high,
          color: Colors.black,
        ),
      ),
      payload: payload,
    );
  }

  tz.TZDateTime _getScheduledDateTime({int days = 1}) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    if (days == 0) {
      return now.add(const Duration(seconds: 5));
    }

    // Start with today at 10 AM
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);

    // Add the specified days
    scheduledDate = scheduledDate.add(Duration(days: days));

    // If the resulting time is in the past, move it to the next day
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Ensure notifications are not sent during quiet hours (10 PM to 7 AM)
    // If it falls in quiet hours, push to 8 AM the next (or current) available day
    if (scheduledDate.hour >= 22 || scheduledDate.hour < 7) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        8,
      );

      // If after adjusting to 8 AM it's still in the past, move to tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
    }

    return scheduledDate;
  }

  Future<void> toggleNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationEnabledKey, enabled);
    if (!enabled) {
      await _localNotifications.cancelAll();
    }
  }

  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notificationEnabledKey) ?? true;
  }

  Future<void> initializeNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Set default value if not set
    if (!prefs.containsKey(notificationEnabledKey)) {
      await prefs.setBool(notificationEnabledKey, true);
    }
  }

  // Mission Engine Notifications

  /// Schedules a "Priming" notification 30 minutes before the user's preferred study time
  Future<void> schedulePrimingNotification({
    required String userId,
    required String preferredStudyTime, // "HH:mm" format
    required int cardCount,
    required int estimatedMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(notificationEnabledKey) ?? true)) return;

    // Parse time
    final parts = preferredStudyTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).subtract(const Duration(minutes: 30)); // 30m before

    // If in the past, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final Duration delay = scheduledDate.difference(now);

    if (!kIsWeb) {
      await Workmanager().registerOneOffTask(
        'priming_$userId',
        'notification_task',
        initialDelay: delay,
        inputData: {
          'id': 1001,
          'title': '🧠 Today\'s Mission is Ready',
          'message': '$cardCount cards • $estimatedMinutes min',
          'payload': json.encode({'route': '/'}),
          'category': 'mission_priming',
        },
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }
  }

  /// Schedules a "Recall" notification 20 hours after mission completion
  Future<void> scheduleRecallNotification({
    required int momentumGain,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(notificationEnabledKey) ?? true)) return;

    if (!kIsWeb) {
      await Workmanager().registerOneOffTask(
        'recall_notification',
        'notification_task',
        initialDelay: const Duration(hours: 20),
        inputData: {
          'id': 1002,
          'title': '🚀 Yesterday: +$momentumGain Momentum',
          'message': 'Keep the habit alive today!',
          'payload': json.encode({'route': '/'}),
          'category': 'mission_recall',
        },
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }
  }

  /// Schedules a "Streak Saver" notification at 8 PM if mission is incomplete
  Future<void> scheduleStreakSaverNotification({
    required int currentStreak,
    required int remainingCards,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(notificationEnabledKey) ?? true)) return;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      20, // 8 PM
      0,
    );

    // If already past 8 PM, skip (don't spam tomorrow)
    if (scheduledDate.isBefore(now)) {
      return;
    }

    final Duration delay = scheduledDate.difference(now);

    if (!kIsWeb) {
      await Workmanager().registerOneOffTask(
        'streak_saver',
        'notification_task',
        initialDelay: delay,
        inputData: {
          'id': 1003,
          'title': '🔥 Save Your $currentStreak-Day Streak!',
          'message': '$remainingCards cards left • 3 mins to complete',
          'payload': json.encode({'route': '/'}),
          'category': 'streak_saver',
        },
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }
  }
}

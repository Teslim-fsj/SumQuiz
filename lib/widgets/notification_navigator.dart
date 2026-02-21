import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/notification_service.dart';

/// Widget that listens for notification taps and handles navigation
class NotificationNavigator extends StatefulWidget {
  final Widget child;

  const NotificationNavigator({super.key, required this.child});

  @override
  State<NotificationNavigator> createState() => _NotificationNavigatorState();
}

class _NotificationNavigatorState extends State<NotificationNavigator> {
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    _notificationSubscription = didReceiveLocalNotificationSubject.listen(
      (notification) {
        if (notification.payload != null) {
          try {
            final data = json.decode(notification.payload!);
            final route = data['route'] as String?;

            if (route != null && mounted) {
              // Use a post-frame callback to ensure context is available
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  GoRouter.of(context).go(route);
                }
              });
            }
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

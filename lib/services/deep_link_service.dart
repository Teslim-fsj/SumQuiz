import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Handles deep links for sumquiz.xyz and sumquiz:// custom scheme
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize deep link handling.
  /// Call once after MaterialApp is built and the router is ready.
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    _appLinks = AppLinks();

    // Handle link that launched the app (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('🔗 Deep link (cold start): $initialUri');
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('❌ Error getting initial deep link: $e');
    }

    // Handle links while app is running (warm start)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('🔗 Deep link (warm): $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('❌ Deep link stream error: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('❌ No navigator context for deep link: $uri');
      return;
    }

    // Extract the path from the deep link
    // Supports:
    //   - https://sumquiz.xyz/library/flashcards/abc123
    //   - sumquiz://library/flashcards/abc123
    //   - https://sumquiz.xyz/deck?id=abc123
    String path = uri.path;

    // If the path is empty or just /, go home
    if (path.isEmpty || path == '/') {
      GoRouter.of(context).go('/');
      return;
    }

    // Preserve query parameters (e.g., /deck?id=abc123)
    if (uri.queryParameters.isNotEmpty) {
      final queryString = uri.query;
      path = '$path?$queryString';
    }

    debugPrint('🔗 Navigating to: $path');
    GoRouter.of(context).go(path);
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/providers/sync_provider.dart';
import 'package:sumquiz/providers/theme_provider.dart';
import 'package:sumquiz/providers/subscription_provider.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/sync_service.dart';
import 'firebase_options.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/view_models/quiz_view_model.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:sumquiz/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/providers/navigation_provider.dart';
import 'package:sumquiz/providers/create_content_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:sumquiz/services/referral_service.dart';
import 'package:sumquiz/services/notification_service.dart';
import 'package:sumquiz/services/user_service.dart';
import 'package:sumquiz/services/youtube_service.dart';
import 'package:sumquiz/view_models/referral_view_model.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/spaced_repetition_service.dart';
import 'package:sumquiz/services/mission_service.dart';
import 'package:sumquiz/services/time_sync_service.dart';
import 'package:sumquiz/services/notification_integration.dart';
import 'package:sumquiz/widgets/notification_navigator.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'notification_task') {
      final id = inputData!['id'];
      final title = inputData['title'] ?? 'Notification';
      final message = inputData['message'] ?? '';
      final payload = inputData['payload'] ?? '';
      final category = inputData['category'] ?? 'general';

      try {
        final notificationService = NotificationService();
        await notificationService.initialize();

        await notificationService.showImmediateNotification(
          id: id,
          title: title,
          message: message,
          payload: payload,
          category: category,
        );
      } catch (e) {
        debugPrint('WorkManager task error: $e');
        return Future.value(false);
      }
    }
    return Future.value(true);
  });
}

void main() async {
  usePathUrlStrategy(); // Remove # from web URLs (sumquiz.xyz/route instead of sumquiz.xyz/#/route)
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  try {
    await LocalDatabaseService().init();
  } catch (e) {
    debugPrint('Database initialization failed: $e');
    // Consider reporting this error or showing a fatal error screen if DB is critical
    // but for now allow app to launch to at least show 'something'
  }

  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.initializeNotificationSettings();

  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug, // Change to playIntegrity in production
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
  }

  final authService = AuthService(FirebaseAuth.instance);

  // Non-blocking TimeSync
  TimeSyncService.syncWithServer().then((_) {
    debugPrint('Time synced successfully');
  }).catchError((e) {
    debugPrint('Startup time sync failed: $e');
  });

  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Log to Crashlytics in release mode
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 56, color: Color(0xFFE57373)),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please go back and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      details.exceptionAsString(),
                      style: const TextStyle(
                          color: Color(0xFFC62828), fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  };

  runApp(MyApp(
      authService: authService, notificationService: notificationService));
}

class MyApp extends StatefulWidget {
  final AuthService authService;
  final NotificationService notificationService;

  const MyApp(
      {super.key,
      required this.authService,
      required this.notificationService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createRouter(widget.authService);
  }

  Future<void> _scheduleNotificationsOnLaunch(BuildContext context) async {
    // Wait a bit for providers to initialize
    await Future.delayed(const Duration(seconds: 2));

    try {
      final user = widget.authService.currentUser;
      if (user != null) {
        // Get user model from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userModel = UserModel.fromFirestore(userDoc);
          if (!context.mounted) return;
          await NotificationIntegration.onAppLaunch(context, userModel);
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to schedule notifications on app launch: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        Provider<AuthService>.value(value: widget.authService),
        Provider<NotificationService>.value(value: widget.notificationService),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<LocalDatabaseService>(create: (_) => LocalDatabaseService()),
        Provider<SpacedRepetitionService>(
            create: (context) => SpacedRepetitionService(
                context.read<LocalDatabaseService>().getSpacedRepetitionBox())),
        ProxyProvider<AuthService, IAPService?>(
          update: (context, authService, previous) {
            final user = authService.currentUser;
            if (user != null) {
              if (previous != null) {
                return previous;
              }
              final service = IAPService();
              service.initialize();
              return service;
            }
            previous?.dispose();
            return null;
          },
          dispose: (_, service) => service?.dispose(),
        ),
        ChangeNotifierProxyProvider<IAPService?, SubscriptionProvider>(
          create: (context) =>
              SubscriptionProvider(context.read<IAPService?>()),
          update: (context, iapService, previous) =>
              previous!..update(iapService),
        ),
        ProxyProvider<IAPService, EnhancedAIService>(
          update: (context, iapService, previous) {
            final service = EnhancedAIService(iapService: iapService);
            // Initialize the service asynchronously
            service.initialize().catchError((e) {
              debugPrint('Error initializing EnhancedAIService: $e');
            });
            return service;
          },
        ),
        ProxyProvider<EnhancedAIService, ContentExtractionService>(
          update: (context, enhancedAIService, previous) =>
              ContentExtractionService(enhancedAIService),
        ),
        Provider<YoutubeService>(create: (_) => YoutubeService()),
        Provider<UserService>(create: (_) => UserService()),
        Provider<SyncService>(
          create: (context) =>
              SyncService(context.read<LocalDatabaseService>()),
        ),
        ChangeNotifierProvider<QuizViewModel>(
          create: (context) => QuizViewModel(
              context.read<LocalDatabaseService>(),
              context.read<AuthService>()),
        ),
        ChangeNotifierProxyProvider<SyncService, SyncProvider>(
          create: (context) => SyncProvider(context.read<SyncService>()),
          update: (context, syncService, previous) => SyncProvider(syncService),
        ),
        ProxyProvider<AuthService, UsageService?>(
          update: (context, authService, previous) {
            final user = authService.currentUser;
            return user != null ? UsageService() : null;
          },
        ),
        ProxyProvider<AuthService, ReferralService>(
          update: (context, authService, previous) {
            return ReferralService();
          },
        ),
        ProxyProvider4<FirestoreService, LocalDatabaseService,
            SpacedRepetitionService, NotificationService, MissionService>(
          update: (context, firestore, localDb, srs, notificationService,
                  previous) =>
              MissionService(
            firestoreService: firestore,
            localDb: localDb,
            srs: srs,
            notificationService: notificationService,
          ),
        ),
        StreamProvider<UserModel?>(
          create: (context) => context.read<AuthService>().user,
          initialData: null,
        ),
        ChangeNotifierProxyProvider<AuthService, ReferralViewModel>(
          create: (context) => ReferralViewModel(
              context.read<ReferralService>(), context.read<AuthService>()),
          update: (context, authService, previous) {
            previous?.update(context.read<ReferralService>(), authService);
            return previous!;
          },
        ),
        ChangeNotifierProxyProvider4<ContentExtractionService, EnhancedAIService,
            LocalDatabaseService, YoutubeService, CreateContentProvider>(
          create: (context) => CreateContentProvider(
            extractionService: context.read<ContentExtractionService>(),
            aiService: context.read<EnhancedAIService>(),
            localDb: context.read<LocalDatabaseService>(),
            youtubeService: context.read<YoutubeService>(),
          ),
          update: (context, extraction, ai, localDb, youtube, previous) =>
              previous ??
              CreateContentProvider(
                extractionService: extraction,
                aiService: ai,
                localDb: localDb,
                youtubeService: youtube,
              ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Builder(
            builder: (context) {
              // Schedule notifications after providers are available
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scheduleNotificationsOnLaunch(context);
              });

              return NotificationNavigator(
                child: MaterialApp.router(
                  title: 'SumQuiz',
                  theme: kIsWeb
                      ? (themeProvider.themeMode == ThemeMode.dark
                          ? WebTheme.darkTheme
                          : WebTheme.lightTheme)
                      : themeProvider.getTheme(),
                  darkTheme: kIsWeb
                      ? (themeProvider.themeMode == ThemeMode.dark
                          ? WebTheme.darkTheme
                          : WebTheme.lightTheme)
                      : themeProvider.getTheme(),
                  themeMode: kIsWeb
                      ? (themeProvider.themeMode == ThemeMode.dark
                          ? ThemeMode.dark
                          : ThemeMode.light)
                      : themeProvider.themeMode,
                  routerConfig: _router,
                  debugShowCheckedModeBanner: false,
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    FlutterQuillLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('en', ''),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

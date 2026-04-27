import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/models/flashcard_set.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/views/screens/auth_screen.dart';
import 'package:sumquiz/views/screens/library_screen.dart';
import 'package:sumquiz/views/screens/progress_screen.dart';
import 'package:sumquiz/views/screens/settings_screen.dart';
import 'package:sumquiz/views/screens/review_screen.dart';
import 'package:sumquiz/views/screens/summary_screen.dart';
import 'package:sumquiz/views/screens/quiz_screen.dart';
import 'package:sumquiz/views/screens/flashcards_screen.dart';
import 'package:sumquiz/views/screens/creator_dashboard_screen.dart';
import 'package:sumquiz/views/screens/preferences_screen.dart';
import 'package:sumquiz/views/screens/data_storage_screen.dart';
import 'package:sumquiz/views/screens/subscription_screen.dart';
import 'package:sumquiz/views/screens/privacy_about_screen.dart';
import 'package:sumquiz/views/screens/splash_screen.dart';
import 'package:sumquiz/views/screens/onboarding_screen.dart';
import 'package:sumquiz/views/screens/referral_screen.dart';
import 'package:sumquiz/views/screens/account_profile_screen.dart';
import 'package:sumquiz/views/screens/create_content_screen.dart';
import 'package:sumquiz/views/screens/results_view_screen.dart';
import 'package:sumquiz/views/widgets/scaffold_with_nav_bar.dart';
import 'package:sumquiz/views/widgets/responsive_view.dart';
import 'package:sumquiz/views/screens/web/library_screen_web.dart';
import 'package:sumquiz/views/screens/web/create_content_screen_web.dart';
import 'package:sumquiz/views/screens/web/progress_screen_web.dart';
import 'package:sumquiz/views/screens/web/results_view_screen_web.dart';
import 'package:sumquiz/views/screens/web/teacher_dashboard_web.dart';
import 'package:sumquiz/views/screens/web/public_scaffold_web.dart';
import 'package:sumquiz/views/screens/web/student_landing_view.dart';
import 'package:sumquiz/views/screens/web/creator_tab_view.dart';
import 'package:sumquiz/views/screens/exam_creation_screen.dart';
import 'package:sumquiz/views/screens/web/review_screen_web.dart';
import 'package:sumquiz/views/screens/web/exam_creation_screen_web.dart';
import 'package:sumquiz/views/screens/public_deck_screen.dart';

// Role-Aware view helper
class RoleAwareView extends StatelessWidget {
  final Widget studentView;
  final Widget creatorView;

  const RoleAwareView({
    super.key,
    required this.studentView,
    required this.creatorView,
  });

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    if (user?.role == UserRole.creator) {
      return creatorView;
    }
    return studentView;
  }
}

// GoRouterRefreshStream class
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

// Keys for shell branches
final _libraryShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'LibraryShell');
final _reviewShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'ReviewShell');
final _createShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'CreateShell');
final _progressShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'ProgressShell');
final _profileShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'ProfileShell');
final _settingsShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'SettingsShell');
final _studentsShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'StudentsShell');
final _feedbackShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'FeedbackShell');

GoRouter createRouter(AuthService authService) {
  final authStream = authService.authStateChanges;

  return GoRouter(
    initialLocation: '/',
    navigatorKey: rootNavigatorKey,
    refreshListenable: GoRouterRefreshStream(authStream),
    redirect: (context, state) {
      // Navigation State Helpers
      final isAuthRoute = state.matchedLocation == '/auth';
      final isLanding = state.matchedLocation == '/landing' || state.matchedLocation == '/Educators';
      final isSplash = state.matchedLocation == '/splash';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isPublicDeck = state.matchedLocation.startsWith('/s/') || state.matchedLocation == '/deck';

      final userModel = Provider.of<UserModel?>(context);
      final firebaseUser = authService.currentUser;

      // 1. Handle Unauthenticated Users
      if (firebaseUser == null) {
        if (isAuthRoute || isLanding || isSplash || isOnboarding || isPublicDeck) {
          return null; // Stay on public pages
        }
        return kIsWeb ? '/landing' : '/onboarding';
      }

      // 2. Handle Users Waiting for Firestore Profile
      if (userModel == null) {
        if (isAuthRoute || isLanding || isSplash || isOnboarding) {
          return '/';
        }
        return null;
      }

      // 3. Handle Email Verification for Creators
      if (!userModel.isEmailVerified && userModel.role == UserRole.creator) {
        return null; 
      }

      // 4. Handle Authenticated Users on Public Routes
      if (isAuthRoute || isLanding || isSplash) {
        final redirectParam = state.uri.queryParameters['redirect'];
        if (redirectParam != null && redirectParam.isNotEmpty) {
          return redirectParam;
        }
        if (isPublicDeck) return null;
        return '/';
      }

      return null;
    },
    routes: <RouteBase>[
      // Top-level standalone routes
      GoRoute(
        path: '/landing',
        builder: (context, state) => const PublicScaffoldWeb(
          isEducatorRoute: false,
          child: StudentLandingView(),
        ),
      ),
      GoRoute(
        path: '/Educators',
        builder: (context, state) => const PublicScaffoldWeb(
          isEducatorRoute: true,
          child: CreatorTabView(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) {
          final redirect = state.uri.queryParameters['redirect'];
          return AuthScreen(redirectPath: redirect);
        },
      ),
      GoRoute(
        path: '/s/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug'];
          return PublicDeckScreen(slug: slug);
        },
      ),
      GoRoute(
        path: '/deck',
        builder: (context, state) {
          final deckId = state.uri.queryParameters['id'];
          final code = state.uri.queryParameters['code'];
          return PublicDeckScreen(deckId: deckId, code: code);
        },
      ),

      // Main application shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _reviewShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (context, state) => const RoleAwareView(
                  studentView: ResponsiveView(
                    mobile: ReviewScreen(),
                    desktop: ReviewScreenWeb(),
                  ),
                  creatorView: ResponsiveView(
                    mobile: TeacherDashboardWeb(module: 'dashboard'),
                    desktop: TeacherDashboardWeb(module: 'dashboard'),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _libraryShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/library',
                builder: (context, state) => const RoleAwareView(
                  studentView: ResponsiveView(
                    mobile: LibraryScreen(),
                    desktop: LibraryScreenWeb(),
                  ),
                  creatorView: ResponsiveView(
                    mobile: TeacherDashboardWeb(module: 'content'),
                    desktop: TeacherDashboardWeb(module: 'content'),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'summary/:id',
                    name: 'library-summary',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final summary = state.extra is LocalSummary ? state.extra as LocalSummary : null;
                      final id = state.pathParameters['id'];
                      return SummaryScreen(summary: summary, id: id);
                    },
                  ),
                  GoRoute(
                    path: 'quiz/:id',
                    name: 'library-quiz',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final quiz = state.extra is LocalQuiz ? state.extra as LocalQuiz : null;
                      final id = state.pathParameters['id'];
                      return QuizScreen(quiz: quiz, id: id);
                    },
                  ),
                  GoRoute(
                    path: 'flashcards/:id',
                    name: 'library-flashcards',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final set = state.extra is FlashcardSet ? state.extra as FlashcardSet : null;
                      final id = state.pathParameters['id'];
                      return FlashcardsScreen(flashcardSet: set, id: id);
                    },
                  ),
                  GoRoute(
                    path: 'results-view/:folderId',
                    name: 'results-view',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final folderId = state.pathParameters['folderId'];
                      final tabParam = state.uri.queryParameters['tab'];
                      final initialTab = int.tryParse(tabParam ?? '') ?? 0;
                      return ResponsiveView(
                        mobile: ResultsViewScreen(folderId: folderId!),
                        desktop: ResultsViewScreenWeb(folderId: folderId, initialTab: initialTab),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _createShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/create-content',
                builder: (context, state) => const RoleAwareView(
                  studentView: ResponsiveView(
                    mobile: CreateContentScreen(),
                    desktop: CreateContentScreenWeb(),
                  ),
                  creatorView: ResponsiveView(
                    mobile: CreateContentScreen(),
                    desktop: CreateContentScreenWeb(),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'exam-wizard',
                    builder: (context, state) => const ResponsiveView(
                      mobile: ExamCreationScreen(),
                      desktop: ExamCreationScreenWeb(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _progressShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/progress',
                builder: (context, state) => RoleAwareView(
                  studentView: const ResponsiveView(
                    mobile: ProgressScreen(),
                    desktop: ProgressScreenWeb(),
                  ),
                  creatorView: TeacherDashboardWeb(
                    module: 'analytics',
                    studentId: state.uri.queryParameters['studentId'],
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _studentsShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/students',
                builder: (context, state) => const ResponsiveView(
                  mobile: TeacherDashboardWeb(module: 'students'),
                  desktop: TeacherDashboardWeb(module: 'students'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _feedbackShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/feedback',
                builder: (context, state) => const ResponsiveView(
                  mobile: TeacherDashboardWeb(module: 'feedback'),
                  desktop: TeacherDashboardWeb(module: 'feedback'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                builder: (context, state) => const AccountProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _settingsShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(path: 'preferences', builder: (context, state) => const PreferencesScreen()),
                  GoRoute(path: 'data-storage', builder: (context, state) => const DataStorageScreen()),
                  GoRoute(path: 'privacy-about', builder: (context, state) => const PrivacyAboutScreen()),
                  GoRoute(path: 'subscription', builder: (context, state) => const SubscriptionScreen()),
                  GoRoute(path: 'account-profile', builder: (context, state) => const AccountProfileScreen()),
                  GoRoute(path: 'referral', builder: (context, state) => const ReferralScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/deck',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? state.uri.queryParameters['code'];
          if (id == null) return const Scaffold(body: Center(child: Text('Invalid Deck Link')));
          return PublicDeckScreen(deckId: id);
        },
      ),
      GoRoute(
        path: '/creator_dashboard',
        builder: (context, state) => const TeacherDashboardScreen(),
      ),
      GoRoute(
        path: '/exam-creation',
        builder: (context, state) => const ResponsiveView(
          mobile: ExamCreationScreen(),
          desktop: ExamCreationScreenWeb(),
        ),
      ),
    ],
  );
}

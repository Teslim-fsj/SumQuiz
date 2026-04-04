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
import 'package:sumquiz/views/screens/edit_creator_profile_screen.dart';
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
import 'package:sumquiz/views/screens/web/landing_page_web.dart';
import 'package:sumquiz/views/screens/exam_creation_screen.dart';
import 'package:sumquiz/views/screens/web/review_screen_web.dart';
import 'package:sumquiz/views/screens/public_deck_screen.dart';
import 'package:sumquiz/views/screens/web/exam_creation_screen_web.dart';

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

final _rootNavigatorKey = GlobalKey<NavigatorState>();

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
    navigatorKey: _rootNavigatorKey,
    refreshListenable: GoRouterRefreshStream(authStream),
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation == '/auth';
      final isLanding = state.matchedLocation == '/landing' ||
          state.matchedLocation == '/Educators';
      final isSplash = state.matchedLocation == '/splash';
      final isOnboarding = state.matchedLocation == '/onboarding';

      final userModel = Provider.of<UserModel?>(context);
      final firebaseUser = authService.currentUser;

      // [FIX] Handle email verification for creators
      if (userModel != null && !userModel.isEmailVerified && userModel.role == UserRole.creator) {
        return null;
      }

      if (isSplash || isOnboarding) {
        return null;
      }

      // [PHASE 1] Handle Unauthenticated Users
      if (firebaseUser == null) {
        if (isAuthRoute || isLanding || isSplash || isOnboarding) {
          return null;
        }
        // Platform-specific default landing
        return kIsWeb ? '/landing' : '/onboarding';
      }

      // [PHASE 1] Handle Authenticated Users with missing Firestore Profile
      // If we have a Firebase User but no UserModel yet, don't redirect to landing.
      // This prevents the sign-in loop where users are stuck on the landing page after login.
      if (userModel == null) {
        if (isAuthRoute || isLanding || isSplash || isOnboarding) {
          // Allow progress to main shell so dashboard can show loading state
          return '/';
        }
        return null; // Stay where you are while loading
      }

      // [PHASE 2] Handle fully authenticated users on landing/auth routes
      if (isAuthRoute || isLanding || isSplash || isOnboarding) {
        return '/';
      }

      return null;
    },
    routes: <RouteBase>[
      // Top-level standalone routes (no nav bar)
      GoRoute(
        path: '/landing',
        builder: (context, state) => const LandingPageWeb(),
      ),
      GoRoute(
        path: '/Educators',
        builder: (context, state) => const LandingPageWeb(initialTab: 1),
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
        builder: (context, state) => const AuthScreen(),
      ),

      // Main application shell with navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          // Branch 0: Home/Dashboard
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
                    mobile: TeacherDashboardScreen(),
                    desktop: TeacherDashboardWeb(module: 'dashboard'),
                  ),
                ),
                routes: [],
              ),
            ],
          ),

          // Branch 1: Library/Content Manager
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
                    mobile: ExamCreationScreen(),
                    desktop: TeacherDashboardWeb(module: 'content'),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'summary/:id',
                    name: 'library-summary',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      try {
                        final summary = state.extra is LocalSummary
                            ? state.extra as LocalSummary?
                            : null;
                        final id = state.pathParameters['id'];
                        return SummaryScreen(summary: summary, id: id);
                      } catch (e) {
                        debugPrint('Error in summary route: $e');
                        return Scaffold(
                          appBar: AppBar(title: Text('Error')),
                          body: Center(
                              child: Text(
                                  'Failed to load summary. Please try again.')),
                        );
                      }
                    },
                  ),
                  GoRoute(
                    path: 'quiz/:id',
                    name: 'library-quiz',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      try {
                        final quiz = state.extra is LocalQuiz
                            ? state.extra as LocalQuiz?
                            : null;
                        final id = state.pathParameters['id'];
                        return QuizScreen(quiz: quiz, id: id);
                      } catch (e) {
                        debugPrint('Error in quiz route: $e');
                        return Scaffold(
                          appBar: AppBar(title: Text('Error')),
                          body: Center(
                              child: Text(
                                  'Failed to load quiz. Please try again.')),
                        );
                      }
                    },
                  ),
                  GoRoute(
                    path: 'flashcards/:id',
                    name: 'library-flashcards',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      try {
                        final set = state.extra is FlashcardSet
                            ? state.extra as FlashcardSet?
                            : null;
                        final id = state.pathParameters['id'];
                        return FlashcardsScreen(flashcardSet: set, id: id);
                      } catch (e) {
                        debugPrint('Error in flashcards route: $e');
                        return Scaffold(
                          appBar: AppBar(title: Text('Error')),
                          body: Center(
                              child: Text(
                                  'Failed to load flashcards. Please try again.')),
                        );
                      }
                    },
                  ),
                  GoRoute(
                    path: 'results-view/:folderId',
                    name: 'results-view',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      try {
                        final folderId = state.pathParameters['folderId'];
                        final tabParam = state.uri.queryParameters['tab'];
                        final initialTab = int.tryParse(tabParam ?? '') ?? 0;

                        if (folderId == null || folderId.isEmpty) {
                          debugPrint('Missing folderId in results-view route');
                          return Scaffold(
                            appBar: AppBar(title: Text('Error')),
                            body: Center(
                                child: Text(
                                    'Missing content identifier. Please try again.')),
                          );
                        }
                        return ResponsiveView(
                          mobile: ResultsViewScreen(folderId: folderId),
                          desktop: ResultsViewScreenWeb(
                              folderId: folderId, initialTab: initialTab),
                        );
                      } catch (e) {
                        debugPrint('Error in results-view route: $e');
                        return Scaffold(
                          appBar: AppBar(title: Text('Error')),
                          body: Center(
                              child: Text(
                                  'Failed to load results. Please try again.')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),

          // Branch 2: Create (Shared)
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
                    mobile: ExamCreationScreen(),
                    desktop: ExamCreationScreenWeb(),
                  ),
                ),
              ),
            ],
          ),

          // Branch 3: Progress/Analytics
          StatefulShellBranch(
            navigatorKey: _progressShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/progress',
                builder: (context, state) => const RoleAwareView(
                  studentView: ResponsiveView(
                    mobile: ProgressScreen(),
                    desktop: ProgressScreenWeb(),
                  ),
                  creatorView: ResponsiveView(
                    mobile: TeacherDashboardScreen(),
                    desktop: TeacherDashboardWeb(module: 'analytics'),
                  ),
                ),
                routes: [],
              ),
            ],
          ),

          // Branch 4: Students (Teacher Only)
          StatefulShellBranch(
            navigatorKey: _studentsShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/students',
                builder: (context, state) =>
                    const TeacherDashboardWeb(module: 'students'),
              ),
            ],
          ),

          // Branch 5: AI Insights (Teacher Only)
          StatefulShellBranch(
            navigatorKey: _feedbackShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/feedback',
                builder: (context, state) =>
                    const TeacherDashboardWeb(module: 'feedback'),
              ),
            ],
          ),

          // Branch 6: Profile (Shared)
          StatefulShellBranch(
            navigatorKey: _profileShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/edit_profile',
                builder: (context, state) => const EditTeacherProfileScreen(),
              ),
            ],
          ),

          // Branch 7: Settings (Shared)
          StatefulShellBranch(
            navigatorKey: _settingsShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'preferences',
                    builder: (context, state) => const PreferencesScreen(),
                  ),
                  GoRoute(
                    path: 'data-storage',
                    builder: (context, state) => const DataStorageScreen(),
                  ),
                  GoRoute(
                    path: 'privacy-about',
                    builder: (context, state) => const PrivacyAboutScreen(),
                  ),
                  GoRoute(
                    path: 'subscription',
                    builder: (context, state) => const SubscriptionScreen(),
                  ),
                  GoRoute(
                    path: 'account-profile',
                    builder: (context, state) => const AccountProfileScreen(),
                  ),
                  GoRoute(
                    path: 'referral',
                    builder: (context, state) => const ReferralScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Standalone routes outside shell
      GoRoute(
        path: '/deck',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          if (id == null) {
            return const Scaffold(
                body: Center(child: Text('Invalid Deck Link')));
          }
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

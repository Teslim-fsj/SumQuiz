# SumQuiz — Comprehensive Technical Documentation

**Version:** 1.1.21+31 | **Last Updated:** March 2026 | **AI Engine:** Gemini 3.1

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [Project File Structure](#3-project-file-structure)
4. [Data Models](#4-data-models)
5. [Navigation & Routing](#5-navigation--routing)
6. [AI Pipeline](#6-ai-pipeline)
7. [Services Reference](#7-services-reference)
8. [UI Screens Reference](#8-ui-screens-reference)
9. [State Management & Providers](#9-state-management--providers)
10. [Firebase & Database Layer](#10-firebase--database-layer)
11. [Subscription & Payment System](#11-subscription--payment-system)
12. [Gamification & Engagement](#12-gamification--engagement)
13. [Offline-First Architecture](#13-offline-first-architecture)
14. [Notifications System](#14-notifications-system)
15. [Asset & Theme Configuration](#15-asset--theme-configuration)
16. [Environment & Secrets](#16-environment--secrets)
17. [Dependencies Reference](#17-dependencies-reference)
18. [Development Setup Guide](#18-development-setup-guide)

---

## 1. Project Overview

SumQuiz is a cross-platform Flutter application (Android, iOS, Web, Desktop) that transforms any educational content into structured study materials using Google's **Gemini 3.1** AI series. Users can upload PDFs, paste text, provide URLs, or enter YouTube links to instantly generate:

- 📝 **AI Summaries** – Concise, exam-focused notes
- ❓ **Quizzes** – Multiple-choice question sets with instant feedback
- 🃏 **Flashcard Decks** – Smart Q&A cards integrated with a spaced repetition system

The app features two user tiers: **Free** and **Pro**, with a gamification layer (Momentum, Daily Missions, Streaks, Achievements) to maximise user engagement.

---

## 2. Architecture Overview

SumQuiz uses a refined **MVVM-Service** architecture implemented in Flutter with the following layers:

```
┌─────────────────────────────────────────────────────────┐
│             PRESENTATION LAYER (UI)                     │
│  views/screens/  |  views/widgets/  |  widgets/         │
│  32 Mobile Screens + 8 Web-Specific Screens             │
└────────────────────────┬────────────────────────────────┘
                         │ Provider / StreamBuilder / FutureBuilder
┌────────────────────────▼────────────────────────────────┐
│              STATE / VIEWMODEL LAYER                    │
│  providers/  |  view_models/  |  viewmodels/            │
└────────────────────────┬────────────────────────────────┘
                         │ Method Calls / Streams
┌────────────────────────▼────────────────────────────────┐
│               BUSINESS LOGIC (SERVICES)                 │
│  services/  (28 service files)                          │
│  AI, Auth, Firestore, IAP, Sync, SRS, Missions, etc.   │
└────────────────────────┬────────────────────────────────┘
                         │
        ┌────────────────┴──────────────────┐
        ▼                                   ▼
┌───────────────┐                ┌──────────────────────┐
│  Local (Hive) │◄──SyncService─►│  Remote (Firestore)  │
│  8 Hive Boxes │                │  Firebase Auth, Cloud │
└───────────────┘                └──────────────────────┘
```

### Key Architectural Decisions

| Decision | Implementation |
|---|---|
| **Navigation** | GoRouter with `StatefulShellRoute` for 4 tab branches |
| **State Management** | Provider (`ChangeNotifierProvider`) |
| **Local Storage** | Hive with typed adapters (code-generated) |
| **Offline-First** | Write-local-then-sync strategy via `SyncService` |
| **AI** | `google_generative_ai` SDK + Gemini 3.1 series |
| **Responsive** | `ResponsiveView` widget for Mobile/Desktop split |

---

## 3. Project File Structure

```
lib/
├── main.dart                          # App entry point, Provider setup
├── firebase_options.dart              # Auto-generated Firebase config
│
├── models/                            # Dart data models (28 files)
│   ├── user_model.dart                # UserModel with full freemium logic
│   ├── summary_model.dart             # Summary data (Firestore)
│   ├── quiz_model.dart                # Quiz with questions (Firestore)
│   ├── flashcard_set.dart             # FlashcardSet (Firestore)
│   ├── flashcard.dart                 # Individual flashcard
│   ├── quiz_question.dart             # Quiz question with options
│   ├── library_item.dart              # Unified UI item for Library
│   ├── public_deck.dart               # Creator-published deck
│   ├── editable_content.dart          # Generic editing model for router
│   ├── extraction_result.dart         # Result from content extraction
│   ├── spaced_repetition.dart         # SRS item (Hive stored)
│   ├── daily_mission.dart             # Daily mission (Hive stored)
│   ├── folder.dart                    # User folder (Hive stored)
│   ├── content_folder.dart            # Folder↔Content relation (Hive)
│   ├── local_summary.dart             # LocalSummary for Hive
│   ├── local_quiz.dart                # LocalQuiz for Hive
│   ├── local_flashcard_set.dart       # LocalFlashcardSet for Hive
│   ├── local_flashcard.dart           # LocalFlashcard for Hive
│   ├── local_quiz_question.dart       # LocalQuizQuestion for Hive
│   └── *.g.dart                       # Hive-generated TypeAdapters
│
├── providers/                         # Provider state classes
│   ├── subscription_provider.dart     # Subscription state listener
│   └── sync_provider.dart             # SyncService wrapper
│
├── router/
│   └── app_router.dart                # Full GoRouter configuration
│
├── services/                          # All business logic (28 files)
│   ├── auth_service.dart              # Auth: Google, Email, Referral, Sync
│   ├── firestore_service.dart         # All CRUD + Creator features
│   ├── iap_service.dart               # Play/App Store IAP
│   ├── web_payment_service.dart       # Flutterwave web payments
│   ├── enhanced_ai_service.dart       # AI orchestration service
│   ├── content_extraction_service.dart # PDF/Image text extraction (OCR)
│   ├── local_database_service.dart    # Hive singleton service
│   ├── sync_service.dart              # Offline ↔ Cloud bidirectional sync
│   ├── spaced_repetition_service.dart # SM-2 SRS algorithm
│   ├── mission_service.dart           # Daily missions & momentum
│   ├── referral_service.dart          # ACID referral system
│   ├── usage_service.dart             # Freemium usage tracking
│   ├── progress_service.dart          # Learning progress tracking
│   ├── notification_service.dart      # Local notification scheduling
│   ├── notification_manager.dart      # Notification type manager
│   ├── notification_integration.dart  # Notification trigger points
│   ├── export_service.dart            # Content export (share/copy)
│   ├── pdf_export_service.dart        # Generate PDF from content
│   ├── word_export_service.dart       # Generate .docx from content
│   ├── sharing_service.dart           # Share via share_plus
│   ├── user_service.dart              # User utility ops (weekly reset)
│   ├── upgrade_service.dart           # Upgrade prompt logic
│   ├── error_reporting_service.dart   # Error logging/reporting
│   ├── time_sync_service.dart         # Server time sync
│   ├── extraction_result_cache.dart   # In-memory cache for router nav
│   └── ai/                            # AI sub-services (9 files)
│       ├── ai_config.dart             # All model names, limits, prompts
│       ├── ai_base_service.dart       # Base class for AI services
│       ├── generator_ai_service.dart  # Quiz/Summary/Flashcard generation
│       ├── youtube_ai_service.dart    # YouTube extraction
│       ├── web_ai_service.dart        # Web page extraction
│       └── ai_types.dart              # Shared types & exceptions
│
├── view_models/                        # ViewModels for screens
│   ├── library_view_model.dart
│   ├── quiz_view_model.dart
│   └── referral_view_model.dart
│
├── views/
│   ├── screens/                        # 32 mobile screens
│   │   ├── splash_screen.dart
│   │   ├── onboarding_screen.dart
│   │   ├── auth_screen.dart
│   │   ├── create_content_screen.dart  # Main creation hub (70KB!)
│   │   ├── extraction_view_screen.dart # Processing status
│   │   ├── results_view_screen.dart    # Post-generation results
│   │   ├── review_screen.dart          # Home tab: daily review
│   │   ├── library_screen.dart         # Library tab
│   │   ├── progress_screen.dart        # Progress tab
│   │   ├── summary_screen.dart         # Full summary viewer
│   │   ├── quiz_screen.dart            # Interactive quiz
│   │   ├── flashcards_screen.dart      # Flashcard viewer + SRS
│   │   ├── spaced_repetition_screen.dart # SRS session screen
│   │   ├── exam_creation_screen.dart   # Full exam builder (62KB)
│   │   ├── subscription_screen.dart    # Paywall + plans
│   │   ├── referral_screen.dart        # Referral program UI
│   │   ├── settings_screen.dart        # Settings hub
│   │   ├── preferences_screen.dart     # App preferences
│   │   ├── data_storage_screen.dart    # Offline storage mgmt
│   │   ├── account_profile_screen.dart
│   │   ├── creator_dashboard_screen.dart # Creator tools
│   │   ├── public_deck_screen.dart     # Shared deck deep link
│   │   ├── edit_*.dart                 # Edit screens for all types
│   │   ├── privacy_about_screen.dart
│   │   └── web/                        # 8 web-specific screens
│   └── widgets/                        # Reusable widgets
│
├── widgets/                            # Gamification widgets
│   ├── achievements_tracker.dart
│   ├── activity_chart.dart
│   ├── daily_goal_tracker.dart
│   ├── goal_setting_dialog.dart
│   ├── personalized_insights.dart
│   └── pro_gate.dart                  # Pro-access gating widget
│
├── theme/
│   └── app_theme.dart
│
└── utils/
    ├── logger.dart
    └── cancellation_token.dart         # For cancelling AI requests
```

---

## 4. Data Models

### UserModel (`lib/models/user_model.dart`)

The central user document. Contains identity, subscription status, gamification tracking, and Creator features.

```
UserModel {
  uid: String                     // Firebase Auth UID
  email, displayName: String
  role: UserRole                  // student | creator
  
  // Subscription
  subscriptionExpiry: DateTime?   // null = no sub
  currentProduct: String?         // IAP product ID
  subscriptionType: String?       // 'monthly' | 'yearly' | 'lifetime'
  isTrial: bool                   // Is currently on trial?
  isCreatorPro: bool              // Permanent Pro via Creator Program

  // Computed Pro status
  bool get isPro: CreatorPro || Active Subscription
  bool get isTrial: _isTrialUser && active subscription

  // Gamification (Pro only for rewards)
  currentMomentum: double         // 0–1000
  momentumDecayRate: double       // Default 5%/day 
  dailyGoal: int                  // Target items to complete
  missionCompletionStreak: int    // Consecutive mission streak
  difficultyPreference: int       // 1-5 for adaptive missions

  // Freemium Limits (Free Tier)
  weeklyUploads: int
  folderCount: int
  srsCardCount: int

  // Referral
  referralCode: String?           // User's shareable code

  // Creator Tools
  creatorProfile: Map<String, dynamic>
}
```

### Content Models

| Model | Firestore Path | Key Fields |
|---|---|---|
| `Summary` | `users/{uid}/summaries/{id}` | `title`, `content`, `tags`, `timestamp` |
| `Quiz` | `users/{uid}/quizzes/{id}` | `title`, `questions: List<QuizQuestion>`, `timestamp` |
| `FlashcardSet` | `users/{uid}/flashcard_sets/{id}` | `title`, `flashcards: List<Flashcard>`, `timestamp` |
| `PublicDeck` | `public_decks/{id}` | `creatorId`, `shareCode`, `summaryData`, `quizData`, `flashcardData`, `uniqueViewCount` |

### Local (Hive) Models

Each Cloud model has a corresponding `Local*` model for offline storage with an `isSynced: bool` field for the offline-first sync system.

| Hive Model | Adapter ID | Purpose |
|---|---|---|
| `LocalSummary` | 0 | Offline summary |
| `LocalQuiz` | 1 | Offline quiz |
| `LocalQuizQuestion` | 2 | Offline quiz question |
| `LocalFlashcard` | 3 | Offline flashcard |
| `LocalFlashcardSet` | 4 | Offline flashcard set |
| `Folder` | 5 | User-created folder |
| `ContentFolder` | 6 | Folder-content mapping |
| `SpacedRepetitionItem` | 8 | SRS scheduling data |
| `DailyMission` | 21 | Today's mission |

---

## 5. Navigation & Routing

Managed by **GoRouter** (`lib/router/app_router.dart`) with auth-aware redirects and platform-specific initial routes.

### Initial Route Logic

```
Mobile          → /splash → /onboarding → /auth → /
Web / Desktop   → /landing → /auth → /
```

### Auth Redirect Guard

- **Unauthenticated user** accessing protected routes → redirected to `/landing`
- **Authenticated user** accessing `/auth` or `/landing` → redirected to `/`

### Route Map

```
/landing             → LandingPageWeb
/splash              → SplashScreen
/onboarding          → OnboardingScreen
/auth                → AuthScreen
/settings            → SettingsScreen
  /settings/preferences      → PreferencesScreen
  /settings/data-storage     → DataStorageScreen
  /settings/privacy-about    → PrivacyAboutScreen
  /settings/subscription     → SubscriptionScreen
  /settings/account-profile  → AccountProfileScreen
  /settings/referral         → ReferralScreen

/deck?id=            → PublicDeckScreen (deep link)
/edit_profile        → EditCreatorProfileScreen
/creator_dashboard   → CreatorDashboardScreen
/exam-creation       → ExamCreationScreen

── Shell Route (Tab Nav) ──────────────────────────
  / (Tab 1: Review)    → ReviewScreen / ReviewScreenWeb
  /library (Tab 2)     → LibraryScreen / LibraryScreenWeb
    /library/summary   → SummaryScreen
    /library/quiz      → QuizScreen
    /library/flashcards → FlashcardsScreen
    /library/results-view/:folderId → ResultsViewScreen
  /create (Tab 3)      → CreateContentScreen / CreateContentScreenWeb
    /create/extraction-view → ExtractionViewScreen
    /create/edit-content    → Edit[Quiz|Flashcards|Summary]Screen
  /progress (Tab 4)    → ProgressScreen / ProgressScreenWeb
```

---

## 6. AI Pipeline

### Model Configuration (`lib/services/ai/ai_config.dart`)

| Constant | Value | Purpose |
|---|---|---|
| `primaryModel` | `gemini-3.1-flash-lite-preview` | Fast generation |
| `proModel` | `gemini-3.1-pro-preview` | Deep reasoning |
| `fallbackModel` | `gemini-2.5-flash` | Fallback if 3.1 unavailable |
| `visionModel` | `gemini-3.1-pro-preview` | Image/visual tasks |
| `youtubeModel` | `gemini-3.1-pro-preview` | YouTube analysis |
| `maxInputLength` | `1,000,000` chars | Full document analysis |
| `maxOutputTokens` | `32,768` | Long-form output |
| `temperature` | `0.3` (default) | Low for factual accuracy |

### System Instructions

Two native `systemInstruction` roles are defined in `AIConfig`:

- **Educator** (`educatorSystemInstruction`): "Expert academic educator" – used for generation tasks.
- **Extractor** (`extractorSystemInstruction`): "Precise content extraction specialist" – used for cleaning raw PDF/web text.

### Generation Config Profiles

| Profile | Temp | Output Tokens | MIME | Used For |
|---|---|---|---|---|
| `defaultGenerationConfig` | 0.3 | 8,192 | `application/json` | Quizzes, Flashcards |
| `extractionGenerationConfig` | 0.1 | 32,768 | `text/plain` | Raw text extraction |
| `proGenerationConfig` | 0.3 | 65,536 | `application/json` | Pro deep generation |

### The AI Orchestration Flow

```
User submits content (PDF/URL/YouTube/Text)
         │
         ▼
CreateContentScreen detects type
         │
         ├─ PDF → ContentExtractionService (SyncFusion PDF + ML Kit OCR)
         │             → Sends text to GeneratorAIService
         │
         ├─ Web URL → WebAIService (fetches + cleans HTML)
         │             → Sends cleaned text to GeneratorAIService
         │
         ├─ YouTube → YouTubeAIService
         │   ├─ Short (<15min) → Mode A: Multimodal (video bytes directly to Gemini Pro)
         │   └─ Long (>15min) → Mode C: youtube_explode_dart transcript + Gemini Flash
         │
         └─ Raw Text → Directly to GeneratorAIService
                    │
                    ▼
            GeneratorAIService
            - Validates JSON via responseSchema
            - Sends to gemini-3.1-flash-lite-preview (primary)
            - Falls back to gemini-2.5-flash if needed
            - Returns: ExtractionResult { summary, quiz, flashcardSet }
                    │
                    ▼
            ExtractionResultCache.store(result)
                    │
                    ▼
            Router navigates to /create/extraction-view
                    │
                    ▼
            ExtractionViewScreen displays AI progress/result
```

### Retry & Timeout Policy

- **Max Retries:** 5 with exponential backoff (1s → 60s max)
- **Master Timeout:** 300 seconds (5 minutes) for the full pipeline
- **YouTube Timeout:** 180 seconds
- **Transcript Timeout:** 45 seconds

---

## 7. Services Reference

### AuthService (`auth_service.dart`)

Handles all authentication flows with post-auth side effects.

| Method | Description |
|---|---|
| `signInWithGoogle(context, referralCode?)` | Google OAuth, creates UserModel, triggers sync, applies referral, schedules notifications |
| `signUpWithEmailAndPassword(...)` | Email sign-up, validates referral code pre-check, creates UserModel, sends verification email |
| `signInWithEmailAndPassword(...)` | Login, saves auth state to SharedPreferences, triggers sync |
| `signOut()` | Signs out Google + Firebase, clears SharedPreferences |
| `sendPasswordResetEmail(email)` | Delegates to Cloud Function with rate limiting |
| `restoreAuthState()` | Checks SharedPreferences for offline auth-state recovery |
| `Stream<UserModel?> get user` | Reactive stream combining Auth state + Firestore user doc |

---

### FirestoreService (`firestore_service.dart`)

All Firestore CRUD operations with automatic dual-write (Hive + Firestore) on writes.

**User:**
- `streamUser(uid)` → `Stream<UserModel?>`
- `saveUserData(user)` – Upsert with `merge: true`
- `updateUserRole(uid, role)` – Set student/creator role

**Content (each type has stream/add/update/delete):**
- `streamSummaries/Quizzes/FlashcardSets(uid)` → Ordered streams
- `streamAllItems(uid)` → Combined stream via `rxdart.CombineLatestStream`
- `addSummary/Quiz/FlashcardSet(...)` – Writes locally first, then Firestore
- `deleteSummary/Quiz/FlashcardSet(...)` – Deletes from both stores

**Creator Features:**
- `publishDeck(deck)` → ID-assigned `public_decks` doc
- `fetchPublicDeckByCode(code)` → Case-insensitive share code lookup
- `recordDeckView(deckId, viewerId)` → Firestore transaction: unique view count; auto-grants Creator Pro at 3 views
- `incrementDeckMetric(deckId, metric)` → Increments `startedCount` / `completedCount`

---

### IAPService (`iap_service.dart`)

Play Store / App Store in-app purchase management.

**Product IDs:**

| ID | Duration |
|---|---|
| `sumquiz_pro_weekly` | 7 days |
| `sumquiz_pro_monthly` | 30 days |
| `sumquiz_pro_yearly` | 365 days |

**Free Tier Hard Limits:**

| Resource | Limit |
|---|---|
| Total Uploads (Lifetime) | 1 |
| Max Folders | 2 |
| Max SRS Cards | 50 |

**Key Methods:**
- `initialize()` – Starts purchase stream listener, web is a no-op
- `purchaseProduct(productId)` – Triggers native IAP flow
- `hasProAccess()` – Reads Firestore, uses `UserModel.isPro` computed getter
- `isProStream(uid)` → `Stream<bool>` – Reactive Pro status for UI
- `restorePurchases()` – iOS: native restore; Android: custom logic

---

### WebPaymentService (`web_payment_service.dart`)

Flutterwave-based payments for Web platform.

**Available Products (Web):**

| Product | Price | Duration |
|---|---|---|
| Daily Pass | $0.99 | 1 day |
| Weekly Pass | $4.99 | 7 days |
| Pro Monthly | $14.99 | 30 days |
| Pro Yearly | $99.00 | 365 days |
| Pro Lifetime | $249.99 | Permanent |

- Payment links launch via `url_launcher` (externally hosted Flutterwave payment pages)
- API key loaded from `.env` (`FLUTTERWAVE_PUBLIC_KEY`)

---

### ReferralService (`referral_service.dart`)

Production-grade referral system built on Firestore transactions (ACID compliant).

**Referral Flow:**
1. New user enters a referral code at signup
2. `applyReferralCode(code, newUserId)` runs a single Firestore transaction:
   - ✅ Prevents self-referral
   - ✅ Idempotency check (blocks duplicate referral application)
   - ✅ New user gets +7 days Pro trial
   - ✅ Referrer's `referrals` counter incremented
3. On new user's **first deck generation**, `grantReferrerReward()` is called:
   - Referrer gets +7 days added to `subscriptionExpiry`
   - Capped at 20 referral rewards total
4. Push notification sent to referrer on reward

**Code Format:** 8-character UUID snippet (uppercase), collision-resistant with 10-attempt uniqueness check.

---

### SpacedRepetitionService (`spaced_repetition_service.dart`)

Implements the **SM-2 (SuperMemo 2)** algorithm for intelligent flashcard scheduling.

**SM-2 Update Logic:**
- ✅ Correct answer: increase `interval` × `easeFactor`, increment `repetitionCount`
- ❌ Wrong answer: reset `interval` to 1, reset `repetitionCount` to 0
- `easeFactor` minimum capped at 1.3

**Key Methods:**
- `scheduleReview(flashcardId, userId)` – Schedules card, enforces 50-card Free tier limit
- `updateReview(itemId, answeredCorrectly)` – Updates SM-2 state after review
- `getDueFlashcardIds(userId)` – Returns IDs of cards due for review
- `getStatistics(userId)` – Returns `dueForReviewCount` and `upcomingReviews` schedule for next 7 days
- `getMasteryScore(userId)` – Computes 0–100 mastery via `correctStreak × 10 + easeFactor × 10`

---

### SyncService (`sync_service.dart`)

Bidirectional Hive ↔ Firestore sync with conflict resolution.

- Triggered on login and can be manually triggered via `SyncProvider`
- **Conflict Resolution:** Firestore timestamp wins; cloud data is always authoritative for existing records
- Syncs: Summaries, Quizzes, FlashcardSets
- Gracefully no-ops if offline

---

### MissionService (`mission_service.dart`)

Generates and manages adaptive daily learning missions.

**Mission Generation:**
1. Checks if a mission for today's date already exists in Hive
2. Fetches user's `difficultyPreference` (1-5) from Firestore
3. Selects due SRS flash cards based on difficulty:
   - Level ≤1: 5 cards, ~2 min, +50 momentum
   - Level 3: 10 cards, ~6 min, +100 momentum
   - Level ≥5: 20 cards, ~12 min, +150 momentum
4. Saves to Hive, schedules a priming notification

**Mission Completion (Pro Users Only for Rewards):**
- Applies momentum decay: `newMomentum = currentMomentum × (1 - decayRate)`
- Adds daily gain: `baseReward × difficultyBonus × streakMultiplier × accuracyMultiplier`
  - Streak multiplier: +5% per consecutive mission, capped at 1.5×
  - Accuracy multiplier: score (0–1), minimum 0.5
  - Daily gain capped at 300, total Momentum capped at 1,000

**Free Users:** Mission streaks still tracked, but no Momentum gain.

---

## 8. UI Screens Reference

### Core Creation Flow

| Screen | File | Purpose |
|---|---|---|
| `CreateContentScreen` | `create_content_screen.dart` | Main hub: text input, file upload, URL/YouTube pasting |
| `ExtractionViewScreen` | `extraction_view_screen.dart` | Shows AI processing status + extracted content preview |
| `ResultsViewScreen` | `results_view_screen.dart` | Displays final Summary, Quiz, Flashcards post-generation |

### Study Screens

| Screen | File | Purpose |
|---|---|---|
| `SummaryScreen` | `summary_screen.dart` | Full summary viewer with edit/export/share |
| `QuizScreen` | `quiz_screen.dart` | Interactive quiz with scoring |
| `FlashcardsScreen` | `flashcards_screen.dart` | Swipeable flashcard viewer + SRS scheduling |
| `SpacedRepetitionScreen` | `spaced_repetition_screen.dart` | Dedicated SRS session |
| `ReviewScreen` | `review_screen.dart` | Home tab: daily mission + due review cards |
| `ExamCreationScreen` | `exam_creation_screen.dart` | Full exam builder (62KB, Pro feature) |

### Library & Organisation

| Screen | Purpose |
|---|---|
| `LibraryScreen` | View all saved content (Summaries, Quizzes, Flashcards, Folders) |
| `DataStorageScreen` | Manage local Hive data, view storage per type |
| `Edit[Summary|Quiz|Flashcards]Screen` | Inline editing of any content type |

### Profile & Settings

| Screen | Purpose |
|---|---|
| `SettingsScreen` | Central settings hub |
| `AccountProfileScreen` | User profile, display name, avatar |
| `PreferencesScreen` | Notifications, theme, study time preferences |
| `SubscriptionScreen` | Plans, pricing, purchase flow |
| `ReferralScreen` | User's referral code + stats |
| `PrivacyAboutScreen` | Privacy policy and app info |

### Creator Tools

| Screen | Purpose |
|---|---|
| `CreatorDashboardScreen` | View published decks, view counts, engagement |
| `EditCreatorProfileScreen` | Creator bio, links, name |
| `PublicDeckScreen` | Deep-linked public deck viewer (`/deck?id=`) |

### Web-Specific Screens (`views/screens/web/`)

| Screen | Description |
|---|---|
| `LandingPageWeb` | Marketing landing page for unauthenticated users |
| `CreateContentScreenWeb` | Web-optimised creator |
| `ExtractionViewScreenWeb` | Web extraction view |
| `ResultsViewScreenWeb` | Web results |
| `LibraryScreenWeb` | Web library |
| `ProgressScreenWeb` | Web progress |
| `ReviewScreenWeb` | Web review/home |
| `ReviewScreenWeb` | Web review screen |

---

## 9. State Management & Providers

Registered in `main.dart` using `MultiProvider`:

| Provider | Type | Purpose |
|---|---|---|
| `AuthService` | `Provider` | Firebase Auth wrapper |
| `SubscriptionProvider` | `ChangeNotifierProvider` | Reactive Pro status |
| `SyncProvider` | `ChangeNotifierProvider` | Sync trigger + status |
| `ThemeProvider` | `ChangeNotifierProvider` | Light/Dark theme toggle |

---

## 10. Firebase & Database Layer

### Firestore Schema

```
users/{uid}
  ├── email, displayName, role
  ├── subscriptionExpiry, isTrial, isCreatorPro, currentProduct
  ├── currentMomentum, momentumDecayRate, dailyGoal
  ├── missionCompletionStreak, difficultyPreference
  ├── weeklyUploads, folderCount, srsCardCount
  ├── referralCode, appliedReferralCode, referredBy
  ├── creatorProfile: {}
  ├── summaries/{id}
  │   └── { title, content, tags, timestamp }
  ├── quizzes/{id}
  │   └── { title, questions: [...], timestamp }
  └── flashcard_sets/{id}
      └── { title, flashcards: [...], timestamp }

public_decks/{id}
  ├── creatorId, creatorName, title, description, shareCode
  ├── summaryData, quizData, flashcardData
  ├── publishedAt, uniqueViewCount, startedCount, completedCount
  └── views/{viewerId}
      └── { viewerId, timestamp }
```

### Firebase Services Used

| Service | SDK Package | Purpose |
|---|---|---|
| Firebase Auth | `firebase_auth` | User authentication |
| Cloud Firestore | `cloud_firestore` | Primary cloud database |
| Firebase App Check | `firebase_app_check` | API abuse protection |
| Firebase Messaging | `firebase_messaging` | Push notifications |
| Firebase Crashlytics | `firebase_crashlytics` | Production error tracking |
| Cloud Functions | `cloud_functions` | Rate-limited password reset |

### Local Hive Database

Singleton `LocalDatabaseService` manages 8 Hive boxes. All adapters are code-generated (`*.g.dart` files).

---

## 11. Subscription & Payment System

### Tier Comparison

| Feature | Free | Pro |
|---|---|---|
| Total Uploads (Lifetime) | 1 | Unlimited |
| Max Folders | 2 | Unlimited |
| SRS Cards | 50 | Unlimited |
| Daily Gen Limit | Yes | No |
| Momentum & Missions | Track only | Full rewards |
| Exam Creation | ❌ | ✅ |
| Export (PDF/Word) | ❌ | ✅ |

### Payment Channels

**Mobile (Android/iOS):**
- IAP via `in_app_purchase`
- Products: Weekly ($X), Monthly ($X), Yearly ($X) — IDs: `sumquiz_pro_weekly/monthly/yearly`

**Web:**
- Flutterwave static payment links
- Products: Daily Pass, Weekly Pass, Monthly ($14.99), Yearly ($99), Lifetime ($249.99)
- Manual webhook flow: User pays → Admin confirms → Updates Firestore `subscriptionExpiry`

### Pro Status Resolution Priority

```
1. isCreatorPro == true → ALWAYS Pro (permanent)
2. subscriptionExpiry != null && isAfter(now) → Pro (active sub)
3. else → Free tier
```

Creator Pro is granted automatically when 3 unique users view a creator's published deck.

---

## 12. Gamification & Engagement

### Momentum System

- **Value Range:** 0 – 1,000
- **Daily Decay:** 5% automatic decay on each session
- **Gain:** Completing daily missions, adjusted by difficulty, streak, and accuracy
- **Pro Only:** Free users complete missions without Momentum gain

### Daily Missions

- Generated once per day, persisted in Hive
- Adaptive card count based on `difficultyPreference` (1–5)
- Mission ID format: `mission_YYYY-MM-DD`
- Contains SRS due cards selected for the day

### Creator Program

- Upload a quality deck and publish it
- 3 unique viewer views → **Creator Pro** badge + permanent Pro access
- Track views, started counts, completion rates via `CreatorDashboardScreen`

### SRS Mastery Score

- Score 0–100 computed per user from all their SRS items
- Formula: `(correctStreak × 10 + easeFactor × 10)` averaged across all cards, capped at 100

---

## 13. Offline-First Architecture

```
User Action (create/edit content)
    │
    ▼
1. Write to Hive immediately (fast, always works)
    │
    ▼
2. Attempt Firestore write
    │
    ├─ Success → Mark Hive item as isSynced=true
    └─ Failure → Leave isSynced=false (no user error shown)
    │
    ▼
3. On next login or manual trigger (SyncProvider):
   SyncService.syncAllData() runs for summaries, quizzes, flashcard sets
    │
    ├─ Local unsynced items → pushed to Firestore
    └─ Firestore items missing locally → pulled to Hive
```

Conflict resolution: Firestore timestamp wins for items that exist in both stores.

---

## 14. Notifications System

Three-layer notification system working together:

| Layer | File | Role |
|---|---|---|
| `NotificationService` | Raw scheduling | Schedules typed local notifications |
| `NotificationManager` | Semantic wrapper | Schedules named notification types |
| `NotificationIntegration` | App events | Called at key lifecycle points |

**Notification Types (scheduled at appropriate moments):**
- **Priming Notification** – 30 min before user's preferred study time
- **Recall Notification** – 20h after mission completion (to reinforce learning)
- **Streak Saver** – Alerts before streak break (cancelled on mission completion)
- **Referral Reward** – Notifies referrer when they earn a reward

---

## 15. Asset & Theme Configuration

### Fonts

| Family | Files | Usage |
|---|---|---|
| Poppins | Regular + Bold | Primary font |
| Inter | Regular + Bold | Secondary font |

### Assets

```
assets/
├── images/
│   ├── sumquiz_logo.png    # App icon source
│   └── web/                # Web-specific images
├── icons/                  # Custom icons
├── fonts/                  # .ttf font files
└── notification_templates.json  # Premium notification data
```

### Launcher Icons & Splash

- `flutter_launcher_icons` → Generates Android/iOS icons from `sumquiz_logo.png`
- `flutter_native_splash` → White splash screen with logo on Android 12+

---

## 16. Environment & Secrets

Managed via `.env` file (loaded by `flutter_dotenv`). The `.env` file is bundled as a Flutter asset.

| Variable | Purpose |
|---|---|
| `FLUTTERWAVE_PUBLIC_KEY` | Web payment key (starts with `FLWPUBK-`) |
| `GEMINI_API_KEY` | (Hardcoded in AIBaseService, should move to .env) |

The `.env` file is listed in `pubspec.yaml` under `flutter.assets` and is loaded at app startup in `main.dart`.

> ⚠️ **Security Note:** The Gemini API key is currently hardcoded in `AIBaseService`. This should be migrated to environment variable or a server-side proxy for production.

---

## 17. Dependencies Reference

### Core Firebase & AI

| Package | Version | Purpose |
|---|---|---|
| `firebase_core` | ^4.3.0 | Firebase init |
| `firebase_auth` | ^6.1.1 | Authentication |
| `cloud_firestore` | ^6.0.3 | Database |
| `firebase_messaging` | ^16.0.3 | Push notifications |
| `firebase_crashlytics` | 5.0.6 | Error tracking |
| `firebase_app_check` | ^0.4.1+3 | API protection |
| `google_generative_ai` | ^0.4.7 | Gemini AI |
| `cloud_functions` | ^6.0.3 | Cloud Functions |

### UI & Navigation

| Package | Purpose |
|---|---|
| `go_router` ^16.2.5 | Declarative routing |
| `provider` ^6.1.2 | State management |
| `google_fonts` ^6.3.3 | Typography |
| `flutter_animate` ^4.5.2 | Animations |
| `flutter_staggered_animations` | List animations |
| `flutter_card_swiper` | Flashcard swipe UI |
| `flip_card` | Flashcard flip animation |
| `confetti` | Celebration effects |
| `shimmer` | Loading shimmer |
| `fl_chart` | Progress charts |
| `percent_indicator` | Circular progress |
| `flutter_quill` | Rich text editor |
| `flutter_markdown` | Markdown rendering |
| `flutter_speed_dial` | FAB dialogs |

### Data & Storage

| Package | Purpose |
|---|---|
| `hive` / `hive_flutter` | Local NoSQL database |
| `shared_preferences` | Simple key-value store |
| `rxdart` | Reactive streams (`CombineLatestStream`) |

### Content Processing

| Package | Purpose |
|---|---|
| `syncfusion_flutter_pdf` | PDF text extraction |
| `google_mlkit_text_recognition` | On-device OCR (free) |
| `image_picker` | Camera/Gallery image input |
| `file_picker` | File system PDF picker |
| `youtube_explode_dart` | YouTube transcript extraction |
| `html` | HTML parsing for web extraction |

### Networking & Payments

| Package | Purpose |
|---|---|
| `http` ^1.6.0 | HTTP for REST calls |
| `url_launcher` | Launch Flutterwave payment links |
| `in_app_purchase` ^3.2.0 | iOS/Android IAP |
| `flutterwave_standard` | (Legacy/alternate Flutterwave SDK) |
| `connectivity_plus` | Network status monitoring |

### Utilities

| Package | Purpose |
|---|---|
| `uuid` | UUID generation for referral codes |
| `intl` | Internationalization |
| `share_plus` | Share content externally |
| `package_info_plus` | App version info |
| `pdf` / `printing` | PDF generation & print |
| `flutter_dotenv` | `.env` file loading |
| `timezone` | Timezone for notification scheduling |
| `flutter_timezone` | Device timezone |

### Dev Dependencies

| Package | Purpose |
|---|---|
| `hive_generator` | Generates Hive TypeAdapters |
| `build_runner` | Code generation runner |
| `flutter_launcher_icons` | App icon generation |
| `flutter_native_splash` | Splash screen generation |
| `mockito` | Unit test mocking |

---

## 18. Development Setup Guide

### Prerequisites

- Flutter SDK `>=3.5.0-18.0.dev <4.0.0`
- Dart SDK `<=4.0.0`
- Firebase project (Auth + Firestore enabled)
- Google AI Studio API Key
- Flutterwave account (for web payments)

### Setup Steps

```bash
# 1. Clone the repository
git clone https://github.com/Teslim-fsj/SumQuiz.git
cd SumQuiz

# 2. Install dependencies
flutter pub get

# 3. Generate Hive adapters
dart run build_runner build --delete-conflicting-outputs

# 4. Configure Firebase
# Copy your google-services.json to android/app/
# Copy your GoogleService-Info.plist to ios/Runner/
# Run: flutterfire configure

# 5. Configure environment
# Create .env file in project root:
echo "FLUTTERWAVE_PUBLIC_KEY=FLWPUBK-XXXXXXXX" > .env

# 6. Generate app icons and splash
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# 7. Run
flutter run -d chrome    # Web
flutter run              # Android/iOS
```

### Firestore Security Rules

Security rules are stored in `firestore.rules`. Ensure they are deployed:
```bash
firebase deploy --only firestore:rules
```

### Environment Configuration

The `android/app/build.gradle.kts` contains signing configuration. Production signing key is stored in `upload-key.jks` (not committed to source control; `key.properties` holds the path + credentials).

---

*Documentation generated from full codebase inspection — March 7, 2026.*
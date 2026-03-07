# SumQuiz Technical Documentation (2026 Edition)

SumQuiz is a state-of-the-art educational platform built with Flutter, designed to transform any content (PDFs, Webpages, YouTube, Raw Text) into high-quality study materials using the Gemini 3.1 AI series.

---

## 🏗️ Architecture Overview

The application follows a refined **MVVM-Service** architecture, prioritizing separation of concerns and offline-first reliability.

### 🧩 Core Modules
1.  **Presentation Layer**: Built using **Material 3**, with dedicated views for high-performance Mobile and Glassmorphic Web interfaces.
2.  **Navigation**: Managed by **GoRouter**, providing declarative routing and deep-linking support.
3.  **State Management**: Orchestrated via **Provider** for clean dependency injection and reactive UI updates.
4.  **Business Logic (Services)**: Discrete services handle specific domains (AI, Auth, Payments, Sync).

---

## 🤖 AI Pipeline (Gemini 3.1 Integration)

The heart of SumQuiz is its advanced AI pipeline, modernized in March 2026 to leverage **Gemini 3.1 Flash and Pro**.

### 🧠 Model Stack
-   **Primary (Fast)**: `gemini-3.1-flash-lite-preview` – Used for rapid summarization and quiz generation.
-   **Pro (Reasoning)**: `gemini-3.1-pro-preview` – Used for complex document analysis, large context extraction, and YouTube multimodal processing.
-   **Context Window**: 1,000,000 tokens/characters, allowing for full-length textbook analysis.

### 🛠️ Specialized Services
-   **GeneratorAIService**: Enforces strict `responseSchema` for valid JSON output. Uses native `systemInstruction` to switch between "Academic Educator" and "Content Extractor" roles.
-   **YouTubeAIService**:
    -   **Mode A (Multimodal)**: Directly analyzes video audio for short videos (<15 mins).
    -   **Mode C (Transcript)**: Refines raw transcripts for longer videos using the 1M context window.
-   **WebAIService**: Extracts core educational content from URLs while stripping noise/ads.

---

## 🔄 Data Flow & Synchronization

SumQuiz implements an **Offline-First** strategy with real-time cloud synchronization.

### 💾 Storage Strategy
1.  **Local Storage (Hive)**: All user data (Summaries, Quizzes, Flashcard Sets, Folders) is first committed to a high-speed Hive database.
2.  **Cloud Storage (Firestore)**: Metadata and content are synced to Firebase Firestore when the device is online.
3.  **Sync Logic**: Managed by `SyncService`, which uses timestamp-based conflict resolution to ensure data consistency across devices.

### 📊 Spaced Repetition (SRS)
-   Integrates a custom SRS engine to schedule flashcard reviews based on user performance, persisted locally and synced to the cloud.

---

## 💳 Payment & Subscriptions

A robust multi-channel payment system supports both Global and Local (Africa-focused) users.

1.  **In-App Purchases (IAP)**: Native handling for iOS App Store and Google Play Store subscriptions.
2.  **Flutterwave**: Integrated for Direct Bank/Card payments, specifically for regions where IAP may have lower adoption or different fee structures.
3.  **Tier System**:
    -   **Free**: Daily limits on generation tasks.
    -   **Pro**: Unlimited generation, priority processing, and advanced AI features.

---

## 🚀 Deployment & Integrity

-   **Backend**: Powered by **Firebase Cloud Functions** for heavy-lifting tasks.
-   **Security**: **Firebase App Check** protects against unauthorized API access.
-   **Crash Reporting**: **Firebase Crashlytics** tracks real-time errors in production.
-   **Platform Support**:
    -   **Android & iOS**: Optimized native binaries.
    -   **Web**: Hosted on **Firebase Hosting** with a sleek, responsive landing page and full dashboard.

---

## 🛠️ Development Setup

1.  Clone Repository.
2.  Initialize Firebase: `flutterfire configure`.
3.  Environment Variables: Configure `.env` for Flutterwave and Gemini API Keys.
4.  Run: `flutter run -d chrome` (Web) or `flutter run` (Mobile).

---
*Last Updated: March 2026 by Antigravity AI*

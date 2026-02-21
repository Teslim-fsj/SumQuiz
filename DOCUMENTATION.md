# SumQuiz Flutter Application Documentation

## Overview

SumQuiz is a Flutter-based educational application that helps students create study materials using AI-powered tools. The app allows users to generate summaries, quizzes, and flashcards from text content or PDF documents. It integrates with Firebase for authentication, data storage, and AI services.

## Features

1. **User Authentication**
   - Email/password registration and login
      - Google Sign-In integration
         - User profile management

         2. **AI-Powered Content Generation**
            - Text summarization
               - Quiz generation with multiple-choice questions
                  - Flashcard creation with question/answer pairs

                  3. **Content Management**
                     - Save generated content to personal library
                        - Organize content by type (summaries, quizzes, flashcards)
                           - View creation history

                           4. **Subscription System**
                              - Free tier with daily usage limits
                                 - Pro subscription for unlimited access
                                    - In-app purchase integration

                                    5. **Offline Support**
                                       - Basic functionality when offline
                                          - Content caching

                                          ## Project Structure

                                          ```
                                          lib/
                                          ├── main.dart                  # Application entry point
                                          ├── models/                    # Data models
                                          │   ├── flashcard.dart         # Flashcard data structure
                                          │   ├── flashcard_model.dart   # Flashcard set model
                                          │   ├── library_item.dart      # Library item model
                                          │   ├── quiz_model.dart        # Quiz model
                                          │   ├── quiz_question.dart     # Quiz question model
                                          │   ├── summary_model.dart     # Summary model
                                          │   └── user_model.dart        # User model
                                          ├── screens/                   # Screen widgets
                                          │   ├── auth_gate.dart         # Authentication gate
                                          │   ├── dashboard_screen.dart  # Dashboard screen
                                          │   └── sign_in_screen.dart    # Sign-in screen
                                          ├── services/                  # Business logic services
                                          │   ├── ai_service.dart        # AI content generation
                                          │   ├── auth_service.dart      # Authentication service
                                          │   ├── firestore_service.dart # Firestore data service
                                          │   ├── progress_service.dart  # Progress tracking service
                                          │   ├── subscription_service.dart # Subscription management
                                          │   └── upgrade_service.dart   # In-app purchase service
                                          ├── utils/                     # Utility functions
                                          │   └── logger.dart            # Logging utility
                                          └── views/                     # UI components
                                              ├── screens/               # Main application screens
                                                  │   ├── auth_screen.dart   # Authentication screen
                                                      │   ├── flashcards_screen.dart # Flashcards generation screen
                                                          │   ├── home_screen.dart   # Home screen
                                                              │   ├── library_screen.dart # Content library screen
                                                                  │   ├── main_screen.dart   # Main application screen
                                                                      │   ├── profile_screen.dart # User profile screen
                                                                          │   ├── progress_screen.dart # Progress tracking screen
                                                                              │   ├── quiz_screen.dart   # Quiz generation screen
                                                                                  │   ├── subscription_screen.dart # Subscription screen
                                                                                      │   └── summary_screen.dart # Summary generation screen
                                                                                          ├── widgets/               # Reusable widgets
                                                                                              │   └── upgrade_modal.dart # Subscription upgrade modal
                                                                                                  ├── auth_screen.dart       # Authentication screen (duplicate)
                                                                                                      ├── main_screen.dart       # Main screen (duplicate)
                                                                                                          └── theme.dart             # Application theming
                                                                                                          ```

                                                                                                          ## Key Components

                                                                                                          ### Authentication System

                                                                                                          The app uses Firebase Authentication for user management with support for:
                                                                                                          - Email/password authentication
                                                                                                          - Google Sign-In
                                                                                                          - User session management

                                                                                                          ### AI Content Generation

                                                                                                          The AI service integrates with Google's Gemini AI to generate educational content:
                                                                                                          - Summaries from text or PDF documents
                                                                                                          - Multiple-choice quizzes with 4 options each
                                                                                                          - Flashcard sets with question/answer pairs

                                                                                                          ### Data Models

                                                                                                          #### User Model
                                                                                                          - Stores user information (UID, name, email)
                                                                                                          - Tracks subscription status and daily usage limits
                                                                                                          - Manages usage statistics

                                                                                                          #### Content Models
                                                                                                          - **Summary**: Text content with timestamp
                                                                                                          - **Quiz**: Collection of questions with title and timestamp
                                                                                                          - **Flashcard Set**: Collection of flashcards with title and timestamp

                                                                                                          ### Services

                                                                                                          #### AuthService
                                                                                                          Handles user authentication and registration, including:
                                                                                                          - Creating new user accounts
                                                                                                          - Signing in with email/password
                                                                                                          - Google Sign-In integration
                                                                                                          - User session management

                                                                                                          #### FirestoreService
                                                                                                          Manages all data operations with Cloud Firestore:
                                                                                                          - User data storage and retrieval
                                                                                                          - Content library management
                                                                                                          - Usage tracking and limits

                                                                                                          #### AIService
                                                                                                          Interfaces with Google's AI models to generate content:
                                                                                                          - Text summarization
                                                                                                          - Quiz generation
                                                                                                          - Flashcard creation

                                                                                                          #### UpgradeService
                                                                                                          Manages in-app purchases for subscription upgrades:
                                                                                                          - Product querying
                                                                                                          - Purchase processing
                                                                                                          - Purchase status handling

                                                                                                          ## UI Components

                                                                                                          ### Main Screens

                                                                                                          1. **AuthScreen**: Handles user login and registration
                                                                                                          2. **MainScreen**: Main application interface with bottom navigation
                                                                                                          3. **LibraryScreen**: Displays user's saved content organized by type
                                                                                                          4. **ProgressScreen**: Shows user's learning progress and statistics
                                                                                                          5. **ProfileScreen**: Displays user information and subscription status
                                                                                                          6. **SummaryScreen**: Generates and manages text summaries
                                                                                                          7. **QuizScreen**: Creates and takes quizzes
                                                                                                          8. **FlashcardsScreen**: Generates and reviews flashcards

                                                                                                          ### Widgets

                                                                                                          - **UpgradeModal**: Subscription upgrade dialog
                                                                                                          - Various Material Design components for consistent UI

                                                                                                          ## Dependencies

                                                                                                          Key dependencies include:
                                                                                                          - `firebase_core`: Firebase initialization
                                                                                                          - `firebase_auth`: Authentication services
                                                                                                          - `cloud_firestore`: Database services
                                                                                                          - `google_sign_in`: Google authentication
                                                                                                          - `provider`: State management
                                                                                                          - `google_fonts`: Typography
                                                                                                          - `file_picker`: PDF file selection
                                                                                                          - `syncfusion_flutter_pdf`: PDF processing
                                                                                                          - `flutter_card_swiper`: Flashcard swiping interface
                                                                                                          - `flip_card`: Flashcard flipping animation
                                                                                                          - `in_app_purchase`: Subscription management
                                                                                                          - `firebase_ai`: AI model integration

                                                                                                          ## Firebase Integration

                                                                                                          The app uses several Firebase services:
                                                                                                          - **Authentication**: User management and security
                                                                                                          - **Cloud Firestore**: Data storage for user content
                                                                                                          - **Firebase AI**: AI model access for content generation

                                                                                                          ## Theme and Styling

                                                                                                          The app implements Material Design 3 with:
                                                                                                          - Light and dark theme support
                                                                                                          - Custom color schemes using seed colors
                                                                                                          - Google Fonts for typography
                                                                                                          - Consistent component styling

                                                                                                          ## Subscription Model

                                                                                                          - **Free Tier**: Limited daily usage (5 summaries, 3 quizzes, 3 flashcards)
                                                                                                          - **Pro Tier**: Unlimited content generation
                                                                                                          - In-app purchase integration for upgrading

                                                                                                          ## Error Handling

                                                                                                          The app includes comprehensive error handling for:
                                                                                                          - Network connectivity issues
                                                                                                          - Authentication failures
                                                                                                          - AI service errors
                                                                                                          - Data storage problems
                                                                                                          - File processing errors

                                                                                                          ## Offline Support

                                                                                                          Basic offline functionality is provided through:
                                                                                                          - Connectivity status monitoring
                                                                                                          - Cached content display
                                                                                                          - Graceful degradation of features

                                                                                                          ## Development Setup

                                                                                                          1. Clone the repository
                                                                                                          2. Run `flutter pub get` to install dependencies
                                                                                                          3. Configure Firebase project and add `firebase_options.dart`
                                                                                                          4. Run `flutter run` to start the application

                                                                                                          ## Future Enhancements

                                                                                                          Potential areas for improvement:
                                                                                                          - Enhanced offline capabilities with local data persistence
                                                                                                          - Social features for sharing content
                                                                                                          - Advanced analytics and progress tracking
                                                                                                          - Additional content types (mind maps, diagrams)
                                                                                                          - Multi-language support
                                                                                                          - Improved AI prompt engineering for better content quality
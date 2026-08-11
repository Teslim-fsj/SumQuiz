import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart' as auth;
import 'package:sumquiz/config/google_oauth_config.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/providers/sync_provider.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/services/referral_service.dart';
import 'package:sumquiz/services/notification_integration.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:sumquiz/services/creator_program_service.dart';

class AuthService {
  final FirebaseAuth _auth;
  final auth.GoogleSignIn _googleSignIn = auth.GoogleSignIn.instance;

  /// Guard so [_googleSignIn.initialize] is only ever called once (v7 requirement).
  static bool _googleSignInInitialized = false;
  final FirestoreService _firestoreService = FirestoreService();
  final ReferralService _referralService = ReferralService();

  static const String _authTokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userDisplayNameKey = 'user_display_name';
  static const String _userEmailKey = 'user_email';

  AuthService(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Save user authentication state locally for offline access
  Future<void> _saveAuthState(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, user.uid);
      await prefs.setString(_userDisplayNameKey, user.displayName ?? '');
      await prefs.setString(_userEmailKey, user.email ?? '');

      // Save token if available
      final token = await user.getIdToken();
      if (token != null) {
        await prefs.setString(_authTokenKey, token);
      }

      developer.log('Authentication state saved locally for user: ${user.uid}');
    } catch (e) {
      developer.log('Failed to save authentication state', error: e);
    }
  }

  /// Clear saved authentication state
  Future<void> _clearAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userDisplayNameKey);
      await prefs.remove(_userEmailKey);
      developer.log('Authentication state cleared');
    } catch (e) {
      developer.log('Failed to clear authentication state', error: e);
    }
  }

  /// Restore authentication state when app starts
  Future<bool> restoreAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_authTokenKey);
      final userId = prefs.getString(_userIdKey);

      // If we have a token and user ID, try to restore the session
      if (token != null &&
          userId != null &&
          token.isNotEmpty &&
          userId.isNotEmpty) {
        // Note: In a real implementation, you would validate the token
        // For now, we'll just log that we have saved state
        developer.log('Found saved authentication state for user: $userId');
        return true;
      }
      return false;
    } catch (e) {
      developer.log('Failed to restore authentication state', error: e);
      return false;
    }
  }

  Stream<UserModel?> get user {
    return _auth.authStateChanges().switchMap((user) {
      if (user == null) {
        return Stream.value(null);
      }
      return _firestoreService.streamUser(user.uid);
    });
  }

  // Removed redundant _ensureGoogleSignInInitialized as configuration is handled in signInWithGoogle for mobile

  Future<void> signInWithGoogle(BuildContext context,
      {String? referralCode}) async {
    try {
      developer.log('Starting Google Sign-In flow (web=$kIsWeb)');

      User? user;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters(const {'prompt': 'select_account'});
        final UserCredential result =
            await _auth.signInWithPopup(googleProvider);
        user = result.user;
      } else {
        // v7: initialize() must be called exactly once before any other method.
        if (!_googleSignInInitialized) {
          await _googleSignIn.initialize(
            clientId: defaultTargetPlatform == TargetPlatform.iOS
                ? kGoogleIosClientId
                : null,
            serverClientId: kGoogleWebServerClientId,
          );
          _googleSignInInitialized = true;
        }

        await _googleSignIn.signOut(); // Ensure fresh account picker

        // Step 1: Authenticate (identity only)
        developer.log('Authenticating with Google...', name: 'AuthService');
        final auth.GoogleSignInAccount googleUser =
            await _googleSignIn.authenticate();

        developer.log('Google user selected: ${googleUser.email}',
            name: 'AuthService');

        // Step 2: Get Authentication tokens (ID)
        developer.log('Fetching Google authentication tokens...',
            name: 'AuthService');
        final auth.GoogleSignInAuthentication googleAuth =
            googleUser.authentication;
        final String? idToken = googleAuth.idToken;

        developer.log('ID Token present: ${idToken != null}',
            name: 'AuthService');

        if (idToken == null || idToken.isEmpty) {
          developer.log('Error: Google did not return an ID token',
              name: 'AuthService');
          throw FirebaseAuthException(
            code: 'no-id-token',
            message: 'Google did not return an ID token.',
          );
        }

        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken:
              null, // accessToken is moved to authorizationClient in v7
        );

        final UserCredential result =
            await _auth.signInWithCredential(credential);
        user = result.user;
      }

      if (user != null) {
        developer.log('Firebase user signed in: ${user.uid}',
            name: 'AuthService');

        // Save authentication state for offline access
        await _saveAuthState(user);

        // Trigger sync in background - DO NOT AWAIT here as it can hang the UI during login
        if (context.mounted) {
          developer.log('Triggering background data sync...',
              name: 'AuthService');
          Provider.of<SyncProvider>(context, listen: false)
              .syncData()
              .catchError((e) {
            developer.log('Background sync failed',
                name: 'AuthService', error: e);
          });
        }

        // Check if user document exists in Firestore
        developer.log('Checking for existing user document in Firestore...',
            name: 'AuthService');
        final userDoc =
            await _firestoreService.db.collection('users').doc(user.uid).get();
        final bool isNewToFirestore = !userDoc.exists;

        if (isNewToFirestore) {
          developer.log('New Firestore user detected. Creating profile...',
              name: 'AuthService');
          final prefs = await SharedPreferences.getInstance();
          final intendedRoleName = prefs.getString('intended_role');
          UserRole role = UserRole.student;
          if (intendedRoleName != null) {
            role = UserRole.values.firstWhere(
              (e) => e.name == intendedRoleName,
              orElse: () => UserRole.student,
            );
            await prefs.remove('intended_role'); // Clean up
          }

          UserModel newUser = UserModel(
            uid: user.uid,
            displayName: user.displayName ?? '',
            email: user.email ?? '',
            role: role,
          );
          await _firestoreService.saveUserData(newUser);
          developer.log('User profile created successfully',
              name: 'AuthService');

          // Handle referral attribution pipeline securely
          await _handleReferralAttribution(user.uid, user.email ?? '', referralCode);

          // 🔔 Schedule notifications for new user
          if (context.mounted) {
            try {
              developer.log('Scheduling new user notifications...',
                  name: 'AuthService');
              await NotificationIntegration.onUserRegistered(context, user.uid);
            } catch (e) {
              developer.log('Failed to schedule notifications for new user',
                  name: 'AuthService', error: e);
            }
          }

          // 🎭 Flag for role-selection onboarding dialog
          await prefs.setBool('is_new_user', true);
        } else {
          developer.log(
              'Existing user document found. Skipping profile creation.',
              name: 'AuthService');
        }
        
        // Track first login for creator referral attribution
        try {
          await CreatorProgramService().trackLogin(user.uid);
        } catch (e) {
          developer.log('Error tracking creator referral login: $e');
        }
        developer.log('Google Sign-In flow complete.', name: 'AuthService');
      }
    } on FirebaseAuthException catch (e, s) {
      developer.log('Firebase Auth error during Google Sign-In',
          error: e, stackTrace: s);
      rethrow;
    } on auth.GoogleSignInException catch (e, s) {
      developer.log('Google Sign-In error', error: e, stackTrace: s);
      rethrow;
    } catch (e, s) {
      developer.log('An unexpected error occurred during Google Sign-In',
          error: e, stackTrace: s);
      if (e is FirebaseAuthException || e is auth.GoogleSignInException) {
        rethrow;
      }
      throw Exception('Google sign-in could not complete. Please try again.');
    }
  }

  Future<void> signInWithEmailAndPassword(
      BuildContext context, String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save authentication state for offline access
      if (result.user != null) {
        await _saveAuthState(result.user!);
        
        // Track login for creator referral attribution
        try {
          await CreatorProgramService().trackLogin(result.user!.uid);
        } catch (e) {
          developer.log('Error tracking creator referral login: $e');
        }

        if (context.mounted) {
          await Provider.of<SyncProvider>(context, listen: false).syncData();
        }
      }
    } on FirebaseAuthException catch (e, s) {
      developer.log('Error signing in with email', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<void> signUpWithEmailAndPassword(BuildContext context, String email,
      String password, String fullName, String? referralCode) async {
    try {
      // 0. Validate Referral Code (Pre-check)
      if (referralCode != null && referralCode.isNotEmpty) {
        final isValid =
            await _referralService.validateReferralCode(referralCode);
        if (!isValid) {
          throw Exception('Referral code error: Code not found');
        }
      }

      // 1. Create user in Firebase Auth directly (Client-side)
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        developer.log('User created via Client SDK: ${user.uid}');

        // 2. Update Display Name
        await user.updateDisplayName(fullName);

        // 3. Create User Document in Firestore
        final prefs = await SharedPreferences.getInstance();
        final intendedRoleName = prefs.getString('intended_role');
        UserRole role = UserRole.student;
        if (intendedRoleName != null) {
          role = UserRole.values.firstWhere(
            (e) => e.name == intendedRoleName,
            orElse: () => UserRole.student,
          );
          await prefs.remove('intended_role'); // Clean up
        }

        UserModel newUser = UserModel(
          uid: user.uid,
          displayName: fullName,
          email: email,
          role: role,
        );
        await _firestoreService.saveUserData(newUser);

        // Apply Referral Code securely via attribution pipeline
        await _handleReferralAttribution(user.uid, email, referralCode);

        // 5. Save Auth State & Sync
        await _saveAuthState(user);
        if (context.mounted) {
          await Provider.of<SyncProvider>(context, listen: false).syncData();
        }

        // 6. Send Verification Email
        try {
          if (!user.emailVerified) {
            await user.sendEmailVerification();
            developer.log('Verification email sent to $email');
          }
        } catch (e) {
          developer.log('Failed to send verification email', error: e);
        }

        // 🔔 Schedule notifications for new user
        if (context.mounted) {
          try {
            await NotificationIntegration.onUserRegistered(context, user.uid);
          } catch (e) {
            developer.log('Failed to schedule notifications for new user',
                error: e);
          }
        }

        // 🎭 Flag for role-selection onboarding dialog
        await prefs.setBool('is_new_user', true);
      }
    } on FirebaseAuthException catch (e, s) {
      developer.log('Error signing up', error: e, stackTrace: s);
      rethrow;
    } catch (e, s) {
      developer.log('Unexpected error during signup', error: e, stackTrace: s);
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
      // Clear saved authentication state
      await _clearAuthState();
    } catch (e, s) {
      developer.log('Error signing out', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // HIGH PRIORITY FIX H2: Rate Limiting (Password Reset)
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendPasswordResetEmail');
      await callable.call({'email': email});
    } on FirebaseFunctionsException catch (e) {
      developer.log('Error sending password reset email via Cloud Function',
          error: e);
      rethrow;
    } catch (e, s) {
      developer.log('Unexpected error sending password reset email',
          error: e, stackTrace: s);
      rethrow;
    }
  }

  User? get currentUser => _auth.currentUser;

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        developer.log('Verification email resent to ${user.email}');
      } catch (e) {
        developer.log('Failed to resend verification email', error: e);
        rethrow;
      }
    }
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Update the user's role in Firestore (called after sign-up role selection)
  Future<void> updateUserRole(String uid, UserRole role) async {
    try {
      await FirestoreService().db.collection('users').doc(uid).update({
        'role': role.name,
      });
      developer.log('User role updated to ${role.name} for $uid');
    } catch (e) {
      developer.log('Failed to update user role', error: e);
      rethrow;
    }
  }
  Future<void> _handleReferralAttribution(String userId, String email, String? code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final finalCode = (code != null && code.isNotEmpty)
          ? code
          : prefs.getString('pending_referral_code');

      if (finalCode == null || finalCode.isEmpty) return;

      if (finalCode.toUpperCase().startsWith('SUMI')) {
        // Creator Referral Attribution
        final creatorService = CreatorProgramService();
        await creatorService.trackSignup(userId, email, finalCode.toUpperCase());
        // Save creator referral tag on user doc
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'referredByCreatorCode': finalCode.toUpperCase(),
        });
        await prefs.remove('pending_referral_code');
        developer.log('Successfully attributed signup of $userId to creator code $finalCode');
      } else {
        // Standard Referral
        await _referralService.applyReferralCode(finalCode, userId);
        await prefs.remove('pending_referral_code');
      }
    } catch (e) {
      developer.log('Error in referral attribution: $e');
    }
  }
}

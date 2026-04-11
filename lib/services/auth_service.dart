import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
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

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final ReferralService _referralService = ReferralService();

  static bool _googleSignInInitialized = false;
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

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: kGoogleWebServerClientId,
    );
    _googleSignInInitialized = true;
  }

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
        await _ensureGoogleSignInInitialized();
        await _googleSignIn.signOut();

        final Future<GoogleSignInAccount?>? lightweightFuture =
            _googleSignIn.attemptLightweightAuthentication();
        GoogleSignInAccount? googleUser;
        if (lightweightFuture != null) {
          googleUser = await lightweightFuture;
        }
        googleUser ??= await _googleSignIn.authenticate();

        developer.log('Google user authenticated: ${googleUser.email}');

        final GoogleSignInAuthentication googleAuth =
            googleUser.authentication;
        final String? idToken = googleAuth.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw FirebaseAuthException(
            code: 'no-id-token',
            message: 'Google did not return an ID token.',
          );
        }

        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: idToken,
        );
        final UserCredential result =
            await _auth.signInWithCredential(credential);
        user = result.user;
      }

      if (user != null) {
        developer.log('Firebase user signed in: ${user.uid}');

        // Save authentication state for offline access
        await _saveAuthState(user);

        if (context.mounted) {
          await Provider.of<SyncProvider>(context, listen: false).syncData();
        }

        // Check if user document exists in Firestore
        final userDoc = await _firestoreService.db.collection('users').doc(user.uid).get();
        final bool isNewToFirestore = !userDoc.exists;

        if (isNewToFirestore) {
          developer.log('New Firestore user signed in with Google: ${user.uid}');
          developer.log('New user signed in with Google: ${user.uid}');
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
          developer.log('User profile created for ${user.uid}');

          if (referralCode != null && referralCode.isNotEmpty) {
            try {
              await _referralService.applyReferralCode(referralCode, user.uid);
            } catch (e, s) {
              developer.log(
                  'Error applying referral code during Google Sign-In',
                  error: e,
                  stackTrace: s);
              // Don't fail the entire sign-in process if referral code fails
              // Just log the error and continue
            }
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
        } else {
          developer.log('Existing Firestore user signed in with Google: ${user.uid}');
        }
      }
    } on FirebaseAuthException catch (e, s) {
      developer.log('Firebase Auth error during Google Sign-In',
          error: e, stackTrace: s);
      rethrow;
    } on GoogleSignInException catch (e, s) {
      developer.log('Google Sign-In error', error: e, stackTrace: s);
      rethrow;
    } catch (e, s) {
      developer.log('An unexpected error occurred during Google Sign-In',
          error: e, stackTrace: s);
      if (e is FirebaseAuthException || e is GoogleSignInException) rethrow;
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

        // 4. Apply Referral Code (Best Effort)
        if (referralCode != null && referralCode.isNotEmpty) {
          try {
            // Try to apply referral via service or cloud function
            // Assuming _referralService exists and handles this
            await _referralService.applyReferralCode(referralCode, user.uid);
          } catch (e) {
            developer.log('Failed to apply referral code', error: e);
            // Do not fail the whole signup
          }
        }

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
      if (!kIsWeb && _googleSignInInitialized) {
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
}

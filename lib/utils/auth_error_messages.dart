import 'package:firebase_auth/firebase_auth.dart';

/// User-facing copy for Firebase Auth. Avoid exposing raw exception strings.
String messageForFirebaseAuth(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'That email address does not look valid. Check for typos.';
    case 'user-disabled':
      return 'This account has been disabled. Contact support if you need help.';
    case 'user-not-found':
      return 'No account exists with this email. Sign up or check the address.';
    case 'wrong-password':
      return 'Incorrect password. Try again or reset your password.';
    case 'invalid-credential':
      return _invalidCredentialMessage(e);
    case 'email-already-in-use':
      return 'An account already uses this email. Try signing in instead.';
    case 'operation-not-allowed':
      return 'This sign-in method is not available for this app.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters and mix letters and numbers.';
    case 'network-request-failed':
      return 'Network problem. Check your connection and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Wait a few minutes and try again.';
    case 'requires-recent-login':
      return 'For security, sign in again before doing that.';
    case 'user-token-expired':
      return 'Your session expired. Please sign in again.';
    case 'expired-action-code':
      return 'This link or code has expired. Request a new one.';
    case 'invalid-action-code':
      return 'This link or code is invalid or was already used.';
    case 'account-exists-with-different-credential':
      return 'This email is already registered with a different sign-in method. Use the original method.';
    case 'credential-already-in-use':
      return 'This Google account is already linked to another user.';
    case 'popup-blocked':
      return 'Your browser blocked the sign-in window. Allow popups for this site and try again.';
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
      return ''; // silent - user dismissed
    case 'web-storage-unsupported':
      return 'This browser does not support the storage needed for sign-in. Try another browser.';
    case 'invalid-verification-code':
    case 'invalid-verification-id':
      return 'Invalid verification code. Check the code and try again.';
    case 'missing-email':
      return 'Please enter your email address.';
    case 'missing-password':
      return 'Please enter your password.';
    case 'no-id-token':
      return 'Google sign-in did not return a token. Close the app and try again.';
    default:
      if (e.message != null &&
          e.message!.isNotEmpty &&
          !e.message!.contains('Exception')) {
        return e.message!;
      }
      return 'Sign-in failed (${e.code}). Please try again.';
  }
}

String _invalidCredentialMessage(FirebaseAuthException e) {
  final msg = (e.message ?? '').toLowerCase();
  if (msg.contains('malformed') || msg.contains('expired')) {
    return 'Your sign-in session is invalid or expired. Please try again.';
  }
  return 'Email or password is too incorrect. You can reset your password if you forgot it.';
}

String messageForGoogleSignInException(dynamic e) {
  final code = e.toString();
  if (code.contains('canceled') || code.contains('cancelled')) {
    return '';
  }
  if (code.contains('network_error')) {
    return 'Network error during Google Sign-In. Please check your connection.';
  }
  return 'Google Sign-In failed. Please try again.';
}

String messageForAuthFailure(Object e) {
  if (e is FirebaseAuthException) {
    return messageForFirebaseAuth(e);
  }
  final s = e.toString();
  if (s.contains('Referral') || s.contains('referral')) {
    return s.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }
  return 'Something went wrong. Please try again.';
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/config/firebase_options.dart';
import '../../subscription/services/subscription_service.dart';
import '../../../data/local/daily_usage_service.dart';

/// Modular Authentication Service handling Firebase Authentication & RevenueCat User ID Sync.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SubscriptionService _subscriptionService;
  final DailyUsageService _usageService;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: kGoogleSignInWebClientId,
  );
  bool _googleSignInInProgress = false;

  AuthService(this._subscriptionService, this._usageService) {
    // Listen to Firebase auth changes & keep RevenueCat synchronized
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _subscriptionService.identifyUser(user.uid);
        await _usageService.syncToCurrentAccount();
      } else {
        await _subscriptionService.resetUser();
      }
    });
  }

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  /// Email & Password Sign Up with Graceful Fallback
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        await _subscriptionService.identifyUser(cred.user!.uid);
      }
      return cred;
    } catch (e) {
      debugPrint('Firebase SignUp Error: $e');
      // If Firebase Auth provider is not enabled in console yet, fall back to anonymous/local auth
      try {
        final anonCred = await _auth.signInAnonymously();
        if (anonCred.user != null) {
          await _subscriptionService.identifyUser(anonCred.user!.uid);
        }
        return anonCred;
      } catch (_) {
        return null;
      }
    }
  }

  /// Email & Password Sign In with Graceful Fallback
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        await _subscriptionService.identifyUser(cred.user!.uid);
      }
      return cred;
    } catch (e) {
      debugPrint('Firebase SignIn Error: $e');
      try {
        final anonCred = await _auth.signInAnonymously();
        if (anonCred.user != null) {
          await _subscriptionService.identifyUser(anonCred.user!.uid);
        }
        return anonCred;
      } catch (_) {
        return null;
      }
    }
  }

  /// Google Sign In. Keep this as one guarded flow so Android does not open
  /// the account chooser twice when OAuth configuration reports an error.
  Future<UserCredential?> signInWithGoogle() async {
    if (_googleSignInInProgress) return null;
    _googleSignInInProgress = true;
    try {
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User explicitly cancelled dialog, return gracefully
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      if (cred.user != null) {
        await _subscriptionService.identifyUser(cred.user!.uid);
      }
      return cred;
    } catch (e) {
      debugPrint('Google Sign In Catch Error: $e');
      return null;
    } finally {
      _googleSignInInProgress = false;
    }
  }

  /// Apple Sign In
  Future<UserCredential?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final cred = await _auth.signInWithCredential(credential);
      if (cred.user != null) {
        await _subscriptionService.identifyUser(cred.user!.uid);
      }
      return cred;
    } catch (e) {
      debugPrint('Apple Sign In Error: $e');
      try {
        final anonCred = await _auth.signInAnonymously();
        if (anonCred.user != null) {
          await _subscriptionService.identifyUser(anonCred.user!.uid);
        }
        return anonCred;
      } catch (_) {
        return null;
      }
    }
  }

  /// Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset error: $e');
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
    await _subscriptionService.resetUser();
  }
}

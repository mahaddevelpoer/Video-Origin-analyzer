import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../subscription/services/subscription_service.dart';

/// Modular Authentication Service handling Firebase Authentication & RevenueCat User ID Sync.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SubscriptionService _subscriptionService;

  AuthService(this._subscriptionService) {
    // Listen to Firebase auth changes & keep RevenueCat synchronized
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _subscriptionService.identifyUser(user.uid);
      } else {
        await _subscriptionService.resetUser();
      }
    });
  }

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  /// Email & Password Sign Up
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (cred.user != null) {
      await _subscriptionService.identifyUser(cred.user!.uid);
    }
    return cred;
  }

  /// Email & Password Sign In
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (cred.user != null) {
      await _subscriptionService.identifyUser(cred.user!.uid);
    }
    return cred;
  }

  /// Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // Cancelled

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
      debugPrint('Google Sign In Error: $e');
      rethrow;
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
      rethrow;
    }
  }

  /// Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    await _subscriptionService.resetUser();
  }
}

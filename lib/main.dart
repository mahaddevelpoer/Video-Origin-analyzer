import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/config/firebase_options.dart';
import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/subscription/services/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Mobile Ads SDK
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('AdMob Init Notice: $e');
  }

  // Initialize RevenueCat SDK
  try {
    final subService = SubscriptionService();
    await subService.initialize();
  } catch (e) {
    debugPrint('RevenueCat Init Notice: $e');
  }

  // Initialize Firebase with Platform Options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase Core Init Notice: $e');
  }

  // Initialize Local Storage
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const VideoOriginAnalyzerApp(),
    ),
  );
}

class VideoOriginAnalyzerApp extends StatelessWidget {
  const VideoOriginAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}

/// Authentication Gate enforcing login/register requirement before accessing HomeScreen.
/// Gracefully handles test environments where native Firebase apps are uninitialized.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if Firebase is initialized (handles widget test runner gracefully)
    if (Firebase.apps.isEmpty) {
      return const WelcomeScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF0000)),
            ),
          );
        }

        // If user is authenticated via Email, Google, or Apple -> HomeScreen
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        // If unauthenticated -> Require Login / Register / Google Sign-In
        return const WelcomeScreen();
      },
    );
  }
}

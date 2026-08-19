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

  // Run independent SDK initializations concurrently to optimize startup speed
  final prefsFuture = SharedPreferences.getInstance();
  final adsFuture = MobileAds.instance.initialize().catchError((e) {
    debugPrint('AdMob Init Notice: $e');
    return InitializationStatus({});
  });
  final subscriptionService = SubscriptionService();
  final subFuture = subscriptionService.initialize().catchError((e) {
    debugPrint('RevenueCat Init Notice: $e');
  });
  final firebaseFuture = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).catchError((e) {
    debugPrint('Firebase Core Init Notice: $e');
    return Firebase.app();
  });

  final results = await Future.wait([
    prefsFuture,
    adsFuture,
    subFuture,
    firebaseFuture,
  ]);

  final prefs = results[0] as SharedPreferences;
  subscriptionService.attachAccountSync();
  await subscriptionService.updateSubscriptionStatus();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        subscriptionServiceProvider.overrideWithValue(subscriptionService),
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
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

/// Authentication Gate enforcing direct HomeScreen access for active/previous logins.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final hasLoggedInBefore = prefs.getBool('has_logged_in_before') ?? false;

    // Check if Firebase is initialized (handles widget test runner gracefully)
    if (Firebase.apps.isEmpty) {
      return hasLoggedInBefore ? const HomeScreen() : const WelcomeScreen();
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

        // If user is authenticated via Email, Google, or has entered before -> HomeScreen
        if ((snapshot.hasData && snapshot.data != null) || hasLoggedInBefore) {
          return const HomeScreen();
        }

        // If fresh initial installation -> Show WelcomeScreen
        return const WelcomeScreen();
      },
    );
  }
}

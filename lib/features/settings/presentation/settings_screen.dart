import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../history/presentation/history_screen.dart';
import '../../subscription/presentation/paywall_screen.dart';
import 'about_screen.dart';
import 'privacy_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final subService = ref.watch(subscriptionServiceProvider);
    final user = authService.currentUser;
    final isPro = subService.isProActive;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(title: const Text('Settings & Configuration')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('ACCOUNT'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: AppColors.youtubeRed),
                    title: Text(
                      user != null ? (user.email ?? 'Authenticated User') : 'Guest User (Local)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    subtitle: Text(
                      user != null ? 'Firebase Auth UID: ${user.uid}' : 'Not signed in',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                  if (user != null)
                    ListTile(
                      leading: const Icon(Icons.logout, color: AppColors.strengthContradictory),
                      title: const Text('Sign Out', style: TextStyle(color: AppColors.strengthContradictory)),
                      onTap: () async {
                        await authService.signOut();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionHeader('SUBSCRIPTION & LICENSING'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isPro ? Icons.star : Icons.account_balance_wallet_outlined,
                      color: isPro ? AppColors.youtubeRed : AppColors.textMuted,
                    ),
                    title: Text(isPro ? 'Pro Subscription Active' : 'Free Tier (2 daily analyses)'),
                    subtitle: Text(isPro ? 'Unlimited local forensic analysis' : 'Tap to upgrade to Pro'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PaywallScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionHeader('PRIVACY & STORAGE'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.security_outlined, color: AppColors.youtubeRed),
                    title: const Text('Local-First Privacy Policy'),
                    subtitle: const Text('Zero video uploads guarantee'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history_outlined, color: AppColors.textMuted),
                    title: const Text('Manage Local History'),
                    subtitle: const Text('Search, filter, or clear analysis history'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HistoryScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionHeader('ABOUT APPLICATION'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: AppColors.youtubeRed),
                    title: const Text('About & Developer Information'),
                    subtitle: const Text(AppConfig.developerName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                '${AppConfig.appName} v1.0.0\n${AppConfig.developerName}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

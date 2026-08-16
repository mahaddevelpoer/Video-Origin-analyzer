import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../home/presentation/home_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isGoogleLoading = false;

  Future<void> _handleGetStarted() async {
    // Automatically initialize/persist session so subsequent app launches jump straight to HomeScreen
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('has_logged_in_before', true);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _handleGoogleQuickLogin() async {
    setState(() => _isGoogleLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('has_logged_in_before', true);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (mounted) {
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.setBool('has_logged_in_before', true);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // App Identity Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.youtubeRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConfig.appName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'v1.0.0 • Mahad and Mehdi Developers',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Local Video Origin & Forensic Analysis',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Identify original social media platforms (TikTok, Instagram, YouTube, Snapchat, Facebook) and intermediate compression channels (WhatsApp) using multi-signal evidence analysis.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              _buildFeatureRow(
                icon: Icons.security,
                title: 'Local-First Privacy',
                subtitle: 'Videos are processed 100% on your device. Never uploaded.',
              ),
              const SizedBox(height: 14),
              _buildFeatureRow(
                icon: Icons.account_tree,
                title: 'Multi-Signal Evidence',
                subtitle: 'Metadata, codec profile, aspect ratio, audio & compression analysis.',
              ),
              const SizedBox(height: 14),
              _buildFeatureRow(
                icon: Icons.find_in_page,
                title: 'Transparent Reporting',
                subtitle: 'Clear evidence breakdown explaining why conclusions were reached.',
              ),

              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _handleGetStarted,
                child: const Text('GET STARTED NOW'),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _isGoogleLoading ? null : _handleGoogleQuickLogin,
                icon: const Icon(Icons.g_mobiledata, size: 24, color: AppColors.youtubeRed),
                label: _isGoogleLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.youtubeRed),
                      )
                    : const Text('Continue with Google'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text('SIGN IN'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: const Text('CREATE ACCOUNT'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Powered by Mahad and Mehdi Developers Forensic Engine',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.lightBorder),
          ),
          child: Icon(icon, color: AppColors.youtubeRed, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

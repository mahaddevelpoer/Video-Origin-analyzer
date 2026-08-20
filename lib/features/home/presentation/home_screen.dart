import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/motion_reveal.dart';
import '../../analyzer/presentation/video_picker_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../subscription/presentation/paywall_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final dailyUsageService = ref.watch(dailyUsageServiceProvider);
    final subscriptionService = ref.watch(subscriptionServiceProvider);
    final isPro = subscriptionService.isProActive;
    final usedCount = dailyUsageService.getUsageCount();
    final canAnalyze = dailyUsageService.canAnalyze(isPro);

    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(size: 32, compact: true),
            const SizedBox(width: 10),
            Text(
              AppConfig.appName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textColor),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: textColor),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textColor),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Developer Branding Header Bar
              MotionReveal(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.dividerColor),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                    const Icon(Icons.verified, color: AppColors.youtubeRed, size: 18),
                    const SizedBox(width: 10),
                    const Text(
                      'DEVELOPER:',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppConfig.developerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Usage & Plan Status Card
              MotionReveal(
                delay: const Duration(milliseconds: 80),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPro ? AppColors.youtubeRed : theme.dividerColor,
                      width: isPro ? 1.5 : 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isPro ? Icons.stars : Icons.account_circle_outlined,
                              color: isPro ? AppColors.youtubeRed : AppColors.textDark,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPro ? 'PRO ACCOUNT ACTIVE' : 'FREE ACCOUNT PLAN',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isPro ? AppColors.youtubeRed : AppColors.textDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        if (!isPro)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const PaywallScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.youtubeRed,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'UPGRADE PRO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (isPro)
                      const Text(
                        'Unlimited local video origin analyses enabled.',
                        style: TextStyle(fontSize: 13, color: AppColors.textDark),
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Daily Usage Limit",
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                          Text(
                            '$usedCount / ${AppConfig.freeDailyAnalysisLimit}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (usedCount / AppConfig.freeDailyAnalysisLimit).clamp(0.0, 1.0),
                          backgroundColor: AppColors.lightBackground,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            canAnalyze ? AppColors.youtubeRed : AppColors.strengthWeak,
                          ),
                          minHeight: 6,
                        ),
                      ),
                      if (!canAnalyze) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Daily limit reached. Upgrade to Pro for unlimited analyses.',
                          style: TextStyle(fontSize: 11, color: AppColors.strengthWeak, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action: Analyze Video Card
              MotionReveal(
                delay: const Duration(milliseconds: 160),
                child: GestureDetector(
                  onTap: canAnalyze
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const VideoPickerScreen(),
                          ),
                        );
                      }
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PaywallScreen()),
                        );
                      },
                  child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: canAnalyze ? AppColors.youtubeRed : AppColors.lightBorder,
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: canAnalyze
                              ? AppColors.youtubeRed.withAlpha(20)
                              : AppColors.lightBackground,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.travel_explore,
                          size: 42,
                          color: canAnalyze ? AppColors.youtubeRed : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'ANALYZE VIDEO ORIGIN',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select a video file to estimate its original platform (TikTok, Instagram, YouTube, Facebook, Snapchat) and intermediate channels (WhatsApp).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Secondary Quick Action Buttons
              MotionReveal(
                delay: const Duration(milliseconds: 230),
                child: Row(
                  children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HistoryScreen()),
                        );
                      },
                      icon: const Icon(Icons.history_outlined, size: 18),
                      label: const Text('VIEW HISTORY'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PaywallScreen()),
                        );
                      },
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: const Text('PRO PAYWALL'),
                    ),
                  ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Privacy Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.lightBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.strengthStrong, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Local-first forensic analysis. Optional visual search sends only selected frames.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

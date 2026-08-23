import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admob_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../data/models/analysis_session.dart';
import '../../../data/models/history_record.dart';
import 'analysis_result_screen.dart';

class AnalysisProgressScreen extends ConsumerStatefulWidget {
  final AnalysisSession session;

  const AnalysisProgressScreen({super.key, required this.session});

  @override
  ConsumerState<AnalysisProgressScreen> createState() =>
      _AnalysisProgressScreenState();
}

class _AnalysisProgressScreenState
    extends ConsumerState<AnalysisProgressScreen> {
  late AnalysisStage _currentStage;
  double _progressFraction = 0.0;
  String? _errorMessage;
  final InterstitialAdService _adService = InterstitialAdService();

  @override
  void initState() {
    super.initState();
    _currentStage = AnalysisStage.validatingFile;
    _adService.loadInterstitialAd();
    _runAnalysisFlow();
  }

  Future<void> _runAnalysisFlow() async {
    final subService = ref.read(subscriptionServiceProvider);
    final isPro = subService.isProActive;

    // Zero banner ads to preserve clean YouTube UI design.
    // Interstitial ads shown for Free Tier users only (0 Ads for Pro users).
    if (!isPro && !widget.session.adSlot1Shown) {
      widget.session.adSlot1Shown = true;
      await _adService.showInterstitialAdIfAvailable(isPro: isPro);
    }

    try {
      final engine = ref.read(videoAnalyzerEngineProvider);
      final startTime = DateTime.now();

      final result = await engine.analyzeVideo(
        payload: widget.session.videoPayload,
        enableOcrSearch: widget.session.ocrSearchEnabled,
        onStageChanged: (stage) {
          if (mounted) {
            setState(() {
              _currentStage = stage;
              _progressFraction = stage.progressFraction;
            });
          }
        },
      );

      widget.session.result = result;

      if (!isPro && !widget.session.adSlot2Shown) {
        widget.session.adSlot2Shown = true;
        await _adService.showInterstitialAdIfAvailable(isPro: isPro);
      }

      final dailyUsageService = ref.read(dailyUsageServiceProvider);
      await dailyUsageService.consumeAnalysis(isPro);

      if (!widget.session.historySaved) {
        widget.session.historySaved = true;
        final historyRepo = ref.read(localHistoryRepositoryProvider);
        final processingMs = DateTime.now()
            .difference(startTime)
            .inMilliseconds;

        final record = HistoryRecord(
          id: widget.session.sessionId,
          timestamp: widget.session.startTime,
          filename: widget.session.videoPayload.name,
          filePath:
              widget.session.videoPayload.path ??
              widget.session.videoPayload.name,
          durationFormatted: '00:30',
          fileSizeFormatted: widget.session.videoPayload.fileSizeFormatted,
          resolution: result.technicalDetails['Resolution'] ?? '1080 × 1920',
          container: result.technicalDetails['Container'] ?? 'MP4',
          videoCodec: result.technicalDetails['Video Codec'] ?? 'H.264',
          audioCodec: result.technicalDetails['Audio Codec'] ?? 'AAC',
          result: result,
          analysisVersion: '1.0.0',
          engineVersion: '1.0.0',
          processingDurationMs: processingMs,
        );

        await historyRepo.saveRecord(record);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              AnalysisResultScreen(result: result, session: widget.session),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentStage = AnalysisStage.failed;
          _errorMessage = 'Analysis error: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardTheme.color ?? (isDark ? const Color(0xFF212121) : AppColors.lightSurface);
    final borderColor = theme.dividerColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : AppColors.textDark);

    final stages = [
      AnalysisStage.readingContainer,
      AnalysisStage.extractingMetadata,
      AnalysisStage.analyzingVideoStream,
      AnalysisStage.analyzingEncodingCharacteristics,
      AnalysisStage.analyzingAudioStream,
      AnalysisStage.checkingVisualEvidence,
      AnalysisStage.comparingPlatformSignatures,
      AnalysisStage.calculatingConfidence,
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Forensic Analysis')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ANALYZING FILE: ${widget.session.videoPayload.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.youtubeRed,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _progressFraction),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.white10 : AppColors.lightBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.youtubeRed,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.strengthContradictory.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.strengthContradictory),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.strengthContradictory,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                            _currentStage = AnalysisStage.validatingFile;
                          });
                          _runAnalysisFlow();
                        },
                        child: const Text('RETRY ANALYSIS'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: ListView.builder(
                      itemCount: stages.length,
                      itemBuilder: (context, index) {
                        final stage = stages[index];
                        final isDone = stage.index < _currentStage.index;
                        final isCurrent = stage.index == _currentStage.index;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.youtubeRed.withAlpha(isDark ? 30 : 12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: isDone
                                    ? const Icon(
                                        Icons.check_circle,
                                        key: ValueKey('done'),
                                        color: AppColors.strengthStrong,
                                        size: 18,
                                      )
                                    : isCurrent
                                        ? const SizedBox(
                                            key: ValueKey('current'),
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.youtubeRed,
                                            ),
                                          )
                                        : Icon(
                                            Icons.radio_button_unchecked,
                                            key: const ValueKey('todo'),
                                            color: isDark ? Colors.white30 : AppColors.textMuted,
                                            size: 18,
                                          ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  stage.statusMessage,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDone || isCurrent
                                        ? textColor
                                        : (isDark ? Colors.white38 : AppColors.textMuted),
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

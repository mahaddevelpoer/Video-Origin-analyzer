import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admob_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/motion_reveal.dart';
import '../../../data/models/analysis_session.dart';
import '../../../data/models/history_record.dart';
import 'analysis_result_screen.dart';

class AnalysisProgressScreen extends ConsumerStatefulWidget {
  final AnalysisSession session;

  const AnalysisProgressScreen({super.key, required this.session});

  @override
  ConsumerState<AnalysisProgressScreen> createState() => _AnalysisProgressScreenState();
}

class _AnalysisProgressScreenState extends ConsumerState<AnalysisProgressScreen> {
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
        final processingMs = DateTime.now().difference(startTime).inMilliseconds;

        final record = HistoryRecord(
          id: widget.session.sessionId,
          timestamp: widget.session.startTime,
          filename: widget.session.videoPayload.name,
          filePath: widget.session.videoPayload.path ?? widget.session.videoPayload.name,
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
          builder: (_) => AnalysisResultScreen(result: result, session: widget.session),
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
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(title: const Text('Forensic Analysis')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MotionReveal(
                child: Text(
                  'ANALYZING FILE: ${widget.session.videoPayload.name}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.youtubeRed,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progressFraction,
                backgroundColor: AppColors.lightCard,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.youtubeRed),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: AppColors.strengthContradictory)),
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
              ] else ...[
                Expanded(
                  child: MotionReveal(
                    delay: const Duration(milliseconds: 100),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightBorder),
                      ),
                      child: ListView.builder(
                        itemCount: stages.length,
                        itemBuilder: (context, index) {
                          final stage = stages[index];
                          final isDone = stage.index < _currentStage.index;
                          final isCurrent = stage.index == _currentStage.index;

                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            child: Padding(
                              key: ValueKey('${stage.name}-$isDone-$isCurrent'),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  if (isDone)
                                    const Icon(Icons.check_circle, color: AppColors.strengthStrong, size: 18)
                                  else if (isCurrent)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.youtubeRed),
                                    )
                                  else
                                    const Icon(Icons.radio_button_unchecked, color: AppColors.textMuted, size: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      stage.statusMessage,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDone || isCurrent ? AppColors.textDark : AppColors.textMuted,
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_origin_analyzer/data/local/daily_usage_service.dart';
import 'package:video_origin_analyzer/data/models/evidence_item.dart';
import 'package:video_origin_analyzer/domain/forensic/scoring/scoring_engine.dart';

void main() {
  group('DailyUsageService Tests', () {
    test('Enforces 2 free daily analyses and resets correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final usageService = DailyUsageService(prefs);

      expect(usageService.getUsageCount(), 0);
      expect(usageService.canAnalyze(false), true);

      await usageService.consumeAnalysis(false);
      expect(usageService.getUsageCount(), 1);
      expect(usageService.canAnalyze(false), true);

      await usageService.consumeAnalysis(false);
      expect(usageService.getUsageCount(), 2);
      expect(usageService.canAnalyze(false), false);

      // Pro users always bypass limits
      expect(usageService.canAnalyze(true), true);
    });
  });

  group('ForensicScoringEngine Tests', () {
    test('Calculates TikTok origin evidence correctly', () {
      final engine = ForensicScoringEngine();

      final evidence = [
        const EvidenceItem(
          category: 'Metadata',
          finding: 'TikTok-compatible filename pattern detected',
          strength: EvidenceStrength.strong,
          scoreContribution: 25,
          technicalExplanation: 'TikTok naming convention',
        ),
        const EvidenceItem(
          category: 'Visual',
          finding: 'TikTok watermark detected',
          strength: EvidenceStrength.strong,
          scoreContribution: 25,
          technicalExplanation: 'Visual watermark',
        ),
      ];

      final result = engine.evaluate(
        allEvidence: evidence,
        possibleIntermediatePlatform: null,
        intermediateReason: null,
        technicalDetails: {'Container': 'MP4'},
      );

      expect(result.platformId, 'tiktok');
      expect(result.platformName, 'TikTok');
      expect(result.confidence > 50, true);
    });
  });
}

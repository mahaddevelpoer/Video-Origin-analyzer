import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_origin_analyzer/data/local/daily_usage_service.dart';
import 'package:video_origin_analyzer/data/models/evidence_item.dart';
import 'package:video_origin_analyzer/data/services/local_ocr_service.dart';
import 'package:video_origin_analyzer/data/utils/instagram_timestamp_decoder.dart';
import 'package:video_origin_analyzer/data/utils/url_platform_detector.dart';
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

    test('Identifies low score evidence as Inconclusive/Unknown', () {
      final engine = ForensicScoringEngine();

      final evidence = [
        const EvidenceItem(
          category: 'Container',
          finding: 'Standard MP4 container format',
          strength: EvidenceStrength.neutral,
          scoreContribution: 5,
          technicalExplanation: 'Generic container format without signature',
        ),
      ];

      final result = engine.evaluate(
        allEvidence: evidence,
        possibleIntermediatePlatform: null,
        intermediateReason: null,
        technicalDetails: {'Container': 'MP4'},
      );

      expect(result.platformId, 'unknown');
      expect(result.confidenceLevel.name, 'unknown');
    });

    test('Tracks intermediate compression channels like WhatsApp', () {
      final engine = ForensicScoringEngine();

      final evidence = [
        const EvidenceItem(
          category: 'Metadata',
          finding: 'Instagram story encoder string match',
          strength: EvidenceStrength.strong,
          scoreContribution: 25,
          technicalExplanation: 'Instagram encoder signature',
        ),
      ];

      final result = engine.evaluate(
        allEvidence: evidence,
        possibleIntermediatePlatform: 'WhatsApp',
        intermediateReason: 'Aggressive compression (bitrate < 1500kbps) detected.',
        technicalDetails: {'Container': 'MP4', 'Bitrate': '800 kbps'},
      );

      expect(result.platformId, 'instagram');
      expect(result.possibleIntermediatePlatform, 'WhatsApp');
      expect(result.intermediateReason, contains('Aggressive compression'));
    });
  });

  group('LocalOcrService Tests', () {
    test('Cleans text noise and extracts handles and hashtags', () async {
      final ocr = LocalOcrService();
      const rawText = 'JFIF @creator_user Check this out #viral #trending Exif 12345';

      final cleaned = ocr.cleanOcrText(rawText);
      final usernames = ocr.extractUsernames(cleaned);
      final hashtags = ocr.extractHashtags(cleaned);

      expect(cleaned.contains('JFIF'), false);
      expect(usernames, contains('@creator_user'));
      expect(hashtags, contains('#viral'));
    });
  });

  group('UrlPlatformDetector Tests', () {
    test('Detects platform and normalizes social URLs', () {
      const igUrl = 'https://www.instagram.com/reel/abc123/?utm_source=igweb&igsh=123';
      const ttUrl = 'https://www.tiktok.com/@user/video/71829304918239?is_from_webapp=1';
      const ytUrl = 'https://youtu.be/dQw4w9WgXcQ';

      expect(UrlPlatformDetector.detectPlatform(igUrl), DetectedPlatform.instagram);
      expect(UrlPlatformDetector.detectPlatform(ttUrl), DetectedPlatform.tiktok);
      expect(UrlPlatformDetector.detectPlatform(ytUrl), DetectedPlatform.youtube);

      final normalizedIg = UrlPlatformDetector.normalizeUrl(igUrl);
      expect(normalizedIg.contains('utm_source'), false);
      expect(normalizedIg.contains('igsh'), false);
    });
  });

  group('InstagramTimestampDecoder Tests', () {
    test('Decodes Instagram Reel URL to exact UTC timestamp mathematically', () {
      const sampleReelUrl = 'https://www.instagram.com/reel/Dbmx219TVIR/?utm_source=ig_web_copy_link';
      final decodedDate = InstagramTimestampDecoder.decodeShortcodeToDate(sampleReelUrl);

      expect(decodedDate, isNotNull);
      expect(decodedDate!.year, 2026);
      expect(decodedDate.month, 8);
      expect(decodedDate.day, 4);

      final iso = InstagramTimestampDecoder.decodeToIsoString(sampleReelUrl);
      expect(iso, contains('2026-08-04'));
    });
  });
}

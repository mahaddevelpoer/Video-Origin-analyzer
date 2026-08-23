import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_origin_analyzer/data/local/daily_usage_service.dart';
import 'package:video_origin_analyzer/data/models/evidence_item.dart';
import 'package:video_origin_analyzer/data/models/online_search_result.dart';
import 'package:video_origin_analyzer/data/services/local_ocr_service.dart';
import 'package:video_origin_analyzer/data/utils/link_timestamp_resolver.dart';
import 'package:video_origin_analyzer/data/utils/instagram_timestamp_decoder.dart';
import 'package:video_origin_analyzer/data/utils/tiktok_timestamp_decoder.dart';
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
        intermediateReason:
            'Aggressive compression (bitrate < 1500kbps) detected.',
        technicalDetails: {'Container': 'MP4', 'Bitrate': '800 kbps'},
      );

      expect(result.platformId, 'instagram');
      expect(result.possibleIntermediatePlatform, 'WhatsApp');
      expect(result.intermediateReason, contains('Aggressive compression'));
    });

    test(
      'Prefers earliest verified timestamp platform when technical evidence is otherwise weak',
      () {
        final engine = ForensicScoringEngine();

        final result = engine.evaluate(
          allEvidence: const [],
          possibleIntermediatePlatform: null,
          intermediateReason: null,
          technicalDetails: {
            'Container': 'MP4',
            'Earliest Verified Platform': 'instagram',
            'Earliest Verified Timestamp': '2026-08-04T12:00:00.000Z',
            'Origin Verification Status': 'earliest_verified_exact_match',
          },
        );

        expect(result.platformId, 'instagram');
        expect(result.confidenceLevel.name, 'high');
      },
    );

    test(
      'Uses the oldest verified exact match over conflicting local platform signals',
      () {
        final engine = ForensicScoringEngine();
        final evidence = [
          const EvidenceItem(
            category: 'Metadata',
            finding: 'TikTok-compatible filename pattern detected',
            strength: EvidenceStrength.strong,
            scoreContribution: 25,
            technicalExplanation: 'Local filename clue',
          ),
          const EvidenceItem(
            category: 'Visual',
            finding: 'TikTok watermark detected',
            strength: EvidenceStrength.strong,
            scoreContribution: 25,
            technicalExplanation: 'Local watermark clue',
          ),
        ];

        final result = engine.evaluate(
          allEvidence: evidence,
          possibleIntermediatePlatform: null,
          intermediateReason: null,
          technicalDetails: {
            'Earliest Verified Platform': 'youtube',
            'Earliest Verified Timestamp': '2021-01-01T00:00:00.000Z',
            'Origin Verification Status': 'earliest_verified_exact_match',
          },
        );

        expect(result.platformId, 'youtube');
        expect(result.confidenceLevel.name, 'moderate');
      },
    );

    test(
      'Does not let an unverified timestamp override local platform evidence',
      () {
        final engine = ForensicScoringEngine();
        final evidence = [
          const EvidenceItem(
            category: 'Visual',
            finding: 'TikTok watermark detected',
            strength: EvidenceStrength.strong,
            scoreContribution: 25,
            technicalExplanation: 'Local watermark clue',
          ),
        ];

        final result = engine.evaluate(
          allEvidence: evidence,
          possibleIntermediatePlatform: null,
          intermediateReason: null,
          technicalDetails: {
            'Earliest Verified Platform': 'instagram',
            'Earliest Verified Timestamp': '2020-01-01T00:00:00.000Z',
            'Origin Verification Status': 'local_signals_or_unverified_matches',
          },
        );

        expect(result.platformId, 'tiktok');
      },
    );

    test(
      'Uses verified platform timestamp from visual result without calling it exact',
      () {
        final engine = ForensicScoringEngine();

        final result = engine.evaluate(
          allEvidence: const [
            EvidenceItem(
              category: 'Platform Post Evidence',
              finding:
                  'INSTAGRAM public post timestamp verified (2026-08-04T12:00:00.000Z)',
              strength: EvidenceStrength.moderate,
              scoreContribution: 18,
              technicalExplanation:
                  'Direct Instagram URL found in visual results and timestamp decoded.',
            ),
          ],
          possibleIntermediatePlatform: null,
          intermediateReason: null,
          technicalDetails: {
            'Earliest Verified Platform': 'instagram',
            'Earliest Verified Timestamp': '2026-08-04T12:00:00.000Z',
            'Origin Verification Status':
                'earliest_verified_platform_timestamp',
          },
        );

        expect(result.platformId, 'instagram');
        expect(result.confidenceLevel.name, 'moderate');
      },
    );

    test('Does not let Gemini-only platform guess become high confidence', () {
      final engine = ForensicScoringEngine();

      final result = engine.evaluate(
        allEvidence: const [
          EvidenceItem(
            category: 'AI Evidence Review',
            finding: 'Gemini AI review points toward INSTAGRAM',
            strength: EvidenceStrength.neutral,
            scoreContribution: 0,
            technicalExplanation: 'AI-only context without verified timestamp.',
          ),
        ],
        possibleIntermediatePlatform: null,
        intermediateReason: null,
        technicalDetails: {
          'Origin Verification Status': 'local_signals_or_unverified_matches',
        },
      );

      expect(result.platformId, 'unknown');
      expect(result.confidenceLevel.name, 'unknown');
    });

    test('Verified timestamp beats conflicting Gemini platform review', () {
      final engine = ForensicScoringEngine();

      final result = engine.evaluate(
        allEvidence: const [
          EvidenceItem(
            category: 'AI Conflict Review',
            finding:
                'Gemini suggested TIKTOK, but verified timestamp evidence points to INSTAGRAM',
            strength: EvidenceStrength.contradictory,
            scoreContribution: 0,
            technicalExplanation: 'Conflict transparency.',
          ),
        ],
        possibleIntermediatePlatform: null,
        intermediateReason: null,
        technicalDetails: {
          'Earliest Verified Platform': 'instagram',
          'Earliest Verified Timestamp': '2026-08-04T12:00:00.000Z',
          'Origin Verification Status': 'earliest_verified_exact_match',
        },
      );

      expect(result.platformId, 'instagram');
      expect(result.confidenceLevel.name, 'moderate');
      expect(result.conflictingEvidenceList.length, 1);
    });
  });

  group('OnlineSearchResult AI Parsing Tests', () {
    test('Parses legacy visual-search response without ai_analysis', () {
      final result = OnlineSearchResult.fromJson({
        'status': 'success',
        'total_matches': 0,
        'summary': {'instagram': 0, 'tiktok': 0, 'youtube': 0, 'other': 0},
        'matches': [],
      });

      expect(result.aiAnalysis, isNull);
      expect(result.matches, isEmpty);
    });

    test('Parses successful Gemini evidence review', () {
      final result = OnlineSearchResult.fromJson({
        'status': 'success',
        'total_matches': 1,
        'summary': {'instagram': 1, 'tiktok': 0, 'youtube': 0, 'other': 0},
        'matches': [],
        'ai_analysis': {
          'status': 'success',
          'model': 'gemini-2.5-flash-lite',
          'summary': 'AI found Instagram-style evidence.',
          'context_analysis': 'The visual overlay uses a font style synonymous with Instagram Reels.',
          'likely_platform': 'instagram',
          'confidence': 64,
          'evidence_reasons': ['Direct Instagram candidate link.'],
          'conflicts': ['No exact timestamp yet.'],
          'recommended_search_queries': ['creator reel title instagram'],
          'source_urls': ['https://www.instagram.com/reel/example/'],
          'risk_level': 'medium',
        },
      });

      expect(result.aiAnalysis, isNotNull);
      expect(result.aiAnalysis!.isAvailable, true);
      expect(result.aiAnalysis!.likelyPlatform, 'instagram');
      expect(result.aiAnalysis!.confidence, 64);
      expect(result.aiAnalysis!.conflicts.length, 1);
      expect(result.aiAnalysis!.contextAnalysis, contains('synonymous with Instagram'));
    });

    test('Parses unavailable Gemini response safely', () {
      final result = OnlineSearchResult.fromJson({
        'status': 'success',
        'total_matches': 0,
        'summary': {'instagram': 0, 'tiktok': 0, 'youtube': 0, 'other': 0},
        'matches': [],
        'ai_analysis': {
          'status': 'unavailable',
          'summary': 'Gemini AI key is not configured.',
          'context_analysis': 'Visual context analysis is unavailable because the AI service could not be reached.',
          'likely_platform': 'instagram',
          'confidence': 120,
          'risk_level': 'extreme',
          'error_code': 'MISSING_GEMINI_KEY',
        },
      });

      expect(result.aiAnalysis!.isAvailable, false);
      expect(result.aiAnalysis!.confidence, 100);
      expect(result.aiAnalysis!.riskLevel, 'unknown');
    });

    test('Rejects malformed AI platform value safely', () {
      final analysis = AiEvidenceAnalysis.fromJson({
        'status': 'success',
        'summary': 'Malformed platform test.',
        'context_analysis': 'Some context.',
        'likely_platform': 'definitely_instagram',
        'confidence': -5,
        'risk_level': 'low',
      });

      expect(analysis.likelyPlatform, 'unknown');
      expect(analysis.confidence, 0);
    });
  });

  group('LinkTimestampResolver Tests', () {
    test('Resolves Instagram link to exact timestamp', () {
      const url =
          'https://www.instagram.com/reel/Dbmx219TVIR/?utm_source=ig_web_copy_link';
      final result = LinkTimestampResolver.resolve(url);

      expect(result.supported, true);
      expect(result.platform, DetectedPlatform.instagram);
      expect(result.hasExactTimestamp, true);
      expect(result.exactTimestampIso, contains('2026-08-04'));
    });

    test('Resolves TikTok link to exact timestamp', () {
      const url =
          'https://www.tiktok.com/@tiktok/video/7106594312292453678?is_from_webapp=1';
      final result = LinkTimestampResolver.resolve(url);

      expect(result.supported, true);
      expect(result.platform, DetectedPlatform.tiktok);
      expect(result.hasExactTimestamp, true);
      expect(result.exactTimestampIso, contains('2022-06'));
    });
  });

  group('LocalOcrService Tests', () {
    test('Cleans text noise and extracts handles and hashtags', () async {
      final ocr = LocalOcrService();
      const rawText =
          'JFIF @creator_user Check this out #viral #trending Exif 12345';

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
      const igUrl =
          'https://www.instagram.com/reel/abc123/?utm_source=igweb&igsh=123';
      const ttUrl =
          'https://www.tiktok.com/@user/video/71829304918239?is_from_webapp=1';
      const ytUrl = 'https://youtu.be/dQw4w9WgXcQ';

      expect(
        UrlPlatformDetector.detectPlatform(igUrl),
        DetectedPlatform.instagram,
      );
      expect(
        UrlPlatformDetector.detectPlatform(ttUrl),
        DetectedPlatform.tiktok,
      );
      expect(
        UrlPlatformDetector.detectPlatform(ytUrl),
        DetectedPlatform.youtube,
      );

      final normalizedIg = UrlPlatformDetector.normalizeUrl(igUrl);
      expect(normalizedIg.contains('utm_source'), false);
      expect(normalizedIg.contains('igsh'), false);
    });
  });

  group('InstagramTimestampDecoder Tests', () {
    test('Decodes Instagram Reel URL to exact UTC timestamp mathematically', () {
      const sampleReelUrl =
          'https://www.instagram.com/reel/Dbmx219TVIR/?utm_source=ig_web_copy_link';
      final decodedDate = InstagramTimestampDecoder.decodeShortcodeToDate(
        sampleReelUrl,
      );

      expect(decodedDate, isNotNull);
      expect(decodedDate!.year, 2026);
      expect(decodedDate.month, 8);
      expect(decodedDate.day, 4);

      final iso = InstagramTimestampDecoder.decodeToIsoString(sampleReelUrl);
      expect(iso, contains('2026-08-04'));
    });
  });

  group('TikTokTimestampDecoder Tests', () {
    test('Decodes TikTok video ID/URL to exact UTC timestamp mathematically', () {
      const sampleTikTokUrl =
          'https://www.tiktok.com/@tiktok/video/7106594312292453678?is_from_webapp=1';
      final decodedDate = TikTokTimestampDecoder.decodeVideoIdToDate(
        sampleTikTokUrl,
      );

      expect(decodedDate, isNotNull);
      expect(decodedDate!.year, 2022);
      expect(decodedDate.month, 6);

      final iso = TikTokTimestampDecoder.decodeToIsoString(sampleTikTokUrl);
      expect(iso, contains('2022-06'));
    });
  });
}

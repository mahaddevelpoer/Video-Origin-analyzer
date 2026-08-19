import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/input_video_payload.dart';
import '../models/online_search_result.dart';
import 'frame_extractor_service.dart';

class OnlineVisualSearchService {
  static const String supabaseProjectUrl =
      'https://stgifkztggudpvshfewk.supabase.co';
  static const String functionEndpoint =
      '$supabaseProjectUrl/functions/v1/visual-search';

  final FrameExtractorService _frameExtractor;

  OnlineVisualSearchService({FrameExtractorService? frameExtractor})
      : _frameExtractor = frameExtractor ?? FrameExtractorService();

  /// Perform smart visual search over extracted representative video frames.
  /// Searches best frame (center) first; checks frequency across TikTok, Instagram, YouTube, Facebook.
  Future<OnlineSearchResult> performVisualSearch(
    InputVideoPayload payload, {
    String? ocrQuery,
  }) async {
    try {
      final frames = await _frameExtractor.extractRepresentativeFrames(payload);
      if (frames.isEmpty) {
        return OnlineSearchResult.failure(
          message: 'No suitable video frames could be extracted for visual search.',
          code: 'NO_FRAMES',
        );
      }

      OnlineSearchResult lastResult = OnlineSearchResult.failure(
        message: 'Visual search initialization pending.',
      );

      final accumulatedMatches = <OnlineMatchItem>[];
      final platformFrequency = <String, int>{
        'instagram': 0,
        'tiktok': 0,
        'youtube': 0,
        'other': 0,
      };

      for (final frame in frames) {
        debugPrint('Querying Supabase Edge Function visual-search for ${frame.position.name} frame...');

        final result = await _sendFrameToEdgeFunction(frame.base64Jpeg, ocrQuery: ocrQuery);
        lastResult = result;

        if (result.isSuccess && result.matches.isNotEmpty) {
          accumulatedMatches.addAll(result.matches);
          result.summary.forEach((key, count) {
            if (platformFrequency.containsKey(key)) {
              platformFrequency[key] = (platformFrequency[key] ?? 0) + count;
            } else {
              platformFrequency['other'] = (platformFrequency['other'] ?? 0) + count;
            }
          });

          final hasDominant = platformFrequency.entries
              .where((e) => e.key != 'other')
              .any((e) => e.value >= 2);

          if (hasDominant) {
            debugPrint('Dominant platform frequency detected across frames. Stopping further searches.');
            break;
          }
        }

        if (result.errorCode == 'HTTP_404' ||
            result.errorCode == 'MISSING_SERPAPI_KEY' ||
            result.errorCode == 'SERPAPI_UPLOAD_FAILED') {
          break;
        }
      }

      if (accumulatedMatches.isNotEmpty) {
        final uniqueMatches = <String, OnlineMatchItem>{};
        for (final match in accumulatedMatches) {
          final key = match.link.isNotEmpty ? match.link : '${match.title}|${match.classifiedPlatform}';
          final existing = uniqueMatches[key];
          if (existing == null || (match.matchType == 'exact_match' && existing.matchType != 'exact_match')) {
            uniqueMatches[key] = match;
          }
        }
        final matches = uniqueMatches.values.toList();
        return OnlineSearchResult(
          status: 'success',
          totalMatches: matches.length,
          summary: {
            for (final platform in platformFrequency.keys)
              platform: matches.where((m) => m.classifiedPlatform == platform).length,
          },
          matches: matches,
        );
      }

      return lastResult;
    } catch (e) {
      debugPrint('OnlineVisualSearchService Exception: $e');
      return OnlineSearchResult.failure(
        message: 'Visual search could not be verified. Local forensic analysis is still available.',
        code: 'VISUAL_SEARCH_UNAVAILABLE',
      );
    }
  }

  Future<OnlineSearchResult> _sendFrameToEdgeFunction(String base64Jpeg, {String? ocrQuery}) async {
    try {
      final response = await http
          .post(
            Uri.parse(functionEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'image_base64': base64Jpeg,
              'max_results': 10,
              if (ocrQuery != null && ocrQuery.isNotEmpty) 'ocr_query': ocrQuery,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        return OnlineSearchResult.fromJson(jsonMap);
      } else if (response.statusCode == 404) {
        return OnlineSearchResult.failure(
          message: 'Online visual search proxy pending deployment on Supabase. Local multi-signal forensic engine completed successfully.',
          code: 'HTTP_404',
        );
      } else {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>?;
        final errMsg = jsonMap?['error'] ?? 'Edge Function status ${response.statusCode}';
        final errCode = jsonMap?['code'] ?? 'HTTP_${response.statusCode}';

        return OnlineSearchResult.failure(
          message: errMsg.toString(),
          code: errCode.toString(),
        );
      }
    } on TimeoutException {
      return OnlineSearchResult.failure(
        message: 'Supabase Edge Function timed out after 12s.',
        code: 'TIMEOUT',
      );
    } catch (e) {
      return OnlineSearchResult.failure(
        message: 'Network connection unavailable for online visual search.',
        code: 'CONNECTION_FAILED',
      );
    }
  }

  @Deprecated('Do not use unverified demo matches as forensic evidence.')
  OnlineSearchResult _getFallbackDemoSearchResult(InputVideoPayload payload, {String? ocrQuery}) {
    final lowerName = payload.name.toLowerCase();
    String detectedPlatform = 'tiktok';
    if (lowerName.contains('ig') || lowerName.contains('reel') || lowerName.contains('instagram')) {
      detectedPlatform = 'instagram';
    } else if (lowerName.contains('yt') || lowerName.contains('youtube') || lowerName.contains('shorts')) {
      detectedPlatform = 'youtube';
    }

    final matches = <OnlineMatchItem>[];
    if (detectedPlatform == 'tiktok') {
      matches.addAll([
        const OnlineMatchItem(
          position: 1,
          title: 'Original Video Post on TikTok',
          link: 'https://www.tiktok.com/@creator/video/71829304918239',
          domain: 'tiktok.com',
          classifiedPlatform: 'tiktok',
          source: 'TikTok',
          matchType: 'exact_match',
          date: 'August 10, 2026',
          dateConfidence: DateConfidence.high,
          snippet: 'Original upload containing high resolution video post',
        ),
        const OnlineMatchItem(
          position: 2,
          title: 'Reposted Short Reel on Instagram',
          link: 'https://www.instagram.com/reels/Cj81923kLA/',
          domain: 'instagram.com',
          classifiedPlatform: 'instagram',
          source: 'Instagram',
          matchType: 'visual_match',
          date: 'August 13, 2026',
          dateConfidence: DateConfidence.medium,
          snippet: 'Reposted video clip with Instagram watermark sticker',
        ),
      ]);
    } else if (detectedPlatform == 'instagram') {
      matches.addAll([
        const OnlineMatchItem(
          position: 1,
          title: 'Original Reel on Instagram',
          link: 'https://www.instagram.com/reels/Ck91023mNB/',
          domain: 'instagram.com',
          classifiedPlatform: 'instagram',
          source: 'Instagram',
          matchType: 'exact_match',
          date: 'August 08, 2026',
          dateConfidence: DateConfidence.high,
          snippet: 'Original instagram reel uploaded by creator',
        ),
        const OnlineMatchItem(
          position: 2,
          title: 'Shared Video Clip on YouTube Shorts',
          link: 'https://www.youtube.com/shorts/x81923kLA',
          domain: 'youtube.com',
          classifiedPlatform: 'youtube',
          source: 'YouTube',
          matchType: 'visual_match',
          date: 'August 14, 2026',
          dateConfidence: DateConfidence.medium,
          snippet: 'Shorts clip posted matching original visual scene',
        ),
      ]);
    } else {
      matches.addAll([
        const OnlineMatchItem(
          position: 1,
          title: 'Original Video Upload on YouTube',
          link: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          domain: 'youtube.com',
          classifiedPlatform: 'youtube',
          source: 'YouTube',
          matchType: 'exact_match',
          date: 'August 05, 2026',
          dateConfidence: DateConfidence.high,
          snippet: 'Original high definition video uploaded on YouTube channel',
        ),
        const OnlineMatchItem(
          position: 2,
          title: 'Trending Short on TikTok',
          link: 'https://www.tiktok.com/@user/video/729102930192',
          domain: 'tiktok.com',
          classifiedPlatform: 'tiktok',
          source: 'TikTok',
          matchType: 'visual_match',
          date: 'August 11, 2026',
          dateConfidence: DateConfidence.medium,
          snippet: 'Trending video clip shared on TikTok',
        ),
      ]);
    }

    final summary = <String, int>{
      'instagram': matches.where((m) => m.classifiedPlatform == 'instagram').length,
      'tiktok': matches.where((m) => m.classifiedPlatform == 'tiktok').length,
      'youtube': matches.where((m) => m.classifiedPlatform == 'youtube').length,
      'other': 0,
    };

    return OnlineSearchResult(
      status: 'success',
      totalMatches: matches.length,
      summary: summary,
      matches: matches,
    );
  }
}

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

}

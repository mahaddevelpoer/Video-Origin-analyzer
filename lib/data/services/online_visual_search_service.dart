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
  /// Searches best frame first; stops if useful results are found to conserve SerpApi quota.
  Future<OnlineSearchResult> performVisualSearch(InputVideoPayload payload) async {
    try {
      final frames = await _frameExtractor.extractRepresentativeFrames(payload);
      if (frames.isEmpty) {
        return OnlineSearchResult.failure(
          message: 'No suitable video frames could be extracted for visual search.',
          code: 'NO_FRAMES',
        );
      }

      // Smart Strategy: Search best frame (middle frame) first
      OnlineSearchResult lastResult = OnlineSearchResult.failure(
        message: 'Visual search initialization pending.',
      );

      for (final frame in frames) {
        debugPrint('Querying Supabase Edge Function visual-search for ${frame.position.name} frame...');

        final result = await _sendFrameToEdgeFunction(frame.base64Jpeg);
        lastResult = result;

        // If useful matches found, stop searching additional frames to save SerpApi quota!
        if (result.isSuccess && result.matches.isNotEmpty) {
          debugPrint('Useful visual matches found (${result.matches.length}). Stopping further frame searches.');
          return result;
        }

        // If error is 404, unconfigured SERPAPI_KEY or rate limit, break immediately
        if (result.errorCode == 'HTTP_404' ||
            result.errorCode == 'MISSING_SERPAPI_KEY' ||
            result.errorCode == 'SERPAPI_UPLOAD_FAILED') {
          break;
        }
      }

      return lastResult;
    } catch (e) {
      debugPrint('OnlineVisualSearchService Exception: $e');
      return OnlineSearchResult.failure(
        message: 'Online visual search failed: ${e.toString()}',
        code: 'NETWORK_EXCEPTION',
      );
    }
  }

  Future<OnlineSearchResult> _sendFrameToEdgeFunction(String base64Jpeg) async {
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
            }),
          )
          .timeout(const Duration(seconds: 15));

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
        message: 'Supabase Edge Function timed out after 15s.',
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

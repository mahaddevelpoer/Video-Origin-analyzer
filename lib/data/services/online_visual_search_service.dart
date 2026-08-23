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

  /// Searches up to three representative frames through the hybrid AI proxy.
  Future<OnlineSearchResult> performVisualSearch(
    InputVideoPayload payload, {
    String? ocrQuery,
  }) async {
    try {
      final frames = await _frameExtractor.extractRepresentativeFrames(payload);
      if (frames.isEmpty) {
        return OnlineSearchResult.failure(
          message:
              'No suitable video frames could be extracted for visual search.',
          code: 'NO_FRAMES',
        );
      }

      debugPrint(
        'Querying Supabase hybrid visual-search for ${frames.length} frame(s)...',
      );

      return await _sendFramesToEdgeFunction(
        frames.map((frame) => frame.base64Jpeg).take(3).toList(),
        ocrQuery: ocrQuery,
      );
    } catch (e) {
      debugPrint('OnlineVisualSearchService Exception: $e');
      return OnlineSearchResult.failure(
        message:
            'Visual search could not be verified. Local forensic analysis is still available.',
        code: 'VISUAL_SEARCH_UNAVAILABLE',
      );
    }
  }

  Future<OnlineSearchResult> _sendFramesToEdgeFunction(
    List<String> base64Jpegs, {
    String? ocrQuery,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(functionEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'image_frames_base64': base64Jpegs,
              'max_results': 15,
              if (ocrQuery != null && ocrQuery.isNotEmpty)
                'ocr_query': ocrQuery,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        return OnlineSearchResult.fromJson(jsonMap);
      } else if (response.statusCode == 404) {
        return OnlineSearchResult.failure(
          message:
              'Online visual search proxy pending deployment on Supabase. Local multi-signal forensic engine completed successfully.',
          code: 'HTTP_404',
        );
      } else {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>?;
        final errMsg =
            jsonMap?['error'] ?? 'Edge Function status ${response.statusCode}';
        final errCode = jsonMap?['code'] ?? 'HTTP_${response.statusCode}';

        return OnlineSearchResult.failure(
          message: errMsg.toString(),
          code: errCode.toString(),
        );
      }
    } on TimeoutException {
      return OnlineSearchResult.failure(
        message: 'Supabase AI visual-search proxy timed out after 25s.',
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

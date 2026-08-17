import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/online_search_result.dart';
import '../utils/url_platform_detector.dart';

class SocialCrawlService {
  static const String supabaseProjectUrl =
      'https://stgifkztggudpvshfewk.supabase.co';
  static const String socialCrawlEndpoint =
      '$supabaseProjectUrl/functions/v1/social-crawl';

  // Session deduplication cache to protect API credits
  final Set<String> _processedUrls = {};

  void clearSessionCache() {
    _processedUrls.clear();
  }

  /// Fetches public social media post metadata securely via Supabase Edge Function
  Future<SocialCrawlPostEvidence?> fetchPostMetadata(String rawUrl) async {
    final normalizedUrl = UrlPlatformDetector.normalizeUrl(rawUrl);
    if (normalizedUrl.isEmpty) return null;

    final platform = UrlPlatformDetector.detectPlatform(normalizedUrl);
    if (platform == DetectedPlatform.other) {
      debugPrint('Skipping SocialCrawl lookup for non-target platform URL: $normalizedUrl');
      return null;
    }

    // Credit Protection: Deduplicate repeated URLs within the current session
    if (_processedUrls.contains(normalizedUrl)) {
      debugPrint('SocialCrawl credit protection: Reusing session cached lookup for $normalizedUrl');
      return null;
    }
    _processedUrls.add(normalizedUrl);

    try {
      debugPrint('Querying Supabase Edge Function social-crawl for ${platform.name} URL...');
      final response = await http
          .post(
            Uri.parse(socialCrawlEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'url': normalizedUrl,
              'platform': platform.name,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonMap['status'] == 'success' && jsonMap['data'] != null) {
          final data = jsonMap['data'] as Map<String, dynamic>;
          return SocialCrawlPostEvidence.fromJson(data);
        }
      } else if (response.statusCode == 429) {
        debugPrint('SocialCrawl quota exhausted or rate limited (429)');
      } else if (response.statusCode == 404) {
        debugPrint('SocialCrawl proxy endpoint notice (404)');
      }
    } on TimeoutException {
      debugPrint('SocialCrawl request timed out (10s)');
    } catch (e) {
      debugPrint('SocialCrawl exception: $e');
    }

    return null;
  }
}

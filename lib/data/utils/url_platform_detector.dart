import 'package:flutter/foundation.dart';

enum DetectedPlatform { instagram, tiktok, youtube, other }

class UrlPlatformDetector {
  /// Detect platform from URL domain
  static DetectedPlatform detectPlatform(String url) {
    if (url.isEmpty) return DetectedPlatform.other;
    final lower = url.toLowerCase().trim();

    if (lower.contains('instagram.com') || lower.contains('instagr.am')) {
      return DetectedPlatform.instagram;
    }
    if (lower.contains('tiktok.com')) {
      return DetectedPlatform.tiktok;
    }
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return DetectedPlatform.youtube;
    }

    return DetectedPlatform.other;
  }

  /// Clean and normalize social media URL for deduplication and API requests
  static String normalizeUrl(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    try {
      final uri = Uri.parse(rawUrl.trim());
      // Reconstruct clean URI without tracking query parameters (e.g. utm_, igsh, share_id)
      final cleanQueryParameters = <String, String>{};
      uri.queryParameters.forEach((key, value) {
        final k = key.toLowerCase();
        if (!k.startsWith('utm_') && k != 'igsh' && k != 'share_id' && k != 's' && k != 't') {
          cleanQueryParameters[key] = value;
        }
      });

      final cleanUri = Uri(
        scheme: uri.scheme.isNotEmpty ? uri.scheme : 'https',
        host: uri.host.toLowerCase(),
        path: uri.path,
        queryParameters: cleanQueryParameters.isNotEmpty ? cleanQueryParameters : null,
      );

      return cleanUri.toString();
    } catch (e) {
      debugPrint('URL normalization error: $e');
      return rawUrl.trim();
    }
  }
}

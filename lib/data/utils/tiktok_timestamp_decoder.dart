import 'package:flutter/foundation.dart';

/// Decodes TikTok video IDs (Snowflake IDs) to extract exact publication timestamps
/// mathematically without consuming any API credits or making network calls.
///
/// Algorithm:
/// 1. Extract numeric video ID from URL (/video/1234567890...) or direct ID string
/// 2. Convert to BigInt (64-bit TikTok snowflake ID)
/// 3. Bitwise right-shift 32 bits (video_id >> 32)
/// 4. Result: Exact UTC creation timestamp in seconds.
class TikTokTimestampDecoder {
  static final RegExp _videoIdRegex = RegExp(r'/video/(\d+)');
  static final RegExp _numericRegex = RegExp(r'^\d+$');

  /// Extract numeric TikTok video ID from URL or ID string
  static String? extractVideoId(String urlOrId) {
    if (urlOrId.isEmpty) return null;
    final trimmed = urlOrId.trim();

    final match = _videoIdRegex.firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    if (_numericRegex.hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }

  /// Decode TikTok ID into exact UTC DateTime
  static DateTime? decodeVideoIdToDate(String urlOrId) {
    final videoIdStr = extractVideoId(urlOrId);
    if (videoIdStr == null) return null;

    try {
      final videoId = BigInt.parse(videoIdStr);
      // Bitwise right-shift 32 bits to get Unix timestamp (seconds)
      final unixTimestampSeconds = (videoId >> 32).toInt();

      if (unixTimestampSeconds <= 0) return null;

      return DateTime.fromMillisecondsSinceEpoch(
        unixTimestampSeconds * 1000,
        isUtc: true,
      );
    } catch (e) {
      debugPrint('TikTokTimestampDecoder error: $e');
      return null;
    }
  }

  /// Decode TikTok URL or ID into formatted ISO timestamp string
  static String? decodeToIsoString(String urlOrId) {
    final dt = decodeVideoIdToDate(urlOrId);
    return dt?.toIso8601String();
  }
}

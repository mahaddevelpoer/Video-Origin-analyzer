import 'package:flutter/foundation.dart';

/// Decodes Instagram media shortcodes (Reels, Posts, IGTV) to extract exact publication timestamps
/// mathematically without consuming any API credits or requiring network calls.
/// 
/// Algorithm:
/// 1. Extract shortcode from URL tokens (/reel/, /p/, /reels/, /tv/)
/// 2. Convert base64-style custom alphabet to BigInt (Instagram Snowflake Media ID)
/// 3. Bitwise right-shift 23 bits + Instagram Epoch offset (1314220021721 ms)
/// 4. Result: Exact UTC creation timestamp in milliseconds.
class InstagramTimestampDecoder {
  static const String _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  static final BigInt _base64BigInt = BigInt.from(64);
  static const int _instagramEpochMs = 1314220021721;

  /// Extract the Instagram media shortcode from a full URL or direct shortcode
  static String? extractShortcode(String url) {
    if (url.isEmpty) return null;
    final cleaned = url.trim();

    for (final token in ['/p/', '/reel/', '/reels/', '/tv/']) {
      if (cleaned.contains(token)) {
        try {
          final afterToken = cleaned.split(token)[1];
          final shortcode = afterToken.split('/')[0].split('?')[0].split('#')[0].trim();
          if (shortcode.isNotEmpty) return shortcode;
        } catch (_) {}
      }
    }

    // Direct shortcode string check
    if (!cleaned.contains('/') && !cleaned.contains('.')) {
      return cleaned;
    }

    return null;
  }

  /// Decode shortcode directly into a DateTime (UTC)
  static DateTime? decodeShortcodeToDate(String shortcodeOrUrl) {
    final shortcode = extractShortcode(shortcodeOrUrl) ?? shortcodeOrUrl.trim();
    if (shortcode.isEmpty) return null;

    try {
      BigInt n = BigInt.zero;
      for (int i = 0; i < shortcode.length; i++) {
        final char = shortcode[i];
        final idx = _alphabet.indexOf(char);
        if (idx == -1) {
          debugPrint('InstagramTimestampDecoder: Invalid character in shortcode: $char');
          return null;
        }
        n = (n * _base64BigInt) + BigInt.from(idx);
      }

      // Bitwise right shift 23 bits + Instagram Epoch (1314220021721)
      final timestampMs = (n >> 23).toInt() + _instagramEpochMs;
      return DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true);
    } catch (e) {
      debugPrint('InstagramTimestampDecoder error: $e');
      return null;
    }
  }

  /// Decode URL or shortcode to formatted ISO string
  static String? decodeToIsoString(String shortcodeOrUrl) {
    final dt = decodeShortcodeToDate(shortcodeOrUrl);
    return dt?.toIso8601String();
  }
}

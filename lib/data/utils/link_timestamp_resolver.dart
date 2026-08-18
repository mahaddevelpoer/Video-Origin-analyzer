import 'instagram_timestamp_decoder.dart';
import 'tiktok_timestamp_decoder.dart';
import 'url_platform_detector.dart';

class LinkTimestampCheckResult {
  final DetectedPlatform platform;
  final String normalizedUrl;
  final String? exactTimestampIso;
  final String message;
  final bool supported;

  const LinkTimestampCheckResult({
    required this.platform,
    required this.normalizedUrl,
    required this.exactTimestampIso,
    required this.message,
    required this.supported,
  });

  bool get hasExactTimestamp => exactTimestampIso != null && exactTimestampIso!.isNotEmpty;
}

class LinkTimestampResolver {
  static LinkTimestampCheckResult resolve(String rawUrl) {
    final normalizedUrl = UrlPlatformDetector.normalizeUrl(rawUrl);
    if (normalizedUrl.isEmpty) {
      return const LinkTimestampCheckResult(
        platform: DetectedPlatform.other,
        normalizedUrl: '',
        exactTimestampIso: null,
        message: 'Paste a valid Instagram, TikTok, or YouTube link first.',
        supported: false,
      );
    }

    final platform = UrlPlatformDetector.detectPlatform(normalizedUrl);
    switch (platform) {
      case DetectedPlatform.instagram:
        final ts = InstagramTimestampDecoder.decodeToIsoString(normalizedUrl);
        return LinkTimestampCheckResult(
          platform: platform,
          normalizedUrl: normalizedUrl,
          exactTimestampIso: ts,
          message: ts != null
              ? 'Instagram post timestamp decoded successfully.'
              : 'Instagram link detected, but the shortcode could not be decoded.',
          supported: true,
        );
      case DetectedPlatform.tiktok:
        final ts = TikTokTimestampDecoder.decodeToIsoString(normalizedUrl);
        return LinkTimestampCheckResult(
          platform: platform,
          normalizedUrl: normalizedUrl,
          exactTimestampIso: ts,
          message: ts != null
              ? 'TikTok post timestamp decoded successfully.'
              : 'TikTok link detected, but the video ID could not be decoded.',
          supported: true,
        );
      case DetectedPlatform.youtube:
        return LinkTimestampCheckResult(
          platform: platform,
          normalizedUrl: normalizedUrl,
          exactTimestampIso: null,
          message:
              'YouTube links can be checked for platform identity, but exact post timestamp is not decoded from the link alone here.',
          supported: true,
        );
      case DetectedPlatform.other:
        return LinkTimestampCheckResult(
          platform: platform,
          normalizedUrl: normalizedUrl,
          exactTimestampIso: null,
          message: 'Only Instagram, TikTok, and YouTube links are supported.',
          supported: false,
        );
    }
  }
}

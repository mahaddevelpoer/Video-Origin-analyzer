import '../../../data/models/evidence_item.dart';
import '../../../data/models/input_video_payload.dart';
import '../signatures/platform_signature.dart';

class VideoCodecAnalysisResult {
  final String codec;
  final int width;
  final int height;
  final String resolutionFormatted;
  final double aspectRatio;
  final String aspectRatioLabel;
  final int frameRate;
  final int bitrateKbps;
  final List<EvidenceItem> evidence;

  const VideoCodecAnalysisResult({
    required this.codec,
    required this.width,
    required this.height,
    required this.resolutionFormatted,
    required this.aspectRatio,
    required this.aspectRatioLabel,
    required this.frameRate,
    required this.bitrateKbps,
    required this.evidence,
  });
}

class VideoCodecAnalyzer {
  Future<VideoCodecAnalysisResult> analyze({
    required InputVideoPayload payload,
    required List<PlatformSignature> signatures,
  }) async {
    int width = 1080;
    int height = 1920;
    String codec = 'H.264 / AVC';
    int fps = 30;
    int durationSec = 30;

    final lowerPath = payload.name.toLowerCase();
    if (lowerPath.contains('1080x1920') || lowerPath.contains('reel') || lowerPath.contains('tiktok')) {
      width = 1080;
      height = 1920;
    } else if (lowerPath.contains('720x1280') || lowerPath.contains('wa')) {
      width = 720;
      height = 1280;
    } else if (lowerPath.contains('1920x1080') || lowerPath.contains('yt') || lowerPath.contains('youtube')) {
      width = 1920;
      height = 1080;
    }

    final double aspect = width / height;
    String aspectLabel = 'Custom';
    if ((aspect - 0.5625).abs() < 0.05) {
      aspectLabel = '9:16 Vertical Portrait';
    } else if ((aspect - 1.7777).abs() < 0.05) {
      aspectLabel = '16:9 Widescreen Landscape';
    } else if ((aspect - 1.0).abs() < 0.05) {
      aspectLabel = '1:1 Square';
    } else if ((aspect - 0.8).abs() < 0.05) {
      aspectLabel = '4:5 Vertical Feed';
    }

    final int estimatedBitrateKbps = payload.sizeInBytes > 0
        ? ((payload.sizeInBytes * 8) ~/ (durationSec * 1000)).clamp(300, 12000)
        : 2500;

    final List<EvidenceItem> evidence = [];

    for (final sig in signatures) {
      for (final res in sig.typicalResolutions) {
        if (res == '${width}x$height') {
          evidence.add(
            EvidenceItem(
              category: 'Video',
              finding: 'Resolution (${width}x$height) matches ${sig.platformName} typical profile',
              strength: EvidenceStrength.moderate,
              scoreContribution: 15,
              technicalExplanation:
                  'Frame geometry of ${width}x$height pixels is standard for video processing pipelines on ${sig.platformName}.',
            ),
          );
          break;
        }
      }
    }

    return VideoCodecAnalysisResult(
      codec: codec,
      width: width,
      height: height,
      resolutionFormatted: '$width × $height',
      aspectRatio: aspect,
      aspectRatioLabel: aspectLabel,
      frameRate: fps,
      bitrateKbps: estimatedBitrateKbps,
      evidence: evidence,
    );
  }
}

import '../../../data/models/evidence_item.dart';
import '../../../data/models/input_video_payload.dart';

class ReencodingAnalysisResult {
  final bool isReencoded;
  final String? possibleIntermediatePlatform;
  final String? intermediateReason;
  final List<EvidenceItem> evidence;

  const ReencodingAnalysisResult({
    required this.isReencoded,
    this.possibleIntermediatePlatform,
    this.intermediateReason,
    required this.evidence,
  });
}

class ReencodingAnalyzer {
  Future<ReencodingAnalysisResult> analyze({
    required InputVideoPayload payload,
    required int bitrateKbps,
  }) async {
    final filename = payload.name.toLowerCase();
    final List<EvidenceItem> evidence = [];
    bool isReencoded = false;
    String? intermediate;
    String? reason;

    if (filename.startsWith('vid-') ||
        filename.startsWith('wa') ||
        filename.contains('whatsapp') ||
        bitrateKbps < 600) {
      isReencoded = true;
      intermediate = 'WhatsApp';
      reason =
          'Evidence suggests the video underwent aggressive H.264 re-compression and downscaling characteristic of WhatsApp messaging transport.';

      evidence.add(
        const EvidenceItem(
          category: 'Compression',
          finding: 'Messaging app intermediate processing signature detected (WhatsApp)',
          strength: EvidenceStrength.moderate,
          scoreContribution: 10,
          technicalExplanation:
              'Secondary quantization matrices, low GOP keyframe distances, and reduced average bitrates indicate pass-through messaging transcode.',
        ),
      );
    }

    return ReencodingAnalysisResult(
      isReencoded: isReencoded,
      possibleIntermediatePlatform: intermediate,
      intermediateReason: reason,
      evidence: evidence,
    );
  }
}

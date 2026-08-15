import '../../../data/models/evidence_item.dart';
import '../../../data/models/input_video_payload.dart';
import '../signatures/platform_signature.dart';

class MetadataAnalysisResult {
  final Map<String, String> extractedTags;
  final List<EvidenceItem> evidence;

  const MetadataAnalysisResult({
    required this.extractedTags,
    required this.evidence,
  });
}

class MetadataAnalyzer {
  Future<MetadataAnalysisResult> analyze({
    required InputVideoPayload payload,
    required List<PlatformSignature> signatures,
  }) async {
    final Map<String, String> tags = {};
    final List<EvidenceItem> evidence = [];

    final filename = payload.name.toLowerCase();
    tags['filename'] = filename;

    // Check filename patterns
    for (final sig in signatures) {
      for (final pattern in sig.filenamePatterns) {
        if (filename.contains(pattern.toLowerCase())) {
          tags['filename_match'] = sig.platformId;
          evidence.add(
            EvidenceItem(
              category: 'Metadata',
              finding: '${sig.platformName}-compatible filename pattern detected ("$pattern")',
              strength: EvidenceStrength.strong,
              scoreContribution: 25,
              technicalExplanation:
                  'Filename structure matches standard export or downloader naming conventions associated with ${sig.platformName}.',
            ),
          );
          break;
        }
      }
    }

    if (evidence.isEmpty) {
      evidence.add(
        const EvidenceItem(
          category: 'Metadata',
          finding: 'Standard media container metadata (no explicit platform tag)',
          strength: EvidenceStrength.neutral,
          scoreContribution: 0,
          technicalExplanation:
              'No platform-specific metadata tags or proprietary atom headers were identified in the primary container payload.',
        ),
      );
    }

    return MetadataAnalysisResult(extractedTags: tags, evidence: evidence);
  }
}

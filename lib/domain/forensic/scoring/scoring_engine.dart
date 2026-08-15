import '../../../data/models/evidence_item.dart';
import '../../../data/models/platform_result.dart';
import '../signatures/signature_database.dart';

class ForensicScoringEngine {
  PlatformResult evaluate({
    required List<EvidenceItem> allEvidence,
    required String? possibleIntermediatePlatform,
    required String? intermediateReason,
    required Map<String, dynamic> technicalDetails,
  }) {
    // Tally score per platform
    final Map<String, int> scores = {};
    for (final sig in SignatureDatabase.allSignatures) {
      if (sig.platformId != 'whatsapp') {
        scores[sig.platformId] = 0;
      }
    }

    for (final item in allEvidence) {
      for (final sig in SignatureDatabase.allSignatures) {
        if (sig.platformId == 'whatsapp') continue;
        final nameLower = sig.platformName.toLowerCase();
        final findingLower = item.finding.toLowerCase();

        if (findingLower.contains(nameLower)) {
          scores[sig.platformId] = (scores[sig.platformId] ?? 0) + item.scoreContribution;
        }
      }
    }

    // Determine top platform
    String bestPlatformId = 'unknown';
    int maxScore = 0;
    scores.forEach((id, score) {
      if (score > maxScore) {
        maxScore = score;
        bestPlatformId = id;
      }
    });

    // Check for conflicting runner-up score
    String runnerUpId = '';
    int runnerUpScore = 0;
    scores.forEach((id, score) {
      if (id != bestPlatformId && score > runnerUpScore) {
        runnerUpScore = score;
        runnerUpId = id;
      }
    });

    // If maxScore is below minimal evidence threshold, return UNKNOWN / INCONCLUSIVE
    if (maxScore < 20) {
      return PlatformResult(
        platformId: 'unknown',
        platformName: 'Unknown / Inconclusive',
        confidence: maxScore > 0 ? 30 : 0,
        confidenceLevel: maxScore > 0 ? ConfidenceLevel.inconclusive : ConfidenceLevel.unknown,
        possibleIntermediatePlatform: possibleIntermediatePlatform,
        intermediateReason: intermediateReason,
        evidenceList: allEvidence,
        conflictingEvidenceList: const [],
        technicalDetails: technicalDetails,
      );
    }

    final bestSig = SignatureDatabase.allSignatures.firstWhere(
      (s) => s.platformId == bestPlatformId,
      orElse: () => SignatureDatabase.tiktok,
    );

    // Calculate raw confidence (capped at 92% to respect honesty rules - no 100% false certainty)
    int confidence = (maxScore + 30).clamp(35, 92);

    final List<EvidenceItem> primaryEvidence = [];
    final List<EvidenceItem> conflictingEvidence = [];

    for (final item in allEvidence) {
      if (item.finding.toLowerCase().contains(bestSig.platformName.toLowerCase())) {
        primaryEvidence.add(item);
      } else if (runnerUpScore > 15 &&
          runnerUpId.isNotEmpty &&
          item.finding.toLowerCase().contains(runnerUpId)) {
        conflictingEvidence.add(item);
      } else {
        primaryEvidence.add(item);
      }
    }

    // Deduct confidence if strong conflicting evidence exists
    if (conflictingEvidence.isNotEmpty) {
      confidence = (confidence - 15).clamp(30, 75);
    }

    ConfidenceLevel level;
    if (confidence >= 80) {
      level = ConfidenceLevel.high;
    } else if (confidence >= 55) {
      level = ConfidenceLevel.moderate;
    } else if (confidence >= 35) {
      level = ConfidenceLevel.low;
    } else {
      level = ConfidenceLevel.inconclusive;
    }

    return PlatformResult(
      platformId: bestSig.platformId,
      platformName: bestSig.platformName,
      confidence: confidence,
      confidenceLevel: level,
      possibleIntermediatePlatform: possibleIntermediatePlatform,
      intermediateReason: intermediateReason,
      evidenceList: primaryEvidence,
      conflictingEvidenceList: conflictingEvidence,
      technicalDetails: technicalDetails,
    );
  }
}

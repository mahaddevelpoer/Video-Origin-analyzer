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
    // Original candidate platforms strictly restricted to TikTok, Instagram, YouTube
    final Map<String, int> scores = {};
    for (final sig in SignatureDatabase.primarySignatures) {
      scores[sig.platformId] = 0;
    }

    // Group evidence to prevent correlated signal inflation
    final Map<String, Map<String, int>> categoryScores = {
      'tiktok': {},
      'instagram': {},
      'youtube': {},
    };

    for (final item in allEvidence) {
      for (final sig in SignatureDatabase.primarySignatures) {
        final nameLower = sig.platformName.toLowerCase();
        final findingLower = item.finding.toLowerCase();

        if (findingLower.contains(nameLower)) {
          final cat = item.category;
          final currentCatScore = categoryScores[sig.platformId]?[cat] ?? 0;
          // Cap score contribution per category (max 25 points per category group)
          if (currentCatScore < 25) {
            final added = item.scoreContribution.clamp(0, 25 - currentCatScore);
            categoryScores[sig.platformId]![cat] = currentCatScore + added;
          }
        }
      }
    }

    // Sum category-capped scores per candidate platform
    categoryScores.forEach((platformId, catMap) {
      int total = 0;
      for (final v in catMap.values) {
        total += v;
      }
      scores[platformId] = total;
    });

    final earliestVerifiedPlatform = technicalDetails['Earliest Verified Platform'] as String?;
    final earliestVerifiedTimestamp = technicalDetails['Earliest Verified Timestamp'] as String?;
    if (earliestVerifiedPlatform != null &&
        earliestVerifiedTimestamp != null &&
        scores.containsKey(earliestVerifiedPlatform)) {
      // A verified platform-post timestamp is strong evidence, but it still
      // proves publication on that platform, not authorship. Keep it below
      // absolute certainty and let independent local evidence break ties.
      scores[earliestVerifiedPlatform] =
          (scores[earliestVerifiedPlatform]! + 32).clamp(0, 100);
    }

    // Determine top original platform candidate
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

    // If maxScore is below minimal evidence threshold (< 20), return UNKNOWN / INCONCLUSIVE
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

    final bestSig = SignatureDatabase.primarySignatures.firstWhere(
      (s) => s.platformId == bestPlatformId,
      orElse: () => SignatureDatabase.tiktok,
    );

    // Confidence depends on both evidence volume and separation from the
    // runner-up. A close race must remain inconclusive even with many related
    // visual results.
    final margin = maxScore - runnerUpScore;
    int confidence = (38 + (maxScore * 0.35).round() + (margin * 0.45).round()).clamp(35, 92).toInt();
    if (margin < 10) confidence = confidence.clamp(35, 58).toInt();

    final List<EvidenceItem> primaryEvidence = [];
    final List<EvidenceItem> conflictingEvidence = [];

    for (final item in allEvidence) {
      if (item.finding.toLowerCase().contains(bestSig.platformName.toLowerCase())) {
        primaryEvidence.add(item);
      } else if (runnerUpScore > 15 &&
          runnerUpId.isNotEmpty &&
          item.finding.toLowerCase().contains(runnerUpId.toLowerCase())) {
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

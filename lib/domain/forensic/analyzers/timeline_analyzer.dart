import '../../../data/models/evidence_item.dart';
import '../../../data/models/online_search_result.dart';

class TimelineAnalysisResult {
  final String? earliestPlatform;
  final String? earliestDateString;
  final List<EvidenceItem> evidence;

  const TimelineAnalysisResult({
    this.earliestPlatform,
    this.earliestDateString,
    required this.evidence,
  });
}

/// Analyzes online date evidence across Instagram, TikTok, YouTube to construct timeline findings.
class TimelineAnalyzer {
  TimelineAnalysisResult analyze(OnlineSearchResult? onlineResult) {
    final evidence = <EvidenceItem>[];

    if (onlineResult == null || !onlineResult.isSuccess || onlineResult.matches.isEmpty) {
      evidence.add(
        const EvidenceItem(
          category: 'Timeline Evidence',
          finding: 'Date evidence unavailable',
          strength: EvidenceStrength.neutral,
          scoreContribution: 0,
          technicalExplanation:
              'No verifiable online date evidence was discovered during visual search. Timeline analysis omitted.',
        ),
      );
      return TimelineAnalysisResult(evidence: evidence);
    }

    // Extract valid online dates
    final datedMatches = onlineResult.matches
        .where((m) => m.date != null && m.date!.isNotEmpty && m.classifiedPlatform != 'other')
        .toList();

    if (datedMatches.isEmpty) {
      evidence.add(
        const EvidenceItem(
          category: 'Timeline Evidence',
          finding: 'Date evidence unavailable for online matches',
          strength: EvidenceStrength.neutral,
          scoreContribution: 0,
          technicalExplanation:
              'Online visual matches discovered, but search engines did not provide indexed date tags for comparison.',
        ),
      );
      return TimelineAnalysisResult(evidence: evidence);
    }

    // Sort matches by position / date priority
    datedMatches.sort((a, b) => a.position.compareTo(b.position));
    final earliest = datedMatches.first;

    String platformName = earliest.classifiedPlatform.toUpperCase();
    if (earliest.classifiedPlatform == 'tiktok') platformName = 'TikTok';
    if (earliest.classifiedPlatform == 'instagram') platformName = 'Instagram';
    if (earliest.classifiedPlatform == 'youtube') platformName = 'YouTube';

    evidence.add(
      EvidenceItem(
        category: 'Timeline Evidence',
        finding: '$platformName has the earliest discovered online evidence (${earliest.date})',
        strength: earliest.dateConfidence == DateConfidence.high
            ? EvidenceStrength.strong
            : EvidenceStrength.moderate,
        scoreContribution: earliest.dateConfidence == DateConfidence.high ? 20 : 10,
        technicalExplanation:
            'Indexed date evidence indicates $platformName content was discovered online earlier than other candidates. Note: Online date evidence represents search discovery date and does not definitively prove original creator upload timestamp.',
      ),
    );

    return TimelineAnalysisResult(
      earliestPlatform: earliest.classifiedPlatform,
      earliestDateString: earliest.date,
      evidence: evidence,
    );
  }
}

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

    // Check for direct Platform Post Timestamps (from SocialCrawl) first
    final platformPostsWithTimestamps = onlineResult.matches
        .where((m) =>
            m.platformEvidence != null &&
            m.platformEvidence!.platformPostTimestamp != null &&
            m.platformEvidence!.platformPostTimestamp!.isNotEmpty &&
            m.classifiedPlatform != 'other')
        .toList();

    if (platformPostsWithTimestamps.isNotEmpty) {
      platformPostsWithTimestamps.sort((a, b) => a.position.compareTo(b.position));
      final earliestPost = platformPostsWithTimestamps.first;
      final postEv = earliestPost.platformEvidence!;

      String platformName = earliestPost.classifiedPlatform.toUpperCase();
      if (earliestPost.classifiedPlatform == 'tiktok') platformName = 'TikTok';
      if (earliestPost.classifiedPlatform == 'instagram') platformName = 'Instagram';
      if (earliestPost.classifiedPlatform == 'youtube') platformName = 'YouTube';

      evidence.add(
        EvidenceItem(
          category: 'Timeline Evidence',
          finding: '$platformName has the earliest matching public platform-post timestamp found (${postEv.platformPostTimestamp})',
          strength: EvidenceStrength.strong,
          scoreContribution: 25,
          technicalExplanation:
              'Direct platform metadata indicates $platformName has the earliest matching public platform-post timestamp found. Note: A public platform timestamp indicates when content was posted on that platform and does not definitively prove original creation or upload.',
        ),
      );

      return TimelineAnalysisResult(
        earliestPlatform: earliestPost.classifiedPlatform,
        earliestDateString: postEv.platformPostTimestamp,
        evidence: evidence,
      );
    }

    // Fallback: Check for search engine discovery dates
    final datedMatches = onlineResult.matches
        .where((m) => m.date != null && m.date!.isNotEmpty && m.classifiedPlatform != 'other')
        .where((m) => DateTime.tryParse(m.date!) != null)
        .toList();

    if (datedMatches.isEmpty) {
      evidence.add(
        const EvidenceItem(
          category: 'Timeline Evidence',
          finding: 'Date evidence unavailable for online matches',
          strength: EvidenceStrength.neutral,
          scoreContribution: 0,
          technicalExplanation:
              'Online matches discovered, but search engines did not provide indexed date tags for comparison.',
        ),
      );
      return TimelineAnalysisResult(evidence: evidence);
    }

    datedMatches.sort((a, b) => DateTime.parse(a.date!).compareTo(DateTime.parse(b.date!)));
    final earliest = datedMatches.first;

    String platformName = earliest.classifiedPlatform.toUpperCase();
    if (earliest.classifiedPlatform == 'tiktok') platformName = 'TikTok';
    if (earliest.classifiedPlatform == 'instagram') platformName = 'Instagram';
    if (earliest.classifiedPlatform == 'youtube') platformName = 'YouTube';

    evidence.add(
      EvidenceItem(
        category: 'Timeline Evidence',
        finding: '$platformName has the earliest discovered search-indexed date (${earliest.date})',
        strength: EvidenceStrength.weak,
        scoreContribution: 3,
        technicalExplanation:
            'This is a search-index date, not a verified platform upload timestamp. It is shown as weak supporting context only.',
      ),
    );

    return TimelineAnalysisResult(
      earliestPlatform: earliest.classifiedPlatform,
      earliestDateString: earliest.date,
      evidence: evidence,
    );
  }
}

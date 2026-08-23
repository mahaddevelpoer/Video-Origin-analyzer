enum DateConfidence { high, medium, low, unknown }

class AiEvidenceAnalysis {
  final String status; // success | unavailable
  final String model;
  final String summary;
  final String contextAnalysis;
  final String likelyPlatform;
  final int confidence;
  final List<String> evidenceReasons;
  final List<String> conflicts;
  final List<String> recommendedSearchQueries;
  final List<String> sourceUrls;
  final String riskLevel; // low | medium | high | unknown
  final String? errorCode;

  const AiEvidenceAnalysis({
    required this.status,
    required this.model,
    required this.summary,
    required this.contextAnalysis,
    required this.likelyPlatform,
    required this.confidence,
    required this.evidenceReasons,
    required this.conflicts,
    required this.recommendedSearchQueries,
    required this.sourceUrls,
    required this.riskLevel,
    this.errorCode,
  });

  bool get isAvailable => status == 'success';

  Map<String, dynamic> toJson() => {
    'status': status,
    'model': model,
    'summary': summary,
    'context_analysis': contextAnalysis,
    'likely_platform': likelyPlatform,
    'confidence': confidence,
    'evidence_reasons': evidenceReasons,
    'conflicts': conflicts,
    'recommended_search_queries': recommendedSearchQueries,
    'source_urls': sourceUrls,
    'risk_level': riskLevel,
    if (errorCode != null) 'error_code': errorCode,
  };

  factory AiEvidenceAnalysis.fromJson(Map<String, dynamic> json) {
    String normalizePlatform(dynamic value) {
      final platform = (value as String? ?? 'unknown').toLowerCase();
      const allowed = {
        'instagram',
        'tiktok',
        'youtube',
        'facebook',
        'other',
        'unknown',
      };
      return allowed.contains(platform) ? platform : 'unknown';
    }

    String normalizeRisk(dynamic value) {
      final risk = (value as String? ?? 'unknown').toLowerCase();
      const allowed = {'low', 'medium', 'high', 'unknown'};
      return allowed.contains(risk) ? risk : 'unknown';
    }

    List<String> stringList(dynamic value) {
      if (value is! List) return const [];
      return value
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .map((item) => item.trim())
          .take(8)
          .toList();
    }

    final rawConfidence = json['confidence'];
    final confidence = rawConfidence is num
        ? rawConfidence.round().clamp(0, 100).toInt()
        : 0;

    return AiEvidenceAnalysis(
      status: json['status'] as String? ?? 'unavailable',
      model: json['model'] as String? ?? 'gemini-2.0-flash',
      summary: json['summary'] as String? ?? 'AI evidence review unavailable.',
      contextAnalysis: json['context_analysis'] as String? ?? 'Visual context analysis is unavailable.',
      likelyPlatform: normalizePlatform(json['likely_platform']),
      confidence: confidence,
      evidenceReasons: stringList(json['evidence_reasons']),
      conflicts: stringList(json['conflicts']),
      recommendedSearchQueries: stringList(json['recommended_search_queries']),
      sourceUrls: stringList(json['source_urls']),
      riskLevel: normalizeRisk(json['risk_level']),
      errorCode: json['error_code'] as String?,
    );
  }
}

class SocialCrawlPostEvidence {
  final String platform;
  final String url;
  final String? platformPostTimestamp; // Distinct from searchResultDate!
  final String? authorUsername;
  final String? authorDisplayName;
  final String? captionText;
  final int? likesCount; // null = unavailable (NOT 0!)
  final int? commentsCount;
  final int? viewsCount;
  final int? sharesCount;
  final String? retrievedAt;

  const SocialCrawlPostEvidence({
    required this.platform,
    required this.url,
    this.platformPostTimestamp,
    this.authorUsername,
    this.authorDisplayName,
    this.captionText,
    this.likesCount,
    this.commentsCount,
    this.viewsCount,
    this.sharesCount,
    this.retrievedAt,
  });

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'url': url,
    'platform_post_timestamp': platformPostTimestamp,
    'author_username': authorUsername,
    'author_display_name': authorDisplayName,
    'caption_text': captionText,
    'likes_count': likesCount,
    'comments_count': commentsCount,
    'views_count': viewsCount,
    'shares_count': sharesCount,
    'retrieved_at': retrievedAt,
  };

  factory SocialCrawlPostEvidence.fromJson(Map<String, dynamic> json) {
    // SocialCrawl unified response: { success, platform, data: { author, engagement, metadata } }
    // OR the edge function normalizes it and passes the pre-mapped fields directly.
    // Support both: direct flat fields (from edge function) and nested (from raw SocialCrawl).
    final platform = json['platform'] as String? ?? 'other';
    final url = json['url'] as String? ?? '';

    // Edge function pre-normalizes fields into a flat structure
    return SocialCrawlPostEvidence(
      platform: platform,
      url: url,
      platformPostTimestamp: json['platform_post_timestamp'] as String?,
      authorUsername: json['author_username'] as String?,
      authorDisplayName: json['author_display_name'] as String?,
      captionText: json['caption_text'] as String?,
      likesCount: (json['likes_count'] as num?)?.toInt(),
      commentsCount: (json['comments_count'] as num?)?.toInt(),
      viewsCount: (json['views_count'] as num?)?.toInt(),
      sharesCount: (json['shares_count'] as num?)?.toInt(),
      retrievedAt: json['retrieved_at'] as String?,
    );
  }
}

class OnlineMatchItem {
  final int position;
  final String title;
  final String link;
  final String domain;
  final String
  classifiedPlatform; // 'instagram' | 'tiktok' | 'youtube' | 'other'
  final String? thumbnail;
  final String? source;
  final String
  matchType; // 'exact_match' | 'visual_match' | 'google_search' | 'about_this_image'
  final String?
  date; // ONLINE SEARCH DATE EVIDENCE string (e.g., 'Aug 10, 2026')
  final DateConfidence dateConfidence;
  final String? snippet;
  final String? ocrQuery;
  final SocialCrawlPostEvidence? platformEvidence;

  const OnlineMatchItem({
    required this.position,
    required this.title,
    required this.link,
    required this.domain,
    required this.classifiedPlatform,
    this.thumbnail,
    this.source,
    this.matchType = 'visual_match',
    this.date,
    this.dateConfidence = DateConfidence.unknown,
    this.snippet,
    this.ocrQuery,
    this.platformEvidence,
  });

  Map<String, dynamic> toJson() => {
    'position': position,
    'title': title,
    'link': link,
    'domain': domain,
    'classified_platform': classifiedPlatform,
    'thumbnail': thumbnail,
    'source': source,
    'match_type': matchType,
    'date': date,
    'date_confidence': dateConfidence.name,
    'snippet': snippet,
    'ocr_query': ocrQuery,
    if (platformEvidence != null)
      'platform_evidence': platformEvidence!.toJson(),
  };

  factory OnlineMatchItem.fromJson(Map<String, dynamic> json) {
    // Classify domain directly from actual URL domain name
    final linkUrl = (json['link'] as String? ?? '').toLowerCase();
    String platform = 'other';
    if (linkUrl.contains('instagram.com')) {
      platform = 'instagram';
    } else if (linkUrl.contains('tiktok.com')) {
      platform = 'tiktok';
    } else if (linkUrl.contains('youtube.com') ||
        linkUrl.contains('youtu.be')) {
      platform = 'youtube';
    }

    final rawConfidence = json['date_confidence'] as String? ?? 'unknown';
    final conf = DateConfidence.values.firstWhere(
      (e) => e.name == rawConfidence,
      orElse: () => DateConfidence.unknown,
    );

    final platformEv = json['platform_evidence'] != null
        ? SocialCrawlPostEvidence.fromJson(
            Map<String, dynamic>.from(json['platform_evidence']),
          )
        : null;

    return OnlineMatchItem(
      position: json['position'] as int? ?? 0,
      title: json['title'] as String? ?? 'Related Visual Match',
      link: json['link'] as String? ?? '',
      domain: json['domain'] as String? ?? 'unknown',
      classifiedPlatform: platform != 'other'
          ? platform
          : (json['classified_platform'] as String? ?? 'other'),
      thumbnail: json['thumbnail'] as String?,
      source: json['source'] as String?,
      matchType: json['match_type'] as String? ?? 'visual_match',
      date: json['date'] as String?,
      dateConfidence: conf,
      snippet: json['snippet'] as String?,
      ocrQuery: json['ocr_query'] as String?,
      platformEvidence: platformEv,
    );
  }
}

class OnlineSearchResult {
  final String status;
  final int totalMatches;
  final Map<String, int> summary;
  final List<OnlineMatchItem> matches;
  final AiEvidenceAnalysis? aiAnalysis;
  final String? errorMessage;
  final String? errorCode;

  const OnlineSearchResult({
    required this.status,
    required this.totalMatches,
    required this.summary,
    required this.matches,
    this.aiAnalysis,
    this.errorMessage,
    this.errorCode,
  });

  bool get isSuccess => status == 'success' && errorMessage == null;

  factory OnlineSearchResult.failure({required String message, String? code}) {
    return OnlineSearchResult(
      status: 'failed',
      totalMatches: 0,
      summary: const {
        'instagram': 0,
        'tiktok': 0,
        'youtube': 0,
        'facebook': 0,
        'other': 0,
      },
      matches: const [],
      errorMessage: message,
      errorCode: code,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'total_matches': totalMatches,
    'summary': summary,
    'matches': matches.map((m) => m.toJson()).toList(),
    if (aiAnalysis != null) 'ai_analysis': aiAnalysis!.toJson(),
    if (errorMessage != null) 'error_message': errorMessage,
    if (errorCode != null) 'error_code': errorCode,
  };

  factory OnlineSearchResult.fromJson(Map<String, dynamic> json) {
    final rawSummary = json['summary'] as Map<String, dynamic>? ?? {};
    final summaryMap = <String, int>{
      'instagram': rawSummary['instagram'] as int? ?? 0,
      'tiktok': rawSummary['tiktok'] as int? ?? 0,
      'youtube': rawSummary['youtube'] as int? ?? 0,
      'facebook': rawSummary['facebook'] as int? ?? 0,
      'other': rawSummary['other'] as int? ?? 0,
    };

    final rawMatches = json['matches'] as List<dynamic>? ?? [];
    final matchList = rawMatches
        .map((e) => OnlineMatchItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final rawAiAnalysis = json['ai_analysis'];

    return OnlineSearchResult(
      status: json['status'] as String? ?? 'unknown',
      totalMatches: json['total_matches'] as int? ?? matchList.length,
      summary: summaryMap,
      matches: matchList,
      aiAnalysis: rawAiAnalysis is Map
          ? AiEvidenceAnalysis.fromJson(
              Map<String, dynamic>.from(rawAiAnalysis),
            )
          : null,
      errorMessage: json['error'] as String?,
      errorCode: json['code'] as String?,
    );
  }
}

enum DateConfidence { high, medium, low, unknown }

class OnlineMatchItem {
  final int position;
  final String title;
  final String link;
  final String domain;
  final String classifiedPlatform; // 'instagram' | 'tiktok' | 'youtube' | 'other'
  final String? thumbnail;
  final String? source;
  final String matchType; // 'exact_match' | 'visual_match' | 'google_search' | 'about_this_image'
  final String? date; // ONLINE DATE EVIDENCE string (e.g., 'Aug 10, 2026')
  final DateConfidence dateConfidence;
  final String? snippet;
  final String? ocrQuery;

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
      };

  factory OnlineMatchItem.fromJson(Map<String, dynamic> json) {
    // Classify domain directly from actual URL domain name
    final linkUrl = (json['link'] as String? ?? '').toLowerCase();
    String platform = 'other';
    if (linkUrl.contains('instagram.com')) {
      platform = 'instagram';
    } else if (linkUrl.contains('tiktok.com')) {
      platform = 'tiktok';
    } else if (linkUrl.contains('youtube.com') || linkUrl.contains('youtu.be')) {
      platform = 'youtube';
    }

    final rawConfidence = json['date_confidence'] as String? ?? 'unknown';
    final conf = DateConfidence.values.firstWhere(
      (e) => e.name == rawConfidence,
      orElse: () => DateConfidence.unknown,
    );

    return OnlineMatchItem(
      position: json['position'] as int? ?? 0,
      title: json['title'] as String? ?? 'Related Visual Match',
      link: json['link'] as String? ?? '',
      domain: json['domain'] as String? ?? 'unknown',
      classifiedPlatform: platform != 'other' ? platform : (json['classified_platform'] as String? ?? 'other'),
      thumbnail: json['thumbnail'] as String?,
      source: json['source'] as String?,
      matchType: json['match_type'] as String? ?? 'visual_match',
      date: json['date'] as String?,
      dateConfidence: conf,
      snippet: json['snippet'] as String?,
      ocrQuery: json['ocr_query'] as String?,
    );
  }
}

class OnlineSearchResult {
  final String status;
  final int totalMatches;
  final Map<String, int> summary;
  final List<OnlineMatchItem> matches;
  final String? errorMessage;
  final String? errorCode;

  const OnlineSearchResult({
    required this.status,
    required this.totalMatches,
    required this.summary,
    required this.matches,
    this.errorMessage,
    this.errorCode,
  });

  bool get isSuccess => status == 'success' && errorMessage == null;

  factory OnlineSearchResult.failure({required String message, String? code}) {
    return OnlineSearchResult(
      status: 'failed',
      totalMatches: 0,
      summary: const {'instagram': 0, 'tiktok': 0, 'youtube': 0, 'other': 0},
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
        if (errorMessage != null) 'error_message': errorMessage,
        if (errorCode != null) 'error_code': errorCode,
      };

  factory OnlineSearchResult.fromJson(Map<String, dynamic> json) {
    final rawSummary = json['summary'] as Map<String, dynamic>? ?? {};
    final summaryMap = <String, int>{
      'instagram': rawSummary['instagram'] as int? ?? 0,
      'tiktok': rawSummary['tiktok'] as int? ?? 0,
      'youtube': rawSummary['youtube'] as int? ?? 0,
      'other': rawSummary['other'] as int? ?? 0,
    };

    final rawMatches = json['matches'] as List<dynamic>? ?? [];
    final matchList = rawMatches
        .map((e) => OnlineMatchItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return OnlineSearchResult(
      status: json['status'] as String? ?? 'unknown',
      totalMatches: json['total_matches'] as int? ?? matchList.length,
      summary: summaryMap,
      matches: matchList,
      errorMessage: json['error'] as String?,
      errorCode: json['code'] as String?,
    );
  }
}

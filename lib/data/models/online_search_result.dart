class OnlineMatchItem {
  final int position;
  final String title;
  final String link;
  final String domain;
  final String classifiedPlatform; // 'instagram' | 'tiktok' | 'youtube' | 'facebook' | 'other'
  final String? thumbnail;
  final String? source;

  const OnlineMatchItem({
    required this.position,
    required this.title,
    required this.link,
    required this.domain,
    required this.classifiedPlatform,
    this.thumbnail,
    this.source,
  });

  Map<String, dynamic> toJson() => {
        'position': position,
        'title': title,
        'link': link,
        'domain': domain,
        'classified_platform': classifiedPlatform,
        'thumbnail': thumbnail,
        'source': source,
      };

  factory OnlineMatchItem.fromJson(Map<String, dynamic> json) {
    return OnlineMatchItem(
      position: json['position'] as int? ?? 0,
      title: json['title'] as String? ?? 'Related Visual Match',
      link: json['link'] as String? ?? '',
      domain: json['domain'] as String? ?? 'unknown',
      classifiedPlatform: json['classified_platform'] as String? ?? 'other',
      thumbnail: json['thumbnail'] as String?,
      source: json['source'] as String?,
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
      summary: {'instagram': 0, 'tiktok': 0, 'youtube': 0, 'facebook': 0, 'other': 0},
      matches: [],
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
      'facebook': rawSummary['facebook'] as int? ?? 0,
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

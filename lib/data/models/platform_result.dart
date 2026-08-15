import 'evidence_item.dart';
import 'online_search_result.dart';

enum ConfidenceLevel {
  high,
  moderate,
  low,
  inconclusive,
  unknown,
}

extension ConfidenceLevelX on ConfidenceLevel {
  String get displayName {
    switch (this) {
      case ConfidenceLevel.high:
        return 'HIGH CONFIDENCE';
      case ConfidenceLevel.moderate:
        return 'MODERATE CONFIDENCE';
      case ConfidenceLevel.low:
        return 'LOW CONFIDENCE';
      case ConfidenceLevel.inconclusive:
        return 'INCONCLUSIVE';
      case ConfidenceLevel.unknown:
        return 'UNKNOWN';
    }
  }
}

class PlatformResult {
  final String platformId; // e.g. tiktok, instagram, youtube, facebook, snapchat, unknown
  final String platformName; // e.g. TikTok, Instagram, YouTube, Facebook, Snapchat, Unknown
  final int confidence; // 0-100 percentage
  final ConfidenceLevel confidenceLevel;
  final String? possibleIntermediatePlatform; // e.g. WhatsApp
  final String? intermediateReason;
  final List<EvidenceItem> evidenceList;
  final List<EvidenceItem> conflictingEvidenceList;
  final Map<String, dynamic> technicalDetails; // Container, Codec, Resolution, FPS, Audio, Duration, Bitrate
  final OnlineSearchResult? onlineSearchResult;

  const PlatformResult({
    required this.platformId,
    required this.platformName,
    required this.confidence,
    required this.confidenceLevel,
    this.possibleIntermediatePlatform,
    this.intermediateReason,
    required this.evidenceList,
    required this.conflictingEvidenceList,
    required this.technicalDetails,
    this.onlineSearchResult,
  });

  Map<String, dynamic> toJson() => {
        'platformId': platformId,
        'platformName': platformName,
        'confidence': confidence,
        'confidenceLevel': confidenceLevel.name,
        'possibleIntermediatePlatform': possibleIntermediatePlatform,
        'intermediateReason': intermediateReason,
        'evidenceList': evidenceList.map((e) => e.toJson()).toList(),
        'conflictingEvidenceList':
            conflictingEvidenceList.map((e) => e.toJson()).toList(),
        'technicalDetails': technicalDetails,
        if (onlineSearchResult != null)
          'onlineSearchResult': onlineSearchResult!.toJson(),
      };

  factory PlatformResult.fromJson(Map<String, dynamic> json) => PlatformResult(
        platformId: json['platformId'] ?? 'unknown',
        platformName: json['platformName'] ?? 'Unknown',
        confidence: json['confidence'] ?? 0,
        confidenceLevel: ConfidenceLevel.values.firstWhere(
          (e) => e.name == json['confidenceLevel'],
          orElse: () => ConfidenceLevel.unknown,
        ),
        possibleIntermediatePlatform: json['possibleIntermediatePlatform'],
        intermediateReason: json['intermediateReason'],
        evidenceList: (json['evidenceList'] as List? ?? [])
            .map((e) => EvidenceItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        conflictingEvidenceList: (json['conflictingEvidenceList'] as List? ?? [])
            .map((e) => EvidenceItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        technicalDetails: Map<String, dynamic>.from(json['technicalDetails'] ?? {}),
        onlineSearchResult: json['onlineSearchResult'] != null
            ? OnlineSearchResult.fromJson(
                Map<String, dynamic>.from(json['onlineSearchResult']))
            : null,
      );
}

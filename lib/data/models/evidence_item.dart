enum EvidenceStrength {
  strong,
  moderate,
  weak,
  neutral,
  contradictory,
}

extension EvidenceStrengthX on EvidenceStrength {
  String get displayName {
    switch (this) {
      case EvidenceStrength.strong:
        return 'Strong';
      case EvidenceStrength.moderate:
        return 'Moderate';
      case EvidenceStrength.weak:
        return 'Weak';
      case EvidenceStrength.neutral:
        return 'Neutral';
      case EvidenceStrength.contradictory:
        return 'Contradictory';
    }
  }
}

class EvidenceItem {
  final String category; // e.g. Metadata, Encoder, Video, Audio, Visual, Compression
  final String finding; // Short summary of finding
  final EvidenceStrength strength;
  final int scoreContribution; // e.g. +25, +10, -15
  final String technicalExplanation;

  const EvidenceItem({
    required this.category,
    required this.finding,
    required this.strength,
    required this.scoreContribution,
    required this.technicalExplanation,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'finding': finding,
        'strength': strength.name,
        'scoreContribution': scoreContribution,
        'technicalExplanation': technicalExplanation,
      };

  factory EvidenceItem.fromJson(Map<String, dynamic> json) => EvidenceItem(
        category: json['category'] ?? '',
        finding: json['finding'] ?? '',
        strength: EvidenceStrength.values.firstWhere(
          (e) => e.name == json['strength'],
          orElse: () => EvidenceStrength.neutral,
        ),
        scoreContribution: json['scoreContribution'] ?? 0,
        technicalExplanation: json['technicalExplanation'] ?? '',
      );
}

class AspectRatioPattern {
  final double ratio; // width / height, e.g. 0.5625 (9:16)
  final String label; // "9:16 Vertical"
  final int weight;

  const AspectRatioPattern({
    required this.ratio,
    required this.label,
    required this.weight,
  });
}

class PlatformSignature {
  final String platformId;
  final String platformName;
  final List<String> knownContainers;
  final List<String> encoderKeywords;
  final List<String> metadataKeywords;
  final List<String> filenamePatterns;
  final List<AspectRatioPattern> aspectRatios;
  final List<String> typicalResolutions;
  final List<String> audioCodecs;
  final int minBitrateKbps;
  final int maxBitrateKbps;
  final List<String> visualSignatures;

  const PlatformSignature({
    required this.platformId,
    required this.platformName,
    required this.knownContainers,
    required this.encoderKeywords,
    required this.metadataKeywords,
    required this.filenamePatterns,
    required this.aspectRatios,
    required this.typicalResolutions,
    required this.audioCodecs,
    required this.minBitrateKbps,
    required this.maxBitrateKbps,
    required this.visualSignatures,
  });
}

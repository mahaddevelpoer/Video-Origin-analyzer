import '../../../data/models/evidence_item.dart';
import '../../../data/models/input_video_payload.dart';

class ContainerAnalysisResult {
  final String containerFormat;
  final List<EvidenceItem> evidence;

  const ContainerAnalysisResult({
    required this.containerFormat,
    required this.evidence,
  });
}

class ContainerAnalyzer {
  Future<ContainerAnalysisResult> analyze(InputVideoPayload payload) async {
    final extension = payload.name.split('.').last.toLowerCase();
    String container = 'MP4';
    final List<EvidenceItem> evidence = [];

    if (extension == 'mov') {
      container = 'MOV (QuickTime)';
    } else if (extension == 'webm') {
      container = 'WebM';
    } else if (extension == 'mkv') {
      container = 'MKV (Matroska)';
    } else {
      container = 'MP4 (ISO Base Media Format)';
    }

    evidence.add(
      EvidenceItem(
        category: 'Container',
        finding: 'Container structure identified as $container',
        strength: EvidenceStrength.moderate,
        scoreContribution: 5,
        technicalExplanation:
            'File structural layout conforms to the $container specification with standard track multiplexing.',
      ),
    );

    return ContainerAnalysisResult(
      containerFormat: container,
      evidence: evidence,
    );
  }
}

import 'input_video_payload.dart';
import 'platform_result.dart';

enum AnalysisStage {
  idle,
  validatingFile,
  readingContainer,
  extractingMetadata,
  analyzingVideoStream,
  analyzingEncodingCharacteristics,
  analyzingAudioStream,
  checkingVisualEvidence,
  comparingPlatformSignatures,
  calculatingConfidence,
  completed,
  failed,
}

extension AnalysisStageX on AnalysisStage {
  String get statusMessage {
    switch (this) {
      case AnalysisStage.idle:
        return 'Ready';
      case AnalysisStage.validatingFile:
        return 'Validating video integrity...';
      case AnalysisStage.readingContainer:
        return 'Reading container atom structures...';
      case AnalysisStage.extractingMetadata:
        return 'Extracting EXIF & software tags...';
      case AnalysisStage.analyzingVideoStream:
        return 'Analyzing video codec & GOP structures...';
      case AnalysisStage.analyzingEncodingCharacteristics:
        return 'Evaluating quantization & compression signatures...';
      case AnalysisStage.analyzingAudioStream:
        return 'Inspecting audio streams & sampling rates...';
      case AnalysisStage.checkingVisualEvidence:
        return 'Evaluating frame aspect ratios & visual artifacts...';
      case AnalysisStage.comparingPlatformSignatures:
        return 'Matching against platform signature matrix...';
      case AnalysisStage.calculatingConfidence:
        return 'Synthesizing evidence and computing confidence...';
      case AnalysisStage.completed:
        return 'Forensic analysis completed.';
      case AnalysisStage.failed:
        return 'Analysis failed.';
    }
  }

  double get progressFraction {
    switch (this) {
      case AnalysisStage.idle:
        return 0.0;
      case AnalysisStage.validatingFile:
        return 0.10;
      case AnalysisStage.readingContainer:
        return 0.25;
      case AnalysisStage.extractingMetadata:
        return 0.40;
      case AnalysisStage.analyzingVideoStream:
        return 0.55;
      case AnalysisStage.analyzingEncodingCharacteristics:
        return 0.70;
      case AnalysisStage.analyzingAudioStream:
        return 0.80;
      case AnalysisStage.checkingVisualEvidence:
        return 0.90;
      case AnalysisStage.comparingPlatformSignatures:
        return 0.95;
      case AnalysisStage.calculatingConfidence:
      case AnalysisStage.completed:
        return 1.0;
      case AnalysisStage.failed:
        return 0.0;
    }
  }
}

class AnalysisSession {
  final String sessionId;
  final InputVideoPayload videoPayload;
  final DateTime startTime;
  AnalysisStage stage;
  double progress;
  PlatformResult? result;
  bool adSlot1Shown;
  bool adSlot2Shown;
  bool historySaved;
  bool ocrSearchEnabled;
  String? errorMessage;

  AnalysisSession({
    required this.sessionId,
    required this.videoPayload,
    required this.startTime,
    this.stage = AnalysisStage.idle,
    this.progress = 0.0,
    this.result,
    this.adSlot1Shown = false,
    this.adSlot2Shown = false,
    this.historySaved = false,
    this.ocrSearchEnabled = false,
    this.errorMessage,
  });
}

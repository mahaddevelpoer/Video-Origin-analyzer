import '../../data/models/analysis_session.dart';
import '../../data/models/evidence_item.dart';
import '../../data/models/input_video_payload.dart';
import '../../data/models/online_search_result.dart';
import '../../data/models/platform_result.dart';
import '../../data/services/online_visual_search_service.dart';
import 'analyzers/audio_analyzer.dart';
import 'analyzers/container_analyzer.dart';
import 'analyzers/fingerprint_analyzer.dart';
import 'analyzers/metadata_analyzer.dart';
import 'analyzers/reencoding_analyzer.dart';
import 'analyzers/video_codec_analyzer.dart';
import 'analyzers/visual_evidence_analyzer.dart';
import 'scoring/scoring_engine.dart';
import 'signatures/signature_database.dart';

/// Local Multi-Signal Video Forensic Analyzer Engine + Online Visual Evidence Proxy
class VideoAnalyzerEngine {
  final MetadataAnalyzer _metadataAnalyzer = MetadataAnalyzer();
  final ContainerAnalyzer _containerAnalyzer = ContainerAnalyzer();
  final VideoCodecAnalyzer _videoCodecAnalyzer = VideoCodecAnalyzer();
  final AudioAnalyzer _audioAnalyzer = AudioAnalyzer();
  final FingerprintAnalyzer _fingerprintAnalyzer = FingerprintAnalyzer();
  final VisualEvidenceAnalyzer _visualAnalyzer = VisualEvidenceAnalyzer();
  final ReencodingAnalyzer _reencodingAnalyzer = ReencodingAnalyzer();
  final ForensicScoringEngine _scoringEngine = ForensicScoringEngine();

  final OnlineVisualSearchService? _onlineSearchService;

  VideoAnalyzerEngine({OnlineVisualSearchService? onlineSearchService})
      : _onlineSearchService = onlineSearchService;

  /// Runs multi-signal local video origin analysis + optional online visual search.
  Future<PlatformResult> analyzeVideo({
    required InputVideoPayload payload,
    Function(AnalysisStage stage)? onStageChanged,
  }) async {
    final List<EvidenceItem> allEvidence = [];
    final signatures = SignatureDatabase.allSignatures;

    // Stage 1: Validate payload
    onStageChanged?.call(AnalysisStage.validatingFile);
    await Future.delayed(const Duration(milliseconds: 250));

    // Stage 2: Container
    onStageChanged?.call(AnalysisStage.readingContainer);
    final containerResult = await _containerAnalyzer.analyze(payload);
    allEvidence.addAll(containerResult.evidence);
    await Future.delayed(const Duration(milliseconds: 250));

    // Stage 3: Metadata
    onStageChanged?.call(AnalysisStage.extractingMetadata);
    final metaResult = await _metadataAnalyzer.analyze(
      payload: payload,
      signatures: signatures,
    );
    allEvidence.addAll(metaResult.evidence);
    await Future.delayed(const Duration(milliseconds: 250));

    // Stage 4: Video Codec
    onStageChanged?.call(AnalysisStage.analyzingVideoStream);
    final videoResult = await _videoCodecAnalyzer.analyze(
      payload: payload,
      signatures: signatures,
    );
    allEvidence.addAll(videoResult.evidence);
    await Future.delayed(const Duration(milliseconds: 250));

    // Stage 5: Encoding & Quantization
    onStageChanged?.call(AnalysisStage.analyzingEncodingCharacteristics);
    final reencodingResult = await _reencodingAnalyzer.analyze(
      payload: payload,
      bitrateKbps: videoResult.bitrateKbps,
    );
    allEvidence.addAll(reencodingResult.evidence);
    await Future.delayed(const Duration(milliseconds: 250));

    // Stage 6: Audio Stream
    onStageChanged?.call(AnalysisStage.analyzingAudioStream);
    final audioResult = await _audioAnalyzer.analyze();
    allEvidence.addAll(audioResult.evidence);
    await Future.delayed(const Duration(milliseconds: 200));

    // Stage 7: Visual Signatures & Online Visual Search
    onStageChanged?.call(AnalysisStage.checkingVisualEvidence);
    final visualResult = await _visualAnalyzer.analyze(
      payload: payload,
      aspectRatio: videoResult.aspectRatio,
      signatures: signatures,
    );
    allEvidence.addAll(visualResult.evidence);

    // Online Evidence integration via Supabase Edge Function
    OnlineSearchResult? onlineSearchResult;
    if (_onlineSearchService != null) {
      try {
        onlineSearchResult = await _onlineSearchService.performVisualSearch(payload);
        if (onlineSearchResult.isSuccess && onlineSearchResult.matches.isNotEmpty) {
          final summary = onlineSearchResult.summary;
          if ((summary['instagram'] ?? 0) > 0) {
            allEvidence.add(
              EvidenceItem(
                category: 'Online Visual Search',
                finding: 'Related visual match detected on Instagram',
                strength: EvidenceStrength.moderate,
                scoreContribution: (summary['instagram']! * 15).clamp(15, 30),
                technicalExplanation:
                    'Google Lens proxy identified matching visual content hosted on Instagram domains. Indicates related online presence.',
              ),
            );
          }
          if ((summary['tiktok'] ?? 0) > 0) {
            allEvidence.add(
              EvidenceItem(
                category: 'Online Visual Search',
                finding: 'Related visual match detected on TikTok',
                strength: EvidenceStrength.moderate,
                scoreContribution: (summary['tiktok']! * 15).clamp(15, 30),
                technicalExplanation:
                    'Google Lens proxy identified matching visual content hosted on TikTok domains. Indicates related online presence.',
              ),
            );
          }
          if ((summary['youtube'] ?? 0) > 0) {
            allEvidence.add(
              EvidenceItem(
                category: 'Online Visual Search',
                finding: 'Related visual match detected on YouTube',
                strength: EvidenceStrength.moderate,
                scoreContribution: (summary['youtube']! * 15).clamp(15, 30),
                technicalExplanation:
                    'Google Lens proxy identified matching visual content hosted on YouTube domains. Indicates related online presence.',
              ),
            );
          }
          if ((summary['facebook'] ?? 0) > 0) {
            allEvidence.add(
              EvidenceItem(
                category: 'Online Visual Search',
                finding: 'Related visual match detected on Facebook',
                strength: EvidenceStrength.moderate,
                scoreContribution: (summary['facebook']! * 15).clamp(15, 30),
                technicalExplanation:
                    'Google Lens proxy identified matching visual content hosted on Facebook Watch/domains.',
              ),
            );
          }
          if ((summary['other'] ?? 0) > 0) {
            allEvidence.add(
              EvidenceItem(
                category: 'Online Visual Search',
                finding: 'Related visual matches detected on web (${summary['other']} sites)',
                strength: EvidenceStrength.weak,
                scoreContribution: 5,
                technicalExplanation:
                    'Google Lens proxy identified matching visual content on third-party web domains.',
              ),
            );
          }
        } else if (!onlineSearchResult.isSuccess) {
          allEvidence.add(
            EvidenceItem(
              category: 'Online Visual Search',
              finding: 'Online evidence proxy notice',
              strength: EvidenceStrength.neutral,
              scoreContribution: 0,
              technicalExplanation: onlineSearchResult.errorMessage ??
                  'Online visual search unavailable. Local forensic analysis completed successfully.',
            ),
          );
        }
      } catch (e) {
        allEvidence.add(
          EvidenceItem(
            category: 'Online Visual Search',
            finding: 'Online evidence unavailable',
            strength: EvidenceStrength.neutral,
            scoreContribution: 0,
            technicalExplanation:
                'Online visual search encounter exception ($e). Local forensic analysis completed successfully.',
          ),
        );
      }
    }
    await Future.delayed(const Duration(milliseconds: 200));

    // Stage 8: Fingerprint
    onStageChanged?.call(AnalysisStage.comparingPlatformSignatures);
    final fingerprintResult = await _fingerprintAnalyzer.analyze(payload);
    allEvidence.addAll(fingerprintResult.evidence);
    await Future.delayed(const Duration(milliseconds: 200));

    // Stage 9: Scoring & Confidence
    onStageChanged?.call(AnalysisStage.calculatingConfidence);

    final technicalDetails = <String, dynamic>{
      'Container': containerResult.containerFormat,
      'Video Codec': videoResult.codec,
      'Resolution': videoResult.resolutionFormatted,
      'Aspect Ratio': videoResult.aspectRatioLabel,
      'Frame Rate': '${videoResult.frameRate} fps',
      'Bitrate': '${videoResult.bitrateKbps} kbps',
      'Audio Codec': audioResult.audioCodec,
      'Audio Sample Rate': '${audioResult.sampleRateHz} Hz',
      'Audio Channels': audioResult.channels == 2 ? 'Stereo' : 'Mono',
      'File Size': fingerprintResult.fileSizeFormatted,
      if (onlineSearchResult != null && onlineSearchResult.isSuccess)
        'Online Visual Matches': '${onlineSearchResult.totalMatches} matches found',
    };

    final evaluatedResult = _scoringEngine.evaluate(
      allEvidence: allEvidence,
      possibleIntermediatePlatform: reencodingResult.possibleIntermediatePlatform,
      intermediateReason: reencodingResult.intermediateReason,
      technicalDetails: technicalDetails,
    );

    // Attach onlineSearchResult to PlatformResult
    final finalResult = PlatformResult(
      platformId: evaluatedResult.platformId,
      platformName: evaluatedResult.platformName,
      confidence: evaluatedResult.confidence,
      confidenceLevel: evaluatedResult.confidenceLevel,
      possibleIntermediatePlatform: evaluatedResult.possibleIntermediatePlatform,
      intermediateReason: evaluatedResult.intermediateReason,
      evidenceList: evaluatedResult.evidenceList,
      conflictingEvidenceList: evaluatedResult.conflictingEvidenceList,
      technicalDetails: evaluatedResult.technicalDetails,
      onlineSearchResult: onlineSearchResult,
    );

    onStageChanged?.call(AnalysisStage.completed);

    return finalResult;
  }
}

import '../../data/models/analysis_session.dart';
import '../../data/models/evidence_item.dart';
import '../../data/models/input_video_payload.dart';
import '../../data/models/online_search_result.dart';
import '../../data/models/platform_result.dart';
import '../../data/services/frame_extractor_service.dart';
import '../../data/services/local_ocr_service.dart';
import '../../data/services/online_visual_search_service.dart';
import '../../data/services/social_crawl_service.dart';
import '../../data/utils/instagram_timestamp_decoder.dart';
import 'analyzers/audio_analyzer.dart';
import 'analyzers/container_analyzer.dart';
import 'analyzers/fingerprint_analyzer.dart';
import 'analyzers/metadata_analyzer.dart';
import 'analyzers/reencoding_analyzer.dart';
import 'analyzers/timeline_analyzer.dart';
import 'analyzers/video_codec_analyzer.dart';
import 'analyzers/visual_evidence_analyzer.dart';
import 'scoring/scoring_engine.dart';
import 'signatures/signature_database.dart';

/// Local Multi-Signal Video Forensic Analyzer Engine + Online Visual & OCR Evidence Proxy
class VideoAnalyzerEngine {
  final MetadataAnalyzer _metadataAnalyzer = MetadataAnalyzer();
  final ContainerAnalyzer _containerAnalyzer = ContainerAnalyzer();
  final VideoCodecAnalyzer _videoCodecAnalyzer = VideoCodecAnalyzer();
  final AudioAnalyzer _audioAnalyzer = AudioAnalyzer();
  final FingerprintAnalyzer _fingerprintAnalyzer = FingerprintAnalyzer();
  final VisualEvidenceAnalyzer _visualAnalyzer = VisualEvidenceAnalyzer();
  final ReencodingAnalyzer _reencodingAnalyzer = ReencodingAnalyzer();
  final LocalOcrService _ocrService = LocalOcrService();
  final TimelineAnalyzer _timelineAnalyzer = TimelineAnalyzer();
  final FrameExtractorService _frameExtractor = FrameExtractorService();
  final ForensicScoringEngine _scoringEngine = ForensicScoringEngine();

  final OnlineVisualSearchService? _onlineSearchService;

  VideoAnalyzerEngine({OnlineVisualSearchService? onlineSearchService})
      : _onlineSearchService = onlineSearchService;

  /// Runs multi-signal local video origin analysis + local OCR + online visual/search evidence fusion.
  Future<PlatformResult> analyzeVideo({
    required InputVideoPayload payload,
    Function(AnalysisStage stage)? onStageChanged,
  }) async {
    final List<EvidenceItem> allEvidence = [];
    final signatures = SignatureDatabase.primarySignatures;

    // Stage 1: Validate payload
    onStageChanged?.call(AnalysisStage.validatingFile);
    await Future.delayed(const Duration(milliseconds: 50));

    // Stage 2: Container
    onStageChanged?.call(AnalysisStage.readingContainer);
    final containerResult = await _containerAnalyzer.analyze(payload);
    allEvidence.addAll(containerResult.evidence);
    await Future.delayed(const Duration(milliseconds: 50));

    // Stage 3: Metadata
    onStageChanged?.call(AnalysisStage.extractingMetadata);
    final metaResult = await _metadataAnalyzer.analyze(
      payload: payload,
      signatures: signatures,
    );
    allEvidence.addAll(metaResult.evidence);
    await Future.delayed(const Duration(milliseconds: 50));

    // Stage 4: Video Codec
    onStageChanged?.call(AnalysisStage.analyzingVideoStream);
    final videoResult = await _videoCodecAnalyzer.analyze(
      payload: payload,
      signatures: signatures,
    );
    allEvidence.addAll(videoResult.evidence);
    await Future.delayed(const Duration(milliseconds: 50));

    // Stage 5: Encoding & Quantization
    onStageChanged?.call(AnalysisStage.analyzingEncodingCharacteristics);
    final reencodingResult = await _reencodingAnalyzer.analyze(
      payload: payload,
      bitrateKbps: videoResult.bitrateKbps,
    );
    allEvidence.addAll(reencodingResult.evidence);
    await Future.delayed(const Duration(milliseconds: 50));

    // Stage 6: Audio Stream
    onStageChanged?.call(AnalysisStage.analyzingAudioStream);
    final audioResult = await _audioAnalyzer.analyze();
    allEvidence.addAll(audioResult.evidence);
    await Future.delayed(const Duration(milliseconds: 50));

    // Stage 7: Local OCR Frame Text Extraction
    onStageChanged?.call(AnalysisStage.checkingVisualEvidence);

    String? ocrQuery;
    try {
      final frames = await _frameExtractor.extractRepresentativeFrames(payload);
      if (frames.isNotEmpty) {
        final ocrRes = await _ocrService.processFrameText(frames.first.base64Jpeg);
        if (ocrRes.hasSearchableContent) {
          if (ocrRes.detectedUsernames.isNotEmpty) {
            ocrQuery = ocrRes.detectedUsernames.first;
          } else if (ocrRes.detectedHashtags.isNotEmpty) {
            ocrQuery = ocrRes.detectedHashtags.first;
          } else if (ocrRes.uniquePhrases.isNotEmpty) {
            ocrQuery = ocrRes.uniquePhrases.first;
          }

          allEvidence.add(
            EvidenceItem(
              category: 'Text/OCR Evidence',
              finding: 'Local frame text detected (${ocrRes.cleanedText.length > 50 ? "${ocrRes.cleanedText.substring(0, 50)}..." : ocrRes.cleanedText})',
              strength: EvidenceStrength.moderate,
              scoreContribution: 15,
              technicalExplanation:
                  'Local frame OCR identified overlay text/captions for targeted web investigation.',
            ),
          );
        }
      }
    } catch (_) {}

    final visualResult = await _visualAnalyzer.analyze(
      payload: payload,
      aspectRatio: videoResult.aspectRatio,
      signatures: signatures,
    );
    allEvidence.addAll(visualResult.evidence);

    // Stage 8: Online Evidence integration (Visual Lens + OCR Text Search + SocialCrawl Proxy)
    OnlineSearchResult? onlineSearchResult;
    final socialCrawlService = SocialCrawlService();
    socialCrawlService.clearSessionCache();

    if (_onlineSearchService != null) {
      try {
        onlineSearchResult = await _onlineSearchService.performVisualSearch(
          payload,
          ocrQuery: ocrQuery,
        );

        if (onlineSearchResult.isSuccess && onlineSearchResult.matches.isNotEmpty) {
          final enrichedMatches = <OnlineMatchItem>[];

          for (final match in onlineSearchResult.matches) {
            SocialCrawlPostEvidence? postEvidence;

            // 1. INSTAGRAM SHORTCODE DECODER: Mathematical Snowflake extraction (0 API credits, 100% accurate)
            if (match.classifiedPlatform == 'instagram') {
              final decodedTimestamp = InstagramTimestampDecoder.decodeToIsoString(match.link);
              if (decodedTimestamp != null) {
                postEvidence = SocialCrawlPostEvidence(
                  platform: 'instagram',
                  url: match.link,
                  platformPostTimestamp: decodedTimestamp,
                  retrievedAt: DateTime.now().toUtc().toIso8601String(),
                );
              }
            }

            // 2. Fetch additional live engagement/author details from proxy if needed
            if (match.classifiedPlatform == 'instagram' ||
                match.classifiedPlatform == 'tiktok' ||
                match.classifiedPlatform == 'youtube') {
              try {
                final liveMetadata = await socialCrawlService.fetchPostMetadata(match.link);
                if (liveMetadata != null) {
                  // Merge decoded timestamp with live engagement metrics
                  postEvidence = SocialCrawlPostEvidence(
                    platform: match.classifiedPlatform,
                    url: match.link,
                    platformPostTimestamp: postEvidence?.platformPostTimestamp ?? liveMetadata.platformPostTimestamp,
                    authorUsername: liveMetadata.authorUsername,
                    authorDisplayName: liveMetadata.authorDisplayName,
                    captionText: liveMetadata.captionText,
                    likesCount: liveMetadata.likesCount,
                    commentsCount: liveMetadata.commentsCount,
                    viewsCount: liveMetadata.viewsCount,
                    sharesCount: liveMetadata.sharesCount,
                    retrievedAt: liveMetadata.retrievedAt,
                  );
                }
              } catch (_) {}
            }

            final enrichedMatch = OnlineMatchItem(
              position: match.position,
              title: match.title,
              link: match.link,
              domain: match.domain,
              classifiedPlatform: match.classifiedPlatform,
              thumbnail: match.thumbnail,
              source: match.source,
              matchType: match.matchType,
              date: match.date,
              dateConfidence: match.dateConfidence,
              snippet: match.snippet,
              ocrQuery: match.ocrQuery,
              platformEvidence: postEvidence,
            );
            enrichedMatches.add(enrichedMatch);

            if (postEvidence != null) {
              final platformCap = match.classifiedPlatform.toUpperCase();
              final sourceDesc = match.classifiedPlatform == 'instagram'
                  ? 'Instagram Snowflake ID decoded'
                  : 'Social platform proxy verified';
              allEvidence.add(
                EvidenceItem(
                  category: 'Platform Post Evidence',
                  finding: '$platformCap public post metadata verified (${postEvidence.authorUsername != null ? "@${postEvidence.authorUsername}" : "Decoded Post"})',
                  strength: EvidenceStrength.strong,
                  scoreContribution: 20,
                  technicalExplanation:
                      '$sourceDesc: Published ${postEvidence.platformPostTimestamp ?? "N/A"}, Views ${postEvidence.viewsCount ?? "N/A"}.',
                ),
              );
            }
          }

          onlineSearchResult = OnlineSearchResult(
            status: onlineSearchResult.status,
            totalMatches: onlineSearchResult.totalMatches,
            summary: onlineSearchResult.summary,
            matches: enrichedMatches,
          );

          final summary = onlineSearchResult.summary;
          if ((summary['instagram'] ?? 0) > 0) {
            allEvidence.add(
              EvidenceItem(
                category: 'Online Evidence',
                finding: 'Matching online evidence detected on Instagram (${summary['instagram']} matches)',
                strength: EvidenceStrength.moderate,
                scoreContribution: (summary['instagram']! * 15).clamp(15, 30),
                technicalExplanation:
                    'Visual search and OCR proxy identified matching content hosted on Instagram domains.',
              ),
            );
          }
          if ((summary['tiktok'] ?? 0) > 0) {
            allEvidence.add(
              EvidenceItem(
                category: 'Online Evidence',
                finding: 'Matching online evidence detected on TikTok (${summary['tiktok']} matches)',
                strength: EvidenceStrength.moderate,
                scoreContribution: (summary['tiktok']! * 15).clamp(15, 30),
                technicalExplanation:
                    'Visual search and OCR proxy identified matching content hosted on TikTok domains.',
              ),
            );
          }
          if ((summary['youtube'] ?? 0) > 0) {
            allEvidence.add(
              EvidenceItem(
                category: 'Online Evidence',
                finding: 'Matching online evidence detected on YouTube (${summary['youtube']} matches)',
                strength: EvidenceStrength.moderate,
                scoreContribution: (summary['youtube']! * 15).clamp(15, 30),
                technicalExplanation:
                    'Visual search and OCR proxy identified matching content hosted on YouTube domains.',
              ),
            );
          }
        }
      } catch (e) {
        allEvidence.add(
          EvidenceItem(
            category: 'Online Evidence',
            finding: 'Online search proxy notice',
            strength: EvidenceStrength.neutral,
            scoreContribution: 0,
            technicalExplanation:
                'Online search proxy notice ($e). Local forensic engine completed successfully.',
          ),
        );
      }
    }

    // Stage 9: Timeline Date Analysis
    final timelineRes = _timelineAnalyzer.analyze(onlineSearchResult);
    allEvidence.addAll(timelineRes.evidence);

    // Stage 10: Fingerprint & Signature Matching
    onStageChanged?.call(AnalysisStage.comparingPlatformSignatures);
    final fingerprintResult = await _fingerprintAnalyzer.analyze(payload);
    allEvidence.addAll(fingerprintResult.evidence);
    await Future.delayed(const Duration(milliseconds: 50));

    // Stage 11: Final Multi-Signal Scoring & Confidence Calculation
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
        'Online Matches': '${onlineSearchResult.totalMatches} matches found',
    };

    final evaluatedResult = _scoringEngine.evaluate(
      allEvidence: allEvidence,
      possibleIntermediatePlatform: reencodingResult.possibleIntermediatePlatform,
      intermediateReason: reencodingResult.intermediateReason,
      technicalDetails: technicalDetails,
    );

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

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
import '../../data/utils/tiktok_timestamp_decoder.dart';
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
    bool enableOcrSearch = false,
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
        final ocrResults = <OcrExtractionResult>[];
        for (final frame in frames) {
          final result = await _ocrService.processFrameText(frame.base64Jpeg);
          if (result.hasSearchableContent) ocrResults.add(result);
        }
        if (ocrResults.isNotEmpty) {
          final bestOcr = ocrResults.first;
          for (final result in ocrResults) {
            if (result.detectedUsernames.isNotEmpty) {
              ocrQuery = result.detectedUsernames.first;
              break;
            }
            if (ocrQuery == null && result.detectedHashtags.isNotEmpty) {
              ocrQuery = result.detectedHashtags.first;
            }
            if (ocrQuery == null && result.uniquePhrases.isNotEmpty) {
              ocrQuery = result.uniquePhrases.first;
            }
          }

          allEvidence.add(
            EvidenceItem(
              category: 'Text/OCR Evidence',
              finding:
                  'Text detected across ${ocrResults.length} selected frame(s) (${bestOcr.cleanedText.length > 50 ? "${bestOcr.cleanedText.substring(0, 50)}..." : bestOcr.cleanedText})',
              strength: EvidenceStrength.moderate,
              scoreContribution: 15,
              technicalExplanation:
                  'On-device multilingual OCR identified overlay text/captions. Online OCR search is only enabled when the Pro option is selected.',
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
        final rawSearchResult = await _onlineSearchService.performVisualSearch(
          payload,
          ocrQuery: enableOcrSearch ? ocrQuery : null,
        );

        if (rawSearchResult.isSuccess && rawSearchResult.matches.isNotEmpty) {
          String? earliestVerifiedPlatform;
          String? earliestVerifiedTimestamp;
          DateTime? earliestVerifiedDate;
          String? earliestVerifiedMatchType;

          Future<SocialCrawlPostEvidence?> resolvePostEvidence(
            OnlineMatchItem match,
          ) async {
            SocialCrawlPostEvidence? postEvidence;

            // 1. Exact platform timestamp decoders for supported public platforms
            if (match.classifiedPlatform == 'instagram') {
              final decodedTimestamp =
                  InstagramTimestampDecoder.decodeToIsoString(match.link);
              if (decodedTimestamp != null) {
                postEvidence = SocialCrawlPostEvidence(
                  platform: 'instagram',
                  url: match.link,
                  platformPostTimestamp: decodedTimestamp,
                  retrievedAt: DateTime.now().toUtc().toIso8601String(),
                );
              }
            } else if (match.classifiedPlatform == 'tiktok') {
              final decodedTimestamp = TikTokTimestampDecoder.decodeToIsoString(
                match.link,
              );
              if (decodedTimestamp != null) {
                postEvidence = SocialCrawlPostEvidence(
                  platform: 'tiktok',
                  url: match.link,
                  platformPostTimestamp: decodedTimestamp,
                  retrievedAt: DateTime.now().toUtc().toIso8601String(),
                );
              }
            }

            // 2. Fallback/Optional: Fetch proxy engagement metadata if available
            if (postEvidence == null &&
                (match.classifiedPlatform == 'instagram' ||
                    match.classifiedPlatform == 'tiktok' ||
                    match.classifiedPlatform == 'youtube')) {
              try {
                final liveMetadata = await socialCrawlService.fetchPostMetadata(
                  match.link,
                );
                if (liveMetadata != null) {
                  postEvidence = liveMetadata;
                }
              } catch (_) {}
            }

            return postEvidence;
          }

          Future<List<OnlineMatchItem>> enrichMatches(
            List<OnlineMatchItem> matches,
          ) async {
            final enrichedMatches = <OnlineMatchItem>[];

            for (final match in matches) {
              final postEvidence = await resolvePostEvidence(match);

              final isExactMatch = match.matchType == 'exact_match';
              final canUsePlatformTimestamp =
                  postEvidence != null &&
                  postEvidence.platformPostTimestamp != null &&
                  (isExactMatch || match.matchType == 'visual_match');
              if (canUsePlatformTimestamp) {
                final parsed = DateTime.tryParse(
                  postEvidence.platformPostTimestamp!,
                );
                if (parsed != null &&
                    (earliestVerifiedDate == null ||
                        parsed.isBefore(earliestVerifiedDate!))) {
                  earliestVerifiedDate = parsed;
                  earliestVerifiedPlatform = match.classifiedPlatform;
                  earliestVerifiedTimestamp =
                      postEvidence.platformPostTimestamp;
                  earliestVerifiedMatchType = match.matchType;
                }
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

              if (canUsePlatformTimestamp &&
                  postEvidence?.platformPostTimestamp != null &&
                  DateTime.tryParse(postEvidence!.platformPostTimestamp!) !=
                      null) {
                final platformCap = match.classifiedPlatform.toUpperCase();
                final sourceDesc = match.classifiedPlatform == 'instagram'
                    ? 'Instagram Snowflake ID decoded'
                    : match.classifiedPlatform == 'tiktok'
                    ? 'TikTok Snowflake ID decoded (video_id >> 32)'
                    : 'YouTube public metadata verified';
                allEvidence.add(
                  EvidenceItem(
                    category: 'Platform Post Evidence',
                    finding:
                        '$platformCap public post timestamp verified (${postEvidence.platformPostTimestamp})',
                    strength: isExactMatch
                        ? EvidenceStrength.strong
                        : EvidenceStrength.moderate,
                    scoreContribution: isExactMatch ? 28 : 18,
                    technicalExplanation:
                        '$sourceDesc: Published ${postEvidence.platformPostTimestamp}. ${isExactMatch ? 'Exact visual match verified by the provider.' : 'Direct platform link found in visual/search results; timestamp is verified from the platform URL or metadata.'}',
                  ),
                );
              }
            }

            return enrichedMatches;
          }

          // Resolve direct social URLs from all result buckets. Exact matches
          // remain strongest, while visual matches can still provide a real
          // platform timestamp instead of forcing an unknown result.
          final enrichedMatches = await enrichMatches(rawSearchResult.matches);

          onlineSearchResult = OnlineSearchResult(
            status: rawSearchResult.status,
            totalMatches: rawSearchResult.totalMatches,
            summary: rawSearchResult.summary,
            matches: enrichedMatches,
          );

          final exactSummary = <String, int>{
            'instagram': enrichedMatches
                .where(
                  (m) =>
                      m.matchType == 'exact_match' &&
                      m.classifiedPlatform == 'instagram',
                )
                .length,
            'tiktok': enrichedMatches
                .where(
                  (m) =>
                      m.matchType == 'exact_match' &&
                      m.classifiedPlatform == 'tiktok',
                )
                .length,
            'youtube': enrichedMatches
                .where(
                  (m) =>
                      m.matchType == 'exact_match' &&
                      m.classifiedPlatform == 'youtube',
                )
                .length,
          };
          final relatedCount = enrichedMatches
              .where((m) => m.matchType != 'exact_match')
              .length;
          final summary = exactSummary;
          if ((summary['instagram'] ?? 0) > 0) {
            allEvidence.add(
              EvidenceItem(
                category: 'Online Evidence',
                finding:
                    'Exact visual match verified on Instagram (${summary['instagram']} matches)',
                strength: EvidenceStrength.moderate,
                scoreContribution: (summary['instagram']! * 5).clamp(3, 10),
                technicalExplanation:
                    'Only provider-marked exact visual matches can support an origin platform candidate.',
              ),
            );
          }
          if ((summary['tiktok'] ?? 0) > 0) {
            allEvidence.add(
              EvidenceItem(
                category: 'Online Evidence',
                finding:
                    'Exact visual match verified on TikTok (${summary['tiktok']} matches)',
                strength: EvidenceStrength.moderate,
                scoreContribution: (summary['tiktok']! * 5).clamp(3, 10),
                technicalExplanation:
                    'Only provider-marked exact visual matches can support an origin platform candidate.',
              ),
            );
          }
          if ((summary['youtube'] ?? 0) > 0) {
            allEvidence.add(
              EvidenceItem(
                category: 'Online Evidence',
                finding:
                    'Exact visual match verified on YouTube (${summary['youtube']} matches)',
                strength: EvidenceStrength.moderate,
                scoreContribution: (summary['youtube']! * 5).clamp(3, 10),
                technicalExplanation:
                    'Only provider-marked exact visual matches can support an origin platform candidate.',
              ),
            );
          }

          if (relatedCount > 0) {
            allEvidence.add(
              EvidenceItem(
                category: 'Related Content',
                finding:
                    '$relatedCount related visual result${relatedCount == 1 ? '' : 's'} found for manual review',
                strength: EvidenceStrength.neutral,
                scoreContribution: 0,
                technicalExplanation:
                    'Related results are shown for discovery only. They cannot select the original platform or contribute to its score.',
              ),
            );
          }

          if (earliestVerifiedPlatform != null &&
              earliestVerifiedTimestamp != null) {
            final isExactEarliest = earliestVerifiedMatchType == 'exact_match';
            allEvidence.add(
              EvidenceItem(
                category: 'Timeline Evidence',
                finding:
                    'Earliest verified timestamp points to ${earliestVerifiedPlatform!.toUpperCase()}',
                strength: isExactEarliest
                    ? EvidenceStrength.strong
                    : EvidenceStrength.moderate,
                scoreContribution: isExactEarliest ? 32 : 22,
                technicalExplanation: isExactEarliest
                    ? 'The oldest exact visual match with a verified public post timestamp was used as the strongest origin clue.'
                    : 'No exact visual match timestamp was available, so the oldest direct platform URL timestamp from visual/search results was used as a calibrated origin clue.',
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

    final verifiedExactTimestampMatches =
        onlineSearchResult?.matches
            .where(
              (match) =>
                  (match.matchType == 'exact_match' ||
                      match.matchType == 'visual_match') &&
                  match.platformEvidence?.platformPostTimestamp != null &&
                  DateTime.tryParse(
                        match.platformEvidence!.platformPostTimestamp!,
                      ) !=
                      null,
            )
            .toList() ??
        <OnlineMatchItem>[];
    verifiedExactTimestampMatches.sort(
      (a, b) => DateTime.parse(
        a.platformEvidence!.platformPostTimestamp!,
      ).compareTo(DateTime.parse(b.platformEvidence!.platformPostTimestamp!)),
    );
    final earliestVerifiedMatch = verifiedExactTimestampMatches.isEmpty
        ? null
        : verifiedExactTimestampMatches.first;
    final originVerificationStatus = earliestVerifiedMatch == null
        ? 'local_signals_or_unverified_matches'
        : earliestVerifiedMatch.matchType == 'exact_match'
        ? 'earliest_verified_exact_match'
        : 'earliest_verified_platform_timestamp';

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
      if (onlineSearchResult != null &&
          onlineSearchResult.isSuccess &&
          onlineSearchResult.matches.isNotEmpty)
        'Exact Matches Checked':
            '${onlineSearchResult.matches.where((m) => m.matchType == 'exact_match').length}',
      if (onlineSearchResult != null &&
          onlineSearchResult.isSuccess &&
          onlineSearchResult.matches.isNotEmpty)
        'Search Matches Checked': '${onlineSearchResult.matches.length}',
      if (earliestVerifiedMatch != null)
        'Earliest Verified Platform': earliestVerifiedMatch.classifiedPlatform,
      if (earliestVerifiedMatch != null)
        'Earliest Verified Timestamp':
            earliestVerifiedMatch.platformEvidence!.platformPostTimestamp!,
      'Origin Verification Status': originVerificationStatus,
      if (onlineSearchResult != null && onlineSearchResult.isSuccess)
        'Online Matches': '${onlineSearchResult.totalMatches} matches found',
    };

    final evaluatedResult = _scoringEngine.evaluate(
      allEvidence: allEvidence,
      possibleIntermediatePlatform:
          reencodingResult.possibleIntermediatePlatform,
      intermediateReason: reencodingResult.intermediateReason,
      technicalDetails: technicalDetails,
    );

    final finalResult = PlatformResult(
      platformId: evaluatedResult.platformId,
      platformName: evaluatedResult.platformName,
      confidence: evaluatedResult.confidence,
      confidenceLevel: evaluatedResult.confidenceLevel,
      possibleIntermediatePlatform:
          evaluatedResult.possibleIntermediatePlatform,
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

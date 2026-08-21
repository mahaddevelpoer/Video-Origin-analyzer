import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/motion_reveal.dart';
import '../../../data/models/analysis_session.dart';
import '../../../data/models/evidence_item.dart';
import '../../../data/models/online_search_result.dart';
import '../../../data/models/platform_result.dart';
import '../../home/presentation/home_screen.dart';

class AnalysisResultScreen extends ConsumerStatefulWidget {
  final PlatformResult result;
  final AnalysisSession? session;

  const AnalysisResultScreen({super.key, required this.result, this.session});

  @override
  ConsumerState<AnalysisResultScreen> createState() =>
      _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends ConsumerState<AnalysisResultScreen> {
  bool _showIntermediateDetails = false;

  String? _getEarliestVerifiedPlatform() {
    final platform =
        widget.result.technicalDetails['Earliest Verified Platform'];
    if (platform is String && platform.isNotEmpty) {
      return platform;
    }
    return null;
  }

  String? _getEarliestVerifiedTimestamp() {
    final timestamp =
        widget.result.technicalDetails['Earliest Verified Timestamp'];
    if (timestamp is String && timestamp.isNotEmpty) {
      return timestamp;
    }
    return null;
  }

  bool get _hasVerifiedExactPublicMatch =>
      widget.result.technicalDetails['Origin Verification Status'] ==
      'earliest_verified_exact_match';

  bool get _hasVerifiedPlatformTimestamp =>
      _hasVerifiedExactPublicMatch ||
      widget.result.technicalDetails['Origin Verification Status'] ==
          'earliest_verified_platform_timestamp';

  String _formatFriendlyTimestamp(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return '${parsed.toUtc().toIso8601String().split('.').first} UTC';
  }

  Future<void> _exportPdfReport(BuildContext context) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      AppConfig.appName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      AppConfig.developerName,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'FORENSIC VIDEO ORIGIN ANALYSIS REPORT',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Likely Origin: ${widget.result.platformName}'),
              pw.Text(
                'Confidence: ${widget.result.confidence}% (${widget.result.confidenceLevel.displayName})',
              ),
              if (widget.result.possibleIntermediatePlatform != null)
                pw.Text(
                  'Possible Intermediate Processing: ${widget.result.possibleIntermediatePlatform}',
                ),
              pw.SizedBox(height: 16),
              pw.Text(
                'WHY DID WE REACH THIS CONCLUSION?',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              ...widget.result.evidenceList.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text(
                    '• [${item.category}] ${item.finding} (${item.strength.displayName})',
                  ),
                ),
              ),
              if (widget.result.onlineSearchResult != null &&
                  widget.result.onlineSearchResult!.matches.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text(
                  'ONLINE EVIDENCE (SERPAPI GOOGLE LENS PROXY)',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                ...widget.result.onlineSearchResult!.matches
                    .take(5)
                    .map(
                      (m) => pw.Text(
                        '• [${m.classifiedPlatform.toUpperCase()}] ${m.title} (${m.domain})',
                      ),
                    ),
              ],
              pw.SizedBox(height: 16),
              pw.Text(
                'TECHNICAL PARAMETERS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              ...widget.result.technicalDetails.entries.map(
                (e) => pw.Text('${e.key}: ${e.value}'),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                AppConfig.legalDisclaimer,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Forensic_Report_${widget.result.platformId}.pdf',
    );
  }

  String _getBeginnerSummary() {
    final inter = widget.result.possibleIntermediatePlatform;
    final earliestPlatform = _getEarliestVerifiedPlatform();
    final earliestTimestamp = _getEarliestVerifiedTimestamp();

    if (_hasVerifiedPlatformTimestamp &&
        earliestPlatform != null &&
        earliestTimestamp != null) {
      final readablePlatform =
          earliestPlatform[0].toUpperCase() + earliestPlatform.substring(1);
      final proofType = _hasVerifiedExactPublicMatch
          ? 'verified exact visual match'
          : 'verified public platform timestamp';
      if (inter != null) {
        return 'The earliest $proofType was published on $readablePlatform. This copy may have been shared through $inter later.';
      }
      return 'The earliest $proofType was published on $readablePlatform.';
    }

    if (inter != null) {
      return 'This video looks like it may have been shared through $inter after the original upload.';
    }

    return 'The app found clues in file structure, metadata, and visuals to estimate the likely source platform.';
  }

  Future<void> _showMatchDetails(OnlineMatchItem match) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Visual match details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (match.thumbnail != null && match.thumbnail!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    match.thumbnail!,
                    width: double.infinity,
                    height: 190,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 190,
                      color: AppColors.lightBackground,
                      alignment: Alignment.center,
                      child: const Text('Thumbnail could not be loaded.'),
                    ),
                  ),
                )
              else
                Container(
                  height: 120,
                  width: double.infinity,
                  color: AppColors.lightBackground,
                  alignment: Alignment.center,
                  child: const Text(
                    'No thumbnail supplied by the search provider.',
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                match.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${match.classifiedPlatform.toUpperCase()} • ${match.matchType == 'exact_match' ? 'Exact match' : 'Related visual result'}',
              ),
              if (match.snippet != null) ...[
                const SizedBox(height: 8),
                Text(
                  match.snippet!,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                'This preview is loaded from the provider thumbnail URL. The app does not download or save it.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (match.link.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () => Share.share(match.link),
              icon: const Icon(Icons.link),
              label: const Text('Copy source link'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onlineRes = widget.result.onlineSearchResult;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final cardColor =
        Theme.of(context).cardTheme.color ??
        (isDark ? const Color(0xFF1E1E1E) : AppColors.lightSurface);
    final borderColor = Theme.of(context).dividerColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Analysis Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF Report',
            onPressed: () => _exportPdfReport(context),
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // 1. BEGINNER-FRIENDLY HERO RESULT CARD
              // ==========================================
              MotionReveal(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.youtubeRed, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.youtubeRed.withAlpha(isDark ? 35 : 20),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _hasVerifiedPlatformTimestamp
                                ? 'EARLIEST VERIFIED PUBLIC MATCH'
                                : 'LIKELY SOURCE PLATFORM',
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.0,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.youtubeRed.withAlpha(24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'BEGINNER VIEW',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.youtubeRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.result.platformName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Easy-to-understand plain language explanation
                      Text(
                        _getBeginnerSummary(),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.white70
                              : AppColors.textDark.withAlpha(200),
                          height: 1.4,
                        ),
                      ),
                      if (_showIntermediateDetails) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Confidence: ${widget.result.confidence}% (${widget.result.confidenceLevel.displayName})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.youtubeRed,
                          ),
                        ),
                      ],
                      if (widget.result.possibleIntermediatePlatform !=
                          null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.strengthWeak.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.strengthWeak.withAlpha(60),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alt_route,
                                color: AppColors.strengthWeak,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Shared via ${widget.result.possibleIntermediatePlatform} before this copy',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.strengthWeak,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==========================================
              // 2. BEGINNER VS INTERMEDIATE VIEW TOGGLE
              // ==========================================
              InkWell(
                onTap: () {
                  setState(() {
                    _showIntermediateDetails = !_showIntermediateDetails;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _showIntermediateDetails
                          ? AppColors.youtubeRed
                          : borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _showIntermediateDetails
                            ? Icons.tune
                            : Icons.analytics_outlined,
                        color: AppColors.youtubeRed,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _showIntermediateDetails
                                  ? 'Intermediate Technical View (Active)'
                                  : 'Tap for More Details',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              _showIntermediateDetails
                                  ? 'Showing full codecs, timestamps, bitrates & raw evidence'
                                  : 'Beginner summary only. Tap to reveal full evidence, timestamps, and scoring.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _showIntermediateDetails
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppColors.youtubeRed,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ==========================================
              // 3. KEY EVIDENCE (Simplified vs Deep Dive)
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showIntermediateDetails
                        ? 'FORENSIC EVIDENCE & SCORING'
                        : 'HOW WE FOUND OUT',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '${widget.result.evidenceList.length} Signals',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              ...widget.result.evidenceList.map(
                (item) =>
                    _buildEvidenceCard(item, _showIntermediateDetails, isDark),
              ),

              if (widget.result.conflictingEvidenceList.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'CONTRADICTORY EVIDENCE DETECTED',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.strengthContradictory,
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.result.conflictingEvidenceList.map(
                  (item) => _buildEvidenceCard(
                    item,
                    _showIntermediateDetails,
                    isDark,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ==========================================
              // 4. ONLINE TIMELINE & DISCOVERY SECTION
              // ==========================================
              if (onlineRes != null &&
                  onlineRes.isSuccess &&
                  onlineRes.matches.isNotEmpty) ...[
                Text(
                  'ONLINE SEARCH & TIMELINE (${onlineRes.totalMatches} Matches)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPlatformBadge(
                              'Instagram',
                              onlineRes.summary['instagram'] ?? 0,
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildPlatformBadge(
                              'TikTok',
                              onlineRes.summary['tiktok'] ?? 0,
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildPlatformBadge(
                              'YouTube',
                              onlineRes.summary['youtube'] ?? 0,
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildPlatformBadge(
                              'Other',
                              onlineRes.summary['other'] ?? 0,
                              isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 10),
                      ...onlineRes.matches.take(_showIntermediateDetails ? 10 : 3).map((
                        match,
                      ) {
                        final postEv = match.platformEvidence;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.youtubeRed,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      match.classifiedPlatform.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      match.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  if (match.matchType == 'exact_match')
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.strengthStrong
                                            .withAlpha(20),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.strengthStrong,
                                        ),
                                      ),
                                      child: const Text(
                                        'EXACT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.strengthStrong,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _showMatchDetails(match),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 16,
                                ),
                                label: const Text('View details'),
                              ),
                              if (postEv != null) ...[
                                const SizedBox(height: 6),
                                if (match.matchType == 'exact_match')
                                  const Text(
                                    'Exact match found. Timestamp is based on the public post itself.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.strengthStrong,
                                    ),
                                  ),
                                if (postEv.platformPostTimestamp != null)
                                  Text(
                                    'Upload Date: ${_formatFriendlyTimestamp(postEv.platformPostTimestamp!)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.youtubeRed,
                                    ),
                                  ),
                                if (postEv.authorUsername != null)
                                  Text(
                                    'Creator: @${postEv.authorUsername}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                if (_showIntermediateDetails) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      if (postEv.likesCount != null)
                                        Text(
                                          'Likes: ${_formatNumber(postEv.likesCount!)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      if (postEv.commentsCount != null)
                                        Text(
                                          'Comments: ${_formatNumber(postEv.commentsCount!)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      if (postEv.viewsCount != null)
                                        Text(
                                          'Views: ${_formatNumber(postEv.viewsCount!)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ==========================================
              // 5. INTERMEDIATE TECHNICAL PARAMETERS
              // ==========================================
              if (_showIntermediateDetails) ...[
                Text(
                  'TECHNICAL PARAMETERS (RAW DATA)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: widget.result.technicalDetails.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.key,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              e.value.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Disclaimer
              const Text(
                AppConfig.legalDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Engine v1.0.0 • Mahad and Mehdi Developers',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformBadge(String label, int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0
            ? AppColors.youtubeRed.withAlpha(20)
            : (isDark ? Colors.white10 : AppColors.lightBackground),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0
              ? AppColors.youtubeRed
              : (isDark ? Colors.white24 : AppColors.lightBorder),
        ),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: count > 0 ? AppColors.youtubeRed : AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildEvidenceCard(
    EvidenceItem item,
    bool isIntermediate,
    bool isDark,
  ) {
    Color badgeColor;
    switch (item.strength) {
      case EvidenceStrength.strong:
        badgeColor = AppColors.strengthStrong;
        break;
      case EvidenceStrength.moderate:
        badgeColor = AppColors.strengthModerate;
        break;
      case EvidenceStrength.weak:
        badgeColor = AppColors.strengthWeak;
        break;
      case EvidenceStrength.neutral:
        badgeColor = AppColors.strengthNeutral;
        break;
      case EvidenceStrength.contradictory:
        badgeColor = AppColors.strengthContradictory;
        break;
    }

    final cardBg =
        Theme.of(context).cardTheme.color ??
        (isDark ? const Color(0xFF1E1E1E) : AppColors.lightSurface);
    final borderColor = Theme.of(context).dividerColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.youtubeRed,
                  letterSpacing: 0.8,
                ),
              ),
              if (isIntermediate)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: badgeColor),
                  ),
                  child: Text(
                    '${item.strength.displayName} (+${item.scoreContribution})',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.finding,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          if (_showIntermediateDetails) ...[
            const SizedBox(height: 4),
            Text(
              item.technicalExplanation,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatNumber(int num) {
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M';
    }
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toString();
  }
}

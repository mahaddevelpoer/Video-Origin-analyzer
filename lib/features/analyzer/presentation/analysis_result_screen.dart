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

class _AnalysisResultScreenState extends ConsumerState<AnalysisResultScreen>
    with TickerProviderStateMixin {
  bool _showIntermediateDetails = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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
              if (widget.result.onlineSearchResult?.aiAnalysis != null) ...[
                pw.SizedBox(height: 14),
                pw.Text(
                  'VISUAL CONTEXT & AI REVIEW',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(widget.result.onlineSearchResult!.aiAnalysis!.summary, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                if (widget.result.onlineSearchResult!.aiAnalysis!.isAvailable) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('Context: ${widget.result.onlineSearchResult!.aiAnalysis!.contextAnalysis}'),
                ],
                pw.SizedBox(height: 6),
                pw.Text(
                  'AI Platform: ${widget.result.onlineSearchResult!.aiAnalysis!.likelyPlatform.toUpperCase()} (${widget.result.onlineSearchResult!.aiAnalysis!.confidence}%)',
                ),
                ...widget.result.onlineSearchResult!.aiAnalysis!.conflicts.map(
                  (item) => pw.Text('Conflict: $item'),
                ),
              ],
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
                  'ONLINE EVIDENCE (GEMINI + SERPAPI LENS PROXY)',
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

  Widget _buildPulsingGauge(
    double targetConfidence,
    Color themeAccent,
    bool isDark,
    Color textColor,
  ) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowScale = 1.0 + (_pulseAnimation.value * 0.08);
        final glowAlpha = (30 + (_pulseAnimation.value * 55)).round();
        return SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Living Pulse Beacon Ring
              Transform.scale(
                scale: glowScale,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: themeAccent.withAlpha(glowAlpha),
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: targetConfidence / 100.0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 5.0,
                          backgroundColor: isDark
                              ? Colors.white10
                              : AppColors.lightBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            themeAccent,
                          ),
                        ),
                      ),
                      Text(
                        '${(value * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildForensicTimelineFlow(
    AiEvidenceAnalysis? ai,
    Color themeAccent,
    bool isDark,
    Color textColor,
    Color borderColor,
  ) {
    final earliestPlatform =
        _getEarliestVerifiedPlatform() ?? widget.result.platformName;
    final intermediate = widget.result.possibleIntermediatePlatform;
    final earliestTime = _getEarliestVerifiedTimestamp();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeAccent.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, size: 16, color: themeAccent),
              const SizedBox(width: 6),
              Text(
                'FORENSIC ORIGIN FLOW & PIPELINE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: themeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Node 1: Original Source Platform
              Expanded(
                child: _buildFlowNode(
                  label: earliestPlatform.toUpperCase(),
                  subLabel: earliestTime != null
                      ? _formatFriendlyTimestamp(earliestTime)
                      : 'Original Source',
                  color: themeAccent,
                  icon: Icons.upload_file_rounded,
                  isDark: isDark,
                ),
              ),

              // Animated Connector 1
              _buildFlowConnector(themeAccent),

              // Node 2: Intermediate (if present) or Visual Check
              if (intermediate != null) ...[
                Expanded(
                  child: _buildFlowNode(
                    label: intermediate.toUpperCase(),
                    subLabel: 'Re-compressed',
                    color: AppColors.strengthWeak,
                    icon: Icons.alt_route_rounded,
                    isDark: isDark,
                  ),
                ),
                _buildFlowConnector(AppColors.strengthWeak),
              ],

              // Node 3: Current Video Analyzed
              Expanded(
                child: _buildFlowNode(
                  label: 'THIS COPY',
                  subLabel: 'Analyzed File',
                  color: isDark ? Colors.white70 : AppColors.textDark,
                  icon: Icons.movie_outlined,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowNode({
    required String label,
    required String subLabel,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowConnector(Color color) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 2,
              width: 12,
              color: color.withAlpha(
                (100 + (_pulseAnimation.value * 155)).round(),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: color.withAlpha(
                (140 + (_pulseAnimation.value * 115)).round(),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getThemeAccentColor(AiEvidenceAnalysis? ai) {
    if (ai == null || !ai.isAvailable) return AppColors.youtubeRed;
    switch (ai.investigationMode) {
      case InvestigationUiMode.verifiedOrigin:
        return const Color(0xFF00C853); // Emerald Green
      case InvestigationUiMode.deepfakeRisk:
        return const Color(0xFFFF1744); // Crimson Red
      case InvestigationUiMode.crossPlatformRepost:
        return const Color(0xFF7C4DFF); // Deep Violet
      case InvestigationUiMode.unconfirmedCopy:
        return const Color(0xFFFF9100); // Amber Orange
    }
  }

  IconData _getModeIcon(AiEvidenceAnalysis? ai) {
    if (ai == null || !ai.isAvailable) return Icons.verified_user_outlined;
    switch (ai.investigationMode) {
      case InvestigationUiMode.verifiedOrigin:
        return Icons.verified_rounded;
      case InvestigationUiMode.deepfakeRisk:
        return Icons.gpp_maybe_rounded;
      case InvestigationUiMode.crossPlatformRepost:
        return Icons.alt_route_rounded;
      case InvestigationUiMode.unconfirmedCopy:
        return Icons.saved_search_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final onlineRes = widget.result.onlineSearchResult;
    final ai = onlineRes?.aiAnalysis;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final cardColor =
        Theme.of(context).cardTheme.color ??
        (isDark ? const Color(0xFF1E1E1E) : AppColors.lightSurface);
    final borderColor = Theme.of(context).dividerColor;
    final themeAccent = _getThemeAccentColor(ai);
    final modeIcon = _getModeIcon(ai);

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
              // 1. AI-DRIVEN DYNAMIC HERO RESULT CARD
              // ==========================================
              MotionReveal(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: themeAccent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: themeAccent.withAlpha(isDark ? 55 : 35),
                        blurRadius: 20,
                        spreadRadius: 1,
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
                          Expanded(
                            child: Row(
                              children: [
                                Icon(modeIcon, color: themeAccent, size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    ai != null && ai.isAvailable
                                        ? ai.verdictHeadline
                                        : (_hasVerifiedPlatformTimestamp
                                            ? 'EARLIEST VERIFIED PUBLIC MATCH'
                                            : 'LIKELY SOURCE PLATFORM'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      letterSpacing: 0.8,
                                      color: themeAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: themeAccent.withAlpha(24),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: themeAccent.withAlpha(90)),
                            ),
                            child: Text(
                              ai != null && ai.isAvailable
                                  ? ai.investigationMode.name.toUpperCase()
                                  : 'STANDARD VIEW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: themeAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.result.platformName.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.result.confidenceLevel.displayName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: themeAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Living Pulsing Beacon Gauge
                          _buildPulsingGauge(
                            widget.result.confidence.toDouble(),
                            themeAccent,
                            isDark,
                            textColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Easy-to-understand plain language explanation
                      Text(
                        ai != null && ai.isAvailable ? ai.summary : _getBeginnerSummary(),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.white70
                              : AppColors.textDark.withAlpha(200),
                          height: 1.4,
                        ),
                      ),
                      // Animated Living Forensic Timeline Flowchart
                      _buildForensicTimelineFlow(ai, themeAccent, isDark, textColor, borderColor),
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
              // 2. GEMINI FORENSIC INTELLIGENCE CARD (TOP LEVEL)
              // ==========================================
              if (onlineRes?.aiAnalysis != null) ...[
                MotionReveal(
                  delay: const Duration(milliseconds: 100),
                  child: _buildAiEvidenceCard(
                    onlineRes!.aiAnalysis!,
                    _showIntermediateDetails,
                    isDark,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ==========================================
              // 3. MORE DETAILS / TECHNICAL VIEW TOGGLE
              // ==========================================
              MotionReveal(
                delay: const Duration(milliseconds: 180),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showIntermediateDetails = !_showIntermediateDetails;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showIntermediateDetails
                            ? themeAccent
                            : borderColor,
                        width: _showIntermediateDetails ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        if (_showIntermediateDetails)
                          BoxShadow(
                            color: themeAccent.withAlpha(25),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showIntermediateDetails
                              ? Icons.tune_rounded
                              : Icons.analytics_outlined,
                          color: themeAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _showIntermediateDetails
                                    ? 'Detailed Forensic View (Active)'
                                    : 'Tap for More Details & Evidence',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                _showIntermediateDetails
                                    ? 'Showing all evidence signals, web matches & raw codecs'
                                    : 'Tap to expand full forensic signals, web matches, and technical parameters.',
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
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: themeAccent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==========================================
              // 4. ANIMATED MORE DETAILS DRAWER (COLLAPSIBLE)
              // ==========================================
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                child: _showIntermediateDetails
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // KEY EVIDENCE & SIGNALS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FORENSIC EVIDENCE & SCORING',
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

                          ...widget.result.evidenceList.asMap().entries.map(
                            (entry) {
                              final item = entry.value;
                              return _buildEvidenceCard(item, _showIntermediateDetails, isDark);
                            },
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

                          // ONLINE SEARCH & TIMELINE SECTION
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
                                  ...onlineRes.matches.map((match) {
                                    final postEv = match.platformEvidence;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF161616) : Theme.of(context).scaffoldBackgroundColor,
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
                                                    color: AppColors.strengthStrong.withAlpha(20),
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
                                                'Exact match found. Timestamp is based on public post itself.',
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

                          // RAW TECHNICAL PARAMETERS
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
                      )
                    : const SizedBox.shrink(),
              ),

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

  Widget _buildAiEvidenceCard(
    AiEvidenceAnalysis ai,
    bool isIntermediate,
    bool isDark,
  ) {
    final cardBg =
        Theme.of(context).cardTheme.color ??
        (isDark ? const Color(0xFF1E1E1E) : AppColors.lightSurface);
    final borderColor = Theme.of(context).dividerColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final isAvailable = ai.isAvailable;
    final badgeColor = _getThemeAccentColor(ai);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withAlpha(120), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: badgeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'GEMINI FORENSIC INTELLIGENCE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withAlpha(120)),
                ),
                child: Text(
                  isAvailable ? '${ai.confidence}% AI CONFIDENCE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ai.summary,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, height: 1.35, color: textColor),
          ),
          if (isAvailable && ai.contextAnalysis.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.find_in_page_outlined, size: 14, color: badgeColor),
                      const SizedBox(width: 6),
                      const Text(
                        'Forensic Multi-Modal Analysis',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ai.contextAnalysis,
                    style: TextStyle(fontSize: 12, height: 1.4, color: textColor),
                  ),
                ],
              ),
            ),
          ],
          if (isAvailable) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildAiChip(
                  'Platform: ${ai.likelyPlatform.toUpperCase()}',
                  badgeColor,
                ),
                _buildAiChip('Risk: ${ai.riskLevel.toUpperCase()}', badgeColor),
                _buildAiChip('Mode: ${ai.investigationMode.name.toUpperCase()}', badgeColor),
                _buildAiChip(ai.model, AppColors.textMuted),
              ],
            ),
          ],
          if (isAvailable && ai.recommendedSearchQueries.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'RECOMMENDED SEARCH QUERIES (TAP TO COPY)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ai.recommendedSearchQueries.map((query) {
                return InkWell(
                  onTap: () {
                    Share.share(query);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied query: "$query"'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeColor.withAlpha(70)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded, size: 12, color: badgeColor),
                        const SizedBox(width: 6),
                        Text(
                          query,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (isAvailable && ai.sourceUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'VERIFIED SOURCE URLS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            ...ai.sourceUrls.map((url) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 14, color: AppColors.youtubeRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.youtubeRed,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 14),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Share.share(url),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (isIntermediate && isAvailable) ...[
            if (ai.evidenceReasons.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildAiList('Key Evidence Reasons', ai.evidenceReasons, textColor),
            ],
            if (ai.conflicts.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildAiList(
                'Conflicting Signals',
                ai.conflicts,
                AppColors.strengthContradictory,
              ),
            ],
          ],
          if (!isAvailable && ai.errorCode != null) ...[
            const SizedBox(height: 6),
            Text(
              'Code: ${ai.errorCode}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAiList(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              item,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
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
        border: Border(
          left: BorderSide(color: badgeColor, width: 4),
          top: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
        ),
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

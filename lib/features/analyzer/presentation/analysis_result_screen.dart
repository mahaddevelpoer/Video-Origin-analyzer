import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/analysis_session.dart';
import '../../../data/models/evidence_item.dart';
import '../../../data/models/platform_result.dart';
import '../../home/presentation/home_screen.dart';

class AnalysisResultScreen extends ConsumerWidget {
  final PlatformResult result;
  final AnalysisSession? session;

  const AnalysisResultScreen({
    super.key,
    required this.result,
    this.session,
  });

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
                    pw.Text(AppConfig.appName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text(AppConfig.developerName,
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('FORENSIC VIDEO ORIGIN ANALYSIS REPORT',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Likely Origin: ${result.platformName}'),
              pw.Text('Confidence: ${result.confidence}% (${result.confidenceLevel.displayName})'),
              if (result.possibleIntermediatePlatform != null)
                pw.Text('Possible Intermediate Processing: ${result.possibleIntermediatePlatform}'),
              pw.SizedBox(height: 16),
              pw.Text('WHY DID WE REACH THIS CONCLUSION?',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              ...result.evidenceList.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text('• [${item.category}] ${item.finding} (${item.strength.displayName})'),
                ),
              ),
              if (result.onlineSearchResult != null && result.onlineSearchResult!.matches.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text('ONLINE EVIDENCE (SERPAPI GOOGLE LENS PROXY)',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                ...result.onlineSearchResult!.matches.take(5).map(
                      (m) => pw.Text('• [${m.classifiedPlatform.toUpperCase()}] ${m.title} (${m.domain})'),
                    ),
              ],
              pw.SizedBox(height: 16),
              pw.Text('TECHNICAL PARAMETERS',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              ...result.technicalDetails.entries.map(
                (e) => pw.Text('${e.key}: ${e.value}'),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Text(AppConfig.legalDisclaimer,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Forensic_Report_${result.platformId}.pdf',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineRes = result.onlineSearchResult;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
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
              // Result Card
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.youtubeRed, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.youtubeRed.withAlpha(20),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESTIMATED ORIGINAL SOURCE',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.0,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        Text(
                          result.platformName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.youtubeRed,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${result.confidence}% ${result.confidenceLevel.displayName}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (result.possibleIntermediatePlatform != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 10),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Icon(Icons.alt_route, color: AppColors.strengthWeak, size: 18),
                          const Text(
                            'Possible Intermediate Processing:',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          Text(
                            result.possibleIntermediatePlatform!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.strengthWeak,
                            ),
                          ),
                        ],
                      ),
                      if (result.intermediateReason != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          result.intermediateReason!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ONLINE EVIDENCE SECTION (SerpApi Google Lens Proxy)
              const Text(
                'ONLINE EVIDENCE (SERPAPI GOOGLE LENS)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onlineRes != null && onlineRes.isSuccess && onlineRes.matches.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.travel_explore, color: AppColors.youtubeRed, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'ONLINE PLATFORM EVIDENCE (${onlineRes.totalMatches} Matches)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPlatformBadge('Instagram', onlineRes.summary['instagram'] ?? 0),
                            const SizedBox(width: 8),
                            _buildPlatformBadge('TikTok', onlineRes.summary['tiktok'] ?? 0),
                            const SizedBox(width: 8),
                            _buildPlatformBadge('YouTube', onlineRes.summary['youtube'] ?? 0),
                            const SizedBox(width: 8),
                            _buildPlatformBadge('Other', onlineRes.summary['other'] ?? 0),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 10),
                      ...onlineRes.matches.take(4).map((match) {
                        final postEv = match.platformEvidence;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                        color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                  if (match.link.isNotEmpty)
                                    InkWell(
                                      onTap: () {
                                        Share.share('Source Match URL: ${match.link}');
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Text(
                                          '[View Source]',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.youtubeRed,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (postEv != null) ...[
                                const SizedBox(height: 8),
                                if (postEv.platformPostTimestamp != null)
                                  Text(
                                    'Platform Post Date: ${postEv.platformPostTimestamp}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.youtubeRed),
                                  ),
                                if (postEv.authorUsername != null)
                                  Text(
                                    'Author: @${postEv.authorUsername}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    if (postEv.likesCount != null)
                                      Text('Likes: ${_formatNumber(postEv.likesCount!)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    if (postEv.commentsCount != null)
                                      Text('Comments: ${_formatNumber(postEv.commentsCount!)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    if (postEv.viewsCount != null)
                                      Text('Views: ${_formatNumber(postEv.viewsCount!)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    if (postEv.sharesCount != null)
                                      Text('Shares: ${_formatNumber(postEv.sharesCount!)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 4),
                                Text(
                                  match.domain,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.textMuted, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              onlineRes?.errorMessage ??
                                  'Online proxy search completed. Local forensic engine results used.',
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Note: Public platform timestamps indicate discovered platform post creation date and do not definitively prove original creator source upload without access to all historical/private copies.',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Why did we reach this conclusion?
              const Text(
                'WHY DID WE REACH THIS CONCLUSION?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),

              ...result.evidenceList.map((item) => _buildEvidenceCard(item)),

              if (result.conflictingEvidenceList.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'CONTRADICTORY EVIDENCE DETECTED',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.strengthContradictory,
                  ),
                ),
                const SizedBox(height: 10),
                ...result.conflictingEvidenceList.map((item) => _buildEvidenceCard(item)),
              ],

              const SizedBox(height: 24),

              // Technical Details Grid
              const Text(
                'TECHNICAL PARAMETERS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightBorder),
                ),
                child: Column(
                  children: result.technicalDetails.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            e.key,
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                          Text(
                            e.value.toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                AppConfig.legalDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),
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

  Widget _buildPlatformBadge(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? AppColors.youtubeRed.withAlpha(20) : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: count > 0 ? AppColors.youtubeRed : AppColors.lightBorder),
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

  Widget _buildEvidenceCard(EvidenceItem item) {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
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
                item.category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.youtubeRed,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 8),
          Text(
            item.finding,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.technicalExplanation,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
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

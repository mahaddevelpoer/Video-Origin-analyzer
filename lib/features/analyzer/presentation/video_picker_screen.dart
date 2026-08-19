import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../data/models/analysis_session.dart';
import '../../../data/models/input_video_payload.dart';
import '../../../data/utils/url_platform_detector.dart';
import '../../../data/utils/link_timestamp_resolver.dart';
import 'analysis_progress_screen.dart';
import 'frame_selection_screen.dart';

class VideoPickerScreen extends ConsumerStatefulWidget {
  const VideoPickerScreen({super.key});

  @override
  ConsumerState<VideoPickerScreen> createState() => _VideoPickerScreenState();
}

class _VideoPickerScreenState extends ConsumerState<VideoPickerScreen> {
  InputVideoPayload? _selectedPayload;
  bool _isPicking = false;
  String? _validationError;
  final TextEditingController _linkController = TextEditingController();
  LinkTimestampCheckResult? _linkCheckResult;
  bool _isCheckingLink = false;

  Future<void> _pickVideo() async {
    setState(() {
      _isPicking = true;
      _validationError = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: kIsWeb, // Ensure bytes are read on Web platform
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;

        if (kIsWeb) {
          if (platformFile.bytes == null || platformFile.bytes!.isEmpty) {
            setState(() => _validationError = 'Selected video file contains no bytes.');
            return;
          }
          setState(() {
            _selectedPayload = InputVideoPayload(
              name: platformFile.name,
              sizeInBytes: platformFile.size,
              bytes: platformFile.bytes,
            );
          });
        } else {
          if (platformFile.path == null) {
            setState(() => _validationError = 'Could not access local video file path.');
            return;
          }
          setState(() {
            _selectedPayload = InputVideoPayload(
              name: platformFile.name,
              sizeInBytes: platformFile.size,
              path: platformFile.path,
            );
          });
        }
      }
    } catch (e) {
      setState(() => _validationError = 'Error selecting video file: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _checkLinkTimestamp() async {
    final rawUrl = _linkController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _linkCheckResult = const LinkTimestampCheckResult(
          platform: DetectedPlatform.other,
          normalizedUrl: '',
          exactTimestampIso: null,
          message: 'Paste a link first.',
          supported: false,
        );
      });
      return;
    }

    setState(() => _isCheckingLink = true);
    try {
      final result = LinkTimestampResolver.resolve(rawUrl);
      if (!mounted) return;
      setState(() {
        _linkCheckResult = result;
      });
    } finally {
      if (mounted) setState(() => _isCheckingLink = false);
    }
  }

  Future<void> _chooseCropRegion() async {
    final selected = await showModalBottomSheet<CropRegion>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Crop video before visual search', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('The app will take its 3 screenshots from this selected area.', style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 16),
              _cropChoice(context, 'Full frame', 'Use the complete video frame.', CropRegion.full),
              _cropChoice(context, 'Center square', 'Remove side borders and focus on the subject.', const CropRegion(left: 0.12, top: 0, right: 0.88, bottom: 1)),
              _cropChoice(context, 'Center portrait', 'Focus on the central 9:16 content area.', const CropRegion(left: 0.22, top: 0, right: 0.78, bottom: 1)),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted && _selectedPayload != null) {
      setState(() {
        final payload = _selectedPayload!;
        _selectedPayload = InputVideoPayload(
          name: payload.name,
          sizeInBytes: payload.sizeInBytes,
          path: payload.path,
          bytes: payload.bytes,
          cropRegion: selected,
        );
      });
    }
  }

  Widget _cropChoice(BuildContext context, String title, String subtitle, CropRegion region) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.crop, color: AppColors.youtubeRed),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      onTap: () => Navigator.of(context).pop(region),
    );
  }

  void _startAnalysis() {
    if (_selectedPayload == null) return;

    if (!kIsWeb && _selectedPayload!.path != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FrameSelectionScreen(payload: _selectedPayload!)),
      );
      return;
    }

    final session = AnalysisSession(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      videoPayload: _selectedPayload!,
      startTime: DateTime.now(),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AnalysisProgressScreen(session: session),
      ),
    );
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dailyUsageService = ref.watch(dailyUsageServiceProvider);
    final subscriptionService = ref.watch(subscriptionServiceProvider);
    final isPro = subscriptionService.isProActive;
    final canAnalyze = dailyUsageService.canAnalyze(isPro);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Select Video'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select Local Video File',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Supported video formats: MP4, MOV, WebM, MKV.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),

              if (_validationError != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.strengthContradictory.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.strengthContradictory),
                  ),
                  child: Text(
                    _validationError!,
                    style: const TextStyle(fontSize: 12, color: AppColors.strengthContradictory),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_selectedPayload != null) ...[
                OutlinedButton.icon(
                  onPressed: _chooseCropRegion,
                  icon: const Icon(Icons.crop),
                  label: Text(_selectedPayload!.cropRegion.isFull ? 'Crop video for visual search (optional)' : 'Change visual-search crop'),
                ),
                const SizedBox(height: 12),
              ],

              // Clean File Upload Box
              GestureDetector(
                onTap: _isPicking ? null : _pickVideo,
                child: Container(
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedPayload != null ? AppColors.youtubeRed : AppColors.lightBorder,
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _selectedPayload != null
                              ? AppColors.youtubeRed.withAlpha(20)
                              : AppColors.lightBackground,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _selectedPayload != null ? Icons.video_file : Icons.cloud_upload_outlined,
                          size: 44,
                          color: _selectedPayload != null ? AppColors.youtubeRed : AppColors.youtubeBlack,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedPayload != null ? _selectedPayload!.name : 'TAP TO BROWSE VIDEO FILE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _selectedPayload != null ? AppColors.textDark : AppColors.youtubeRed,
                        ),
                      ),
                      if (_selectedPayload != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _selectedPayload!.fileSizeFormatted,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Quick Link Check',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Paste an Instagram or TikTok video link to decode its exact publish timestamp. For full forensic analysis, download the video and add it as a local file above.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _linkController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: 'Paste video link here',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isCheckingLink ? null : _checkLinkTimestamp,
                      child: _isCheckingLink
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('CHECK LINK TIMESTAMP'),
                    ),
                    if (_linkCheckResult != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _linkCheckResult!.hasExactTimestamp
                              ? AppColors.strengthStrong.withAlpha(16)
                              : AppColors.strengthWeak.withAlpha(16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _linkCheckResult!.hasExactTimestamp
                                ? AppColors.strengthStrong
                                : AppColors.strengthWeak,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _linkCheckResult!.message,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Platform: ${_linkCheckResult!.platform.name.toUpperCase()}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            if (_linkCheckResult!.hasExactTimestamp) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Exact timestamp: ${_linkCheckResult!.exactTimestampIso}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Instruction: download this video, then add the local file above for full forensic analysis.',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Use the local video file picker above for the full forensic report.',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: (_selectedPayload != null && canAnalyze && !_isPicking)
                    ? _startAnalysis
                    : null,
                child: const Text('START FORENSIC ANALYSIS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

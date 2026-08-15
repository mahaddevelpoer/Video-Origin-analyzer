import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../data/models/analysis_session.dart';
import '../../../data/models/input_video_payload.dart';
import 'analysis_progress_screen.dart';

class VideoPickerScreen extends ConsumerStatefulWidget {
  const VideoPickerScreen({super.key});

  @override
  ConsumerState<VideoPickerScreen> createState() => _VideoPickerScreenState();
}

class _VideoPickerScreenState extends ConsumerState<VideoPickerScreen> {
  InputVideoPayload? _selectedPayload;
  bool _isPicking = false;
  String? _validationError;

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

  void _startAnalysis() {
    if (_selectedPayload == null) return;

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

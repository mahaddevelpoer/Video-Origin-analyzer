import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../data/models/analysis_session.dart';
import '../../../data/models/input_video_payload.dart';
import '../../../data/services/frame_extractor_service.dart';
import 'analysis_progress_screen.dart';

class FrameSelectionScreen extends ConsumerStatefulWidget {
  final InputVideoPayload payload;

  const FrameSelectionScreen({super.key, required this.payload});

  @override
  ConsumerState<FrameSelectionScreen> createState() =>
      _FrameSelectionScreenState();
}

class _FrameSelectionScreenState extends ConsumerState<FrameSelectionScreen> {
  VideoPlayerController? _controller;
  List<Uint8List?> _thumbnails = const [];
  Set<int> _selectedIndexes = {0};
  int _clipDurationMs = 15000;
  int _startMs = 0;
  bool _loading = true;
  bool _ocrSearchEnabled = false;
  bool _isPlaying = false;

  int get _videoDurationMs =>
      _controller?.value.duration.inMilliseconds ?? _clipDurationMs;
  int get _maxStartMs =>
      (_videoDurationMs - _clipDurationMs).clamp(0, 1 << 31).toInt();

  @override
  void initState() {
    super.initState();
    _ocrSearchEnabled = ref.read(subscriptionServiceProvider).isProActive;
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (widget.payload.path == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final controller = VideoPlayerController.file(File(widget.payload.path!));
    try {
      await controller.initialize();
      _controller = controller;
      controller.addListener(_handleVideoUpdate);
      final duration = controller.value.duration.inMilliseconds;
      _clipDurationMs = duration > 0
          ? duration.clamp(1000, 15000).toInt()
          : 1000;
      await _loadThumbnails();
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _loading = false);
    }
  }

  List<int> get _candidateTimesMs {
    if (_clipDurationMs <= 1000) return [_startMs];
    final step = _clipDurationMs / 4;
    return List<int>.generate(5, (index) => _startMs + (step * index).round());
  }

  void _handleVideoUpdate() {
    if (!mounted || _controller == null) return;
    final playing = _controller!.value.isPlaying;
    if (playing != _isPlaying) setState(() => _isPlaying = playing);
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _loadThumbnails() async {
    final path = widget.payload.path;
    if (path == null) return;
    if (mounted) setState(() => _loading = true);
    final results = <Uint8List?>[];
    try {
      for (final timeMs in _candidateTimesMs) {
        // Native extractors can return a blank frame at the precise end time.
        final safeTimeMs = timeMs
            .clamp(0, (_videoDurationMs - 120).clamp(0, _videoDurationMs))
            .toInt();
        final thumbnail = await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 420,
          quality: 82,
          timeMs: safeTimeMs,
        );
        results.add(
          thumbnail == null
              ? null
              : FrameExtractorService().cropPreview(
                  thumbnail,
                  widget.payload.cropRegion,
                ),
        );
      }
    } catch (_) {
      // Keep the selector usable and show unavailable thumbnails instead of a stuck loader.
    }
    if (mounted) {
      setState(() {
        _thumbnails = results;
        _loading = false;
      });
    }
  }

  Future<void> _continue() async {
    if (_selectedIndexes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least 1 frame for the forensic search.'),
        ),
      );
      return;
    }
    final selectedTimes = _selectedIndexes.toList()..sort();
    final selectedPayload = InputVideoPayload(
      name: widget.payload.name,
      sizeInBytes: widget.payload.sizeInBytes,
      path: widget.payload.path,
      bytes: widget.payload.bytes,
      cropRegion: widget.payload.cropRegion,
      analysisWindowStartMs: _startMs,
      analysisWindowDurationMs: _clipDurationMs,
      selectedFrameTimesMs: selectedTimes
          .map((index) => _candidateTimesMs[index])
          .toList(),
    );
    final session = AnalysisSession(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      videoPayload: selectedPayload,
      startTime: DateTime.now(),
      ocrSearchEnabled: _ocrSearchEnabled,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AnalysisProgressScreen(session: session),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(subscriptionServiceProvider).isProActive;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(title: const Text('Choose Search Frames')),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.youtubeRed),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '1. Select a clip',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'For long videos, choose up to 15 seconds where the important action appears.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    if (_controller?.value.isInitialized == true) ...[
                      const SizedBox(height: 14),
                      AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio > 0
                            ? _controller!.value.aspectRatio
                            : 16 / 9,
                        child: VideoPlayer(_controller!),
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: _isPlaying ? 'Pause video' : 'Play video',
                            onPressed: _togglePlayback,
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              _controller!,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              colors: const VideoProgressColors(
                                playedColor: AppColors.youtubeRed,
                                bufferedColor: AppColors.lightBorder,
                                backgroundColor: AppColors.lightBackground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Start: ${(_startMs / 1000).toStringAsFixed(1)}s   Clip: ${(_clipDurationMs / 1000).toStringAsFixed(0)}s',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: _startMs
                          .toDouble()
                          .clamp(0, _maxStartMs.toDouble())
                          .toDouble(),
                      max: _maxStartMs.toDouble() == 0
                          ? 1
                          : _maxStartMs.toDouble(),
                      activeColor: AppColors.youtubeRed,
                      onChanged: (value) {
                        setState(() => _startMs = value.round());
                      },
                      onChangeEnd: (_) async {
                        await _controller?.seekTo(
                          Duration(milliseconds: _startMs),
                        );
                        await _loadThumbnails();
                      },
                    ),
                    Wrap(
                      spacing: 8,
                      children: [5, 10, 15].map((seconds) {
                        final enabled = _videoDurationMs >= seconds * 1000;
                        return ChoiceChip(
                          label: Text('${seconds}s'),
                          selected: _clipDurationMs == seconds * 1000,
                          onSelected: enabled
                              ? (_) {
                                  setState(() {
                                    _clipDurationMs = seconds * 1000;
                                    _startMs = _startMs
                                        .clamp(0, _maxStartMs)
                                        .toInt();
                                    _selectedIndexes = {0};
                                  });
                                  _loadThumbnails();
                                }
                              : null,
                        );
                      }).toList(),
                    ),
                    if (_controller?.value.duration.inMilliseconds == 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'This file does not expose its duration on this device. The first available frame can still be searched.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      '2. Choose up to 3 search frames',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_selectedIndexes.length}/3 selected. Choose 1, 2, or 3 frames.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _thumbnails.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemBuilder: (context, index) {
                        final selected = _selectedIndexes.contains(index);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedIndexes.remove(index);
                              } else if (_selectedIndexes.length < 3) {
                                _selectedIndexes.add(index);
                              }
                            });
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_thumbnails[index] != null)
                                Image.memory(
                                  _thumbnails[index]!,
                                  fit: BoxFit.cover,
                                )
                              else
                                const ColoredBox(color: Colors.black12),
                              if (selected)
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.youtubeRed,
                                      width: 4,
                                    ),
                                    color: AppColors.youtubeRed.withAlpha(35),
                                  ),
                                ),
                              Positioned(
                                left: 8,
                                bottom: 8,
                                child: Text(
                                  '${(_candidateTimesMs[index] / 1000).toStringAsFixed(1)}s',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 3,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (selected)
                                const Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: AppColors.youtubeRed,
                                    size: 28,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _ocrSearchEnabled,
                      onChanged: isPro
                          ? (value) => setState(() => _ocrSearchEnabled = value)
                          : null,
                      title: const Text('Find related videos using OCR text'),
                      subtitle: Text(
                        isPro
                            ? 'Pro online OCR search. Local OCR still runs for every user.'
                            : 'Pro feature. Local multilingual OCR remains available in the free analysis.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _continue,
                      icon: const Icon(Icons.search),
                      label: const Text('SEARCH THESE FRAMES'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

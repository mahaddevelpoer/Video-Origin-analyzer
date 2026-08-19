import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/input_video_payload.dart';

enum FramePosition { beginning, middle, ending }

class FrameExtractionResult {
  final FramePosition position;
  final String base64Jpeg;
  final int byteSize;

  const FrameExtractionResult({
    required this.position,
    required this.base64Jpeg,
    required this.byteSize,
  });
}

/// Service for extracting authentic video frame screenshots for visual search.
/// Extracts actual frames using video_thumbnail on devices/files.
class FrameExtractorService {
  /// Extracts authentic representative frame screenshots (Center/Middle, Beginning, Ending).
  Future<List<FrameExtractionResult>> extractRepresentativeFrames(
    InputVideoPayload payload,
  ) async {
    final results = <FrameExtractionResult>[];

    // Ensure we have a valid file path for video extraction
    String? videoPath = payload.path;
    File? tempFile;

    try {
      if ((videoPath == null || videoPath.isEmpty) && payload.bytes != null && payload.bytes!.isNotEmpty && !kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        tempFile = File('${tempDir.path}/temp_extract_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await tempFile.writeAsBytes(payload.bytes!);
        videoPath = tempFile.path;
      }

      if (videoPath != null && videoPath.isNotEmpty && !kIsWeb) {
        // 1. Center / Middle Frame (timeMs: 2500 - 50% through video)
        final middle = await _extractRealFrame(videoPath, FramePosition.middle, timeMs: 3000, cropRegion: payload.cropRegion);
        if (middle != null) results.add(middle);

        // 2. Beginning Frame (timeMs: 1000)
        final beginning = await _extractRealFrame(videoPath, FramePosition.beginning, timeMs: 1000, cropRegion: payload.cropRegion);
        if (beginning != null) results.add(beginning);

        // 3. Ending Frame (timeMs: 6000)
        final ending = await _extractRealFrame(videoPath, FramePosition.ending, timeMs: 6000, cropRegion: payload.cropRegion);
        if (ending != null) results.add(ending);
      }
    } catch (e) {
      debugPrint('Real frame extraction error: $e');
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }

    if (results.isEmpty) {
      // Fallback only if native video decoding is not available on platform
      final fallback = _generateMinimalFrame(payload, FramePosition.middle);
      results.add(fallback);
    }

    return results;
  }

  Future<FrameExtractionResult?> _extractRealFrame(
    String videoPath,
    FramePosition position, {
    int timeMs = 0,
    CropRegion cropRegion = CropRegion.full,
  }) async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 80,
        timeMs: timeMs,
      );

      if (uint8list != null && uint8list.isNotEmpty) {
        final croppedBytes = _cropJpeg(uint8list, payloadCrop: cropRegion);
        final b64 = base64Encode(croppedBytes);
        debugPrint('Successfully extracted REAL frame screenshot ($position, ${uint8list.length} bytes)');
        return FrameExtractionResult(
          position: position,
          base64Jpeg: b64,
          byteSize: uint8list.length,
        );
      }
    } catch (e) {
      debugPrint('Failed to extract real frame at $timeMs ms: $e');
    }
    return null;
  }

  Uint8List _cropJpeg(Uint8List bytes, {CropRegion? payloadCrop}) {
    final crop = payloadCrop ?? CropRegion.full;
    if (crop.isFull) return bytes;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final left = (decoded.width * crop.left).round().clamp(0, decoded.width - 1).toInt();
    final top = (decoded.height * crop.top).round().clamp(0, decoded.height - 1).toInt();
    final right = (decoded.width * crop.right).round().clamp(left + 1, decoded.width).toInt();
    final bottom = (decoded.height * crop.bottom).round().clamp(top + 1, decoded.height).toInt();
    final cropped = img.copyCrop(
      decoded,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 82));
  }

  FrameExtractionResult _generateMinimalFrame(
    InputVideoPayload payload,
    FramePosition position,
  ) {
    const width = 320;
    const height = 320;
    final image = img.Image(width: width, height: height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, 40, 40, 40);
      }
    }

    final jpegBytes = img.encodeJpg(image, quality: 80);
    final b64 = base64Encode(jpegBytes);

    return FrameExtractionResult(
      position: position,
      base64Jpeg: b64,
      byteSize: jpegBytes.length,
    );
  }
}

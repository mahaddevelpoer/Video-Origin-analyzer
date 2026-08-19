import 'dart:io';
import 'package:flutter/foundation.dart';

class CropRegion {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const CropRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  static const full = CropRegion(left: 0, top: 0, right: 1, bottom: 1);

  bool get isFull => left == 0 && top == 0 && right == 1 && bottom == 1;
}

class InputVideoPayload {
  final String name;
  final int sizeInBytes;
  final String? path;
  final Uint8List? bytes;
  final CropRegion cropRegion;
  final int analysisWindowStartMs;
  final int analysisWindowDurationMs;
  final List<int> selectedFrameTimesMs;

  const InputVideoPayload({
    required this.name,
    required this.sizeInBytes,
    this.path,
    this.bytes,
    this.cropRegion = CropRegion.full,
    this.analysisWindowStartMs = 0,
    this.analysisWindowDurationMs = 15000,
    this.selectedFrameTimesMs = const [],
  });

  File? get file => (path != null && !kIsWeb) ? File(path!) : null;

  String get fileSizeFormatted {
    final mb = sizeInBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }
}

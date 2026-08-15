import 'dart:io';
import 'package:flutter/foundation.dart';

class InputVideoPayload {
  final String name;
  final int sizeInBytes;
  final String? path;
  final Uint8List? bytes;

  const InputVideoPayload({
    required this.name,
    required this.sizeInBytes,
    this.path,
    this.bytes,
  });

  File? get file => (path != null && !kIsWeb) ? File(path!) : null;

  String get fileSizeFormatted {
    final mb = sizeInBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class OcrExtractionResult {
  final String rawText;
  final String cleanedText;
  final List<String> detectedUsernames;
  final List<String> detectedHashtags;
  final List<String> uniquePhrases;
  final bool hasSearchableContent;

  const OcrExtractionResult({
    required this.rawText,
    required this.cleanedText,
    required this.detectedUsernames,
    required this.detectedHashtags,
    required this.uniquePhrases,
    required this.hasSearchableContent,
  });

  factory OcrExtractionResult.empty() => const OcrExtractionResult(
        rawText: '',
        cleanedText: '',
        detectedUsernames: [],
        detectedHashtags: [],
        uniquePhrases: [],
        hasSearchableContent: false,
      );
}

/// Service for local video frame text extraction and cleaning.
class LocalOcrService {
  /// Analyzes frame content (base64/bytes) locally and extracts clean text.
  Future<OcrExtractionResult> processFrameText(String base64Jpeg) async {
    try {
      if (base64Jpeg.isEmpty) return OcrExtractionResult.empty();

      final bytes = base64Decode(base64Jpeg);
      final joinedRaw = kIsWeb ? _fallbackBinaryScan(bytes) : await _recognizeWithMlKit(bytes);
      final cleaned = cleanOcrText(joinedRaw);

      final usernames = extractUsernames(cleaned);
      final hashtags = extractHashtags(cleaned);
      final phrases = extractUniquePhrases(cleaned);

      final hasContent = usernames.isNotEmpty || hashtags.isNotEmpty || phrases.isNotEmpty;

      return OcrExtractionResult(
        rawText: joinedRaw.length > 300 ? joinedRaw.substring(0, 300) : joinedRaw,
        cleanedText: cleaned,
        detectedUsernames: usernames,
        detectedHashtags: hashtags,
        uniquePhrases: phrases,
        hasSearchableContent: hasContent,
      );
    } catch (e) {
      debugPrint('Local OCR processing exception: $e');
      return OcrExtractionResult.empty();
    }
  }

  Future<String> _recognizeWithMlKit(List<int> bytes) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    final recognized = <String>[];

    try {
      // ML Kit provides separate on-device models for these script families.
      // Running each model keeps OCR useful for mixed-language social clips.
      for (final script in [
        TextRecognitionScript.latin,
        TextRecognitionScript.devanagiri,
        TextRecognitionScript.chinese,
        TextRecognitionScript.japanese,
        TextRecognitionScript.korean,
      ]) {
        final recognizer = TextRecognizer(script: script);
        try {
          final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
          if (result.text.trim().isNotEmpty) recognized.add(result.text.trim());
        } finally {
          await recognizer.close();
        }
      }
    } finally {
      if (await file.exists()) await file.delete();
    }

    return recognized.join(' ');
  }

  String _fallbackBinaryScan(List<int> bytes) {
    final rawStrings = <String>[];
    final buffer = StringBuffer();
    for (final byte in bytes) {
      if ((byte >= 32 && byte <= 126) || byte == 10 || byte == 13) {
        buffer.writeCharCode(byte);
      } else {
        if (buffer.length > 5) rawStrings.add(buffer.toString());
        buffer.clear();
      }
    }
    if (buffer.length > 5) rawStrings.add(buffer.toString());
    return rawStrings.join(' ');
  }

  /// Cleans raw OCR text by removing noise, random symbols, and duplicated words.
  String cleanOcrText(String raw) {
    if (raw.isEmpty) return '';

    String text = raw.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    // Remove control characters only so non-Latin scripts remain intact.
    text = text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ');

    final words = text.split(RegExp(r'\s+'));
    final cleanedWords = <String>[];
    final seen = <String>{};

    for (var w in words) {
      final trimmed = w.trim();
      if (trimmed.length < 2) continue;

      if (RegExp(r'^(JFIF|Exif|ICC_PROFILE|Photoshop|Adobe|http|https|www|com|org|net)$', caseSensitive: false)
          .hasMatch(trimmed)) {
        continue;
      }

      final lower = trimmed.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        cleanedWords.add(trimmed);
      }
    }

    return cleanedWords.join(' ');
  }

  List<String> extractUsernames(String text) {
    final matches = RegExp(r'@[^\s@#]{3,30}').allMatches(text);
    return matches.map((m) => m.group(0)!).toSet().toList();
  }

  List<String> extractHashtags(String text) {
    final matches = RegExp(r'#[^\s@#]{3,30}').allMatches(text);
    return matches.map((m) => m.group(0)!).toSet().toList();
  }

  List<String> extractUniquePhrases(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.length > 3).toList();
    if (words.length < 3) return [];

    final phrases = <String>[];
    for (int i = 0; i <= words.length - 3 && i < 6; i += 3) {
      phrases.add('${words[i]} ${words[i + 1]} ${words[i + 2]}');
    }
    return phrases;
  }
}

import 'platform_result.dart';

class HistoryRecord {
  final String id;
  final DateTime timestamp;
  final String filename;
  final String filePath;
  final String durationFormatted;
  final String fileSizeFormatted;
  final String resolution;
  final String container;
  final String videoCodec;
  final String audioCodec;
  final PlatformResult result;
  final String analysisVersion;
  final String engineVersion;
  final int processingDurationMs;

  const HistoryRecord({
    required this.id,
    required this.timestamp,
    required this.filename,
    required this.filePath,
    required this.durationFormatted,
    required this.fileSizeFormatted,
    required this.resolution,
    required this.container,
    required this.videoCodec,
    required this.audioCodec,
    required this.result,
    required this.analysisVersion,
    required this.engineVersion,
    required this.processingDurationMs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'filename': filename,
        'filePath': filePath,
        'durationFormatted': durationFormatted,
        'fileSizeFormatted': fileSizeFormatted,
        'resolution': resolution,
        'container': container,
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
        'result': result.toJson(),
        'analysisVersion': analysisVersion,
        'engineVersion': engineVersion,
        'processingDurationMs': processingDurationMs,
      };

  factory HistoryRecord.fromJson(Map<String, dynamic> json) => HistoryRecord(
        id: json['id'] ?? '',
        timestamp: DateTime.parse(json['timestamp']),
        filename: json['filename'] ?? '',
        filePath: json['filePath'] ?? '',
        durationFormatted: json['durationFormatted'] ?? '00:00',
        fileSizeFormatted: json['fileSizeFormatted'] ?? '0 MB',
        resolution: json['resolution'] ?? 'Unknown',
        container: json['container'] ?? 'MP4',
        videoCodec: json['videoCodec'] ?? 'H.264',
        audioCodec: json['audioCodec'] ?? 'AAC',
        result: PlatformResult.fromJson(Map<String, dynamic>.from(json['result'])),
        analysisVersion: json['analysisVersion'] ?? '1.0.0',
        engineVersion: json['engineVersion'] ?? '1.0.0',
        processingDurationMs: json['processingDurationMs'] ?? 0,
      );
}

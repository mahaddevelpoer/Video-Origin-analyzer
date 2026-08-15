import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_record.dart';

/// Repository for storing and reading video origin analysis history locally on device.
class LocalHistoryRepository {
  static const String _keyHistoryJson = 'local_analysis_history_v1';
  final SharedPreferences _prefs;

  LocalHistoryRepository(this._prefs);

  /// Fetch all saved analysis history records, ordered newest first.
  List<HistoryRecord> getHistory() {
    final rawJsonList = _prefs.getStringList(_keyHistoryJson) ?? [];
    final List<HistoryRecord> records = [];

    for (final rawJson in rawJsonList) {
      try {
        final Map<String, dynamic> map = jsonDecode(rawJson);
        records.add(HistoryRecord.fromJson(map));
      } catch (e) {
        // Skip corrupted individual record safely
      }
    }

    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  /// Save a new completed analysis record.
  Future<void> saveRecord(HistoryRecord record) async {
    final history = getHistory();
    // Check for duplicate ID
    if (history.any((r) => r.id == record.id)) {
      return;
    }

    history.insert(0, record);
    await _saveAll(history);
  }

  /// Delete a single record by ID.
  Future<void> deleteRecord(String id) async {
    final history = getHistory();
    history.removeWhere((r) => r.id == id);
    await _saveAll(history);
  }

  /// Clear all analysis history records.
  Future<void> clearHistory() async {
    await _prefs.remove(_keyHistoryJson);
  }

  /// Search history by filename or origin platform.
  List<HistoryRecord> searchHistory(String query) {
    if (query.trim().isEmpty) return getHistory();
    final lower = query.toLowerCase();
    return getHistory().where((r) {
      return r.filename.toLowerCase().contains(lower) ||
          r.result.platformName.toLowerCase().contains(lower) ||
          r.container.toLowerCase().contains(lower) ||
          r.videoCodec.toLowerCase().contains(lower);
    }).toList();
  }

  Future<void> _saveAll(List<HistoryRecord> history) async {
    final rawJsonList = history.map((r) => jsonEncode(r.toJson())).toList();
    await _prefs.setStringList(_keyHistoryJson, rawJsonList);
  }
}

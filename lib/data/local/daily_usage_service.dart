import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

/// Real-time service for managing free tier daily analysis limits.
/// Notifies listeners in real-time on usage consumption and handles persistent device tracking.
class DailyUsageService extends ChangeNotifier {
  static const String _keyUsageDate = 'daily_usage_date';
  static const String _keyUsageCount = 'daily_usage_count';
  static const String _keyDeviceId = 'persistent_device_id';

  final SharedPreferences _prefs;
  late String _deviceId;

  DailyUsageService(this._prefs) {
    _initDeviceId();
  }

  void _initDeviceId() {
    var savedId = _prefs.getString(_keyDeviceId);
    if (savedId == null || savedId.isEmpty) {
      savedId = 'DEV_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond)}';
      _prefs.setString(_keyDeviceId, savedId);
    }
    _deviceId = savedId;
  }

  String get deviceId => _deviceId;

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Synchronizes date and returns current analysis count for today.
  int getUsageCount() {
    final savedDate = _prefs.getString(_keyUsageDate);
    final today = _getTodayString();

    if (savedDate != today) {
      // New day: reset counter
      _prefs.setString(_keyUsageDate, today);
      _prefs.setInt(_keyUsageCount, 0);
      return 0;
    }

    return _prefs.getInt(_keyUsageCount) ?? 0;
  }

  /// Returns whether user is allowed to perform an analysis.
  bool canAnalyze(bool isPro) {
    if (isPro) return true;
    final currentCount = getUsageCount();
    return currentCount < AppConfig.freeDailyAnalysisLimit;
  }

  /// Consumes one analysis slot if user is not Pro and notifies UI in real-time.
  Future<void> consumeAnalysis(bool isPro) async {
    if (isPro) return;
    final currentCount = getUsageCount();
    final today = _getTodayString();
    await _prefs.setString(_keyUsageDate, today);
    await _prefs.setInt(_keyUsageCount, currentCount + 1);
    notifyListeners(); // Immediate real-time UI update across HomeScreen & VideoPicker
  }

  /// Remaining analyses for free users.
  int getRemainingAnalyses(bool isPro) {
    if (isPro) return 999999;
    final used = getUsageCount();
    final remaining = AppConfig.freeDailyAnalysisLimit - used;
    return remaining < 0 ? 0 : remaining;
  }
}

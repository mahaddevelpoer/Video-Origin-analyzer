import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';

/// Isolated local service for managing free tier daily analysis limits.
/// Stores usage date and analysis count persistently.
class DailyUsageService {
  static const String _keyUsageDate = 'daily_usage_date';
  static const String _keyUsageCount = 'daily_usage_count';

  final SharedPreferences _prefs;

  DailyUsageService(this._prefs);

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

  /// Consumes one analysis slot if user is not Pro.
  Future<void> consumeAnalysis(bool isPro) async {
    if (isPro) return;
    final currentCount = getUsageCount();
    final today = _getTodayString();
    await _prefs.setString(_keyUsageDate, today);
    await _prefs.setInt(_keyUsageCount, currentCount + 1);
  }

  /// Remaining analyses for free users.
  int getRemainingAnalyses(bool isPro) {
    if (isPro) return 999999;
    final used = getUsageCount();
    final remaining = AppConfig.freeDailyAnalysisLimit - used;
    return remaining < 0 ? 0 : remaining;
  }
}

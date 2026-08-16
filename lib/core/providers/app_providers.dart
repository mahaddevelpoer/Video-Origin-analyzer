import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/daily_usage_service.dart';
import '../../data/local/local_history_repository.dart';
import '../../data/services/frame_extractor_service.dart';
import '../../data/services/online_visual_search_service.dart';
import '../../domain/forensic/video_analyzer_engine.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/subscription/services/subscription_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main()');
});

final dailyUsageServiceProvider = ChangeNotifierProvider<DailyUsageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DailyUsageService(prefs);
});

final localHistoryRepositoryProvider = Provider<LocalHistoryRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalHistoryRepository(prefs);
});

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  final subService = ref.watch(subscriptionServiceProvider);
  return AuthService(subService);
});

final frameExtractorServiceProvider = Provider<FrameExtractorService>((ref) {
  return FrameExtractorService();
});

final onlineVisualSearchServiceProvider = Provider<OnlineVisualSearchService>((ref) {
  final frameExtractor = ref.watch(frameExtractorServiceProvider);
  return OnlineVisualSearchService(frameExtractor: frameExtractor);
});

final videoAnalyzerEngineProvider = Provider<VideoAnalyzerEngine>((ref) {
  final searchService = ref.watch(onlineVisualSearchServiceProvider);
  return VideoAnalyzerEngine(onlineSearchService: searchService);
});

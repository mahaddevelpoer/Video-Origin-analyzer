import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Central AdMob Configuration for Video Origin Analyzer
/// Developer: Mahadand Mehdi Developers
class AdMobConfig {
  // AdMob App ID
  static const String appIdAndroid = 'ca-app-pub-1107688707504015~5138881223';
  static const String appIdIOS = 'ca-app-pub-1107688707504015~5138881223';

  // Interstitial Ad Unit ID (No banner ads to preserve clean YouTube UI design)
  static const String interstitialAdUnitIdAndroid =
      'ca-app-pub-1107688707504015/4860463446';
  static const String interstitialAdUnitIdIOS =
      'ca-app-pub-1107688707504015/4860463446';

  // Official Test Unit ID Fallback (Guarantees ads show during testing)
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  static String get interstitialAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return interstitialAdUnitIdAndroid;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return interstitialAdUnitIdIOS;
    }
    return interstitialAdUnitIdAndroid;
  }
}

/// Helper service for loading and showing full-screen Interstitial Ads for Free Tier users
class InterstitialAdService {
  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;

  void loadInterstitialAd({bool isFallback = false}) {
    if (kIsWeb || _isAdLoading) return;
    _isAdLoading = true;

    final targetUnitId = isFallback
        ? AdMobConfig.testInterstitialAdUnitId
        : AdMobConfig.interstitialAdUnitId;

    InterstitialAd.load(
      adUnitId: targetUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoading = false;
          debugPrint('AdMob Interstitial Ad Loaded Successfully ($targetUnitId).');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isAdLoading = false;
          debugPrint('AdMob Interstitial Ad Failed To Load ($targetUnitId): $error');

          // If custom unit ID failed to fill, automatically retry with official test unit ID
          if (!isFallback) {
            debugPrint('Retrying AdMob Interstitial load with Test Ad Unit ID fallback...');
            loadInterstitialAd(isFallback: true);
          }
        },
      ),
    );
  }

  Future<void> showInterstitialAdIfAvailable({required bool isPro}) async {
    if (kIsWeb || isPro || _interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Preload next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        debugPrint('AdMob Interstitial Ad Failed to show: $error');
      },
    );

    await _interstitialAd!.show();
  }
}

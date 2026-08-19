import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/config/revenuecat_config.dart';
import '../../../data/services/firebase_account_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// RevenueCat Subscription Management Service
class SubscriptionService {
  bool _isInitialized = false;
  bool _isProActive = false;
  Offerings? _currentOfferings;
  FirebaseAccountSyncService? _accountSync;

  bool get isProActive => _isProActive;
  Offerings? get currentOfferings => _currentOfferings;

  /// Initializes RevenueCat SDK with OS-appropriate public API key.
  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;
    try {
      final apiKey = (defaultTargetPlatform == TargetPlatform.android)
          ? RevenueCatConfig.apiKeyAndroid
          : RevenueCatConfig.apiKeyIOS;

      await Purchases.configure(PurchasesConfiguration(apiKey));
      _isInitialized = true;
      await updateSubscriptionStatus();
      await fetchOfferings();
    } catch (e) {
      debugPrint('RevenueCat Init Exception: $e');
    }
  }

  void attachAccountSync(SharedPreferences prefs) {
    _accountSync ??= FirebaseAccountSyncService(prefs);
  }

  /// Syncs RevenueCat identity with Firebase UID.
  Future<void> identifyUser(String firebaseUid) async {
    if (!_isInitialized || kIsWeb) return;
    try {
      final customerInfo = await Purchases.logIn(firebaseUid);
      _checkEntitlement(customerInfo.customerInfo);
    } catch (e) {
      debugPrint('RevenueCat logIn Exception: $e');
    }
  }

  /// Resets RevenueCat identity on logout.
  Future<void> resetUser() async {
    if (!_isInitialized || kIsWeb) return;
    try {
      final customerInfo = await Purchases.logOut();
      _checkEntitlement(customerInfo);
    } catch (e) {
      debugPrint('RevenueCat logOut Exception: $e');
    }
  }

  /// Updates current subscription status directly from RevenueCat entitlement.
  Future<bool> updateSubscriptionStatus() async {
    if (!_isInitialized || kIsWeb) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _checkEntitlement(customerInfo);
    } catch (e) {
      debugPrint('RevenueCat getCustomerInfo Exception: $e');
    }
    return _isProActive;
  }

  /// Fetches dynamic subscription offerings from RevenueCat.
  Future<Offerings?> fetchOfferings() async {
    if (!_isInitialized) return null;
    try {
      _currentOfferings = await Purchases.getOfferings();
    } catch (e) {
      debugPrint('RevenueCat getOfferings Exception: $e');
    }
    return _currentOfferings;
  }

  /// Make a package purchase.
  Future<bool> purchasePackage(Package package) async {
    if (!_isInitialized) return false;
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      _checkEntitlement(customerInfo);
      return _isProActive;
    } catch (e) {
      debugPrint('RevenueCat Purchase Exception: $e');
      return false;
    }
  }

  /// Restore past in-app purchases.
  Future<bool> restorePurchases() async {
    if (!_isInitialized) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      _checkEntitlement(customerInfo);
      return _isProActive;
    } catch (e) {
      debugPrint('RevenueCat Restore Exception: $e');
      return false;
    }
  }

  void _checkEntitlement(CustomerInfo info) {
    final entitlement = info.entitlements.all[RevenueCatConfig.entitlementId];
    _isProActive = entitlement != null && entitlement.isActive;
    _accountSync?.syncEntitlement(
      isPro: _isProActive,
      productId: entitlement?.productIdentifier,
    );
  }
}

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Syncs quota and entitlement state across signed-in sessions and devices.
/// Sensitive identifiers are hashed before they leave the device.
class FirebaseAccountSyncService {
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const AndroidId _androidId = AndroidId();

  FirebaseAccountSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null),
        _auth = auth ?? (Firebase.apps.isNotEmpty ? FirebaseAuth.instance : null);

  Future<String> _fingerprint() async {
    var details = 'unknown';
    try {
      if (kIsWeb) {
        final info = await _deviceInfo.webBrowserInfo;
        details = '${info.browserName}|${info.platform}|${info.userAgent}';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await _deviceInfo.androidInfo;
        final androidId = await _androidId.getId();
        details = '${androidId ?? info.id}|${info.model}|${info.manufacturer}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _deviceInfo.iosInfo;
        details = '${info.identifierForVendor}|${info.model}|${info.systemVersion}';
      } else {
        final info = await _deviceInfo.deviceInfo;
        details = info.data.toString();
      }
    } catch (_) {}
    // Do not include the locally generated installation ID: clearing app
    // storage must not create a new quota identity on the same device.
    return _hash('$defaultTargetPlatform|$details');
  }

  Future<String?> _ipHash() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final ip = (jsonDecode(response.body) as Map<String, dynamic>)['ip'] as String?;
        if (ip != null && ip.isNotEmpty) return _hash(ip);
      }
    } catch (_) {}
    return null;
  }

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();

  Future<DocumentReference<Map<String, dynamic>>> _accountRef() async {
    final firestore = _firestore;
    if (firestore == null) throw StateError('Firebase is not initialized');
    await _ensureFirebaseIdentity();
    final user = _auth?.currentUser;
    if (user != null && !user.isAnonymous) return firestore.collection('accounts').doc(user.uid);
    return firestore.collection('device_accounts').doc(await _fingerprint());
  }

  Future<void> _ensureFirebaseIdentity() async {
    if (_auth?.currentUser == null) {
      try {
        await _auth?.signInAnonymously();
      } catch (e) {
        debugPrint('Anonymous Firebase identity unavailable: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _identityFields() async {
    final ipHash = await _ipHash();
    return {
      'fingerprintHash': await _fingerprint(),
      if (ipHash != null) 'ipHash': ipHash,
      'userId': _auth?.currentUser?.uid,
      'lastSeenAt': FieldValue.serverTimestamp(),
    };
  }

  Future<int?> restoreUsage({required String date}) async {
    try {
      final ref = await _accountRef();
      final snapshot = await ref.get();
      await ref.set({
        ...await _identityFields(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final data = snapshot.data();
      if (data == null || data['usageDate'] != date) return null;
      return (data['freeAnalysesUsed'] as num?)?.toInt();
    } catch (e) {
      debugPrint('Firebase usage restore skipped: $e');
      return null;
    }
  }

  Future<void> syncUsage({required String date, required int used}) async {
    try {
      final ref = await _accountRef();
      final previous = await ref.get();
      final oldData = previous.data();
      final oldUsed = oldData?['usageDate'] == date ? (oldData?['freeAnalysesUsed'] as num?)?.toInt() ?? 0 : 0;
      await ref.set({
        ...await _identityFields(),
        'usageDate': date,
        'freeAnalysesUsed': used > oldUsed ? used : oldUsed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firebase usage sync skipped: $e');
    }
  }

  Future<void> syncEntitlement({required bool isPro, required String? productId}) async {
    try {
      final ref = await _accountRef();
      await ref.set({
        ...await _identityFields(),
        'proActive': isPro,
        'proProductId': productId,
        'proSyncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firebase entitlement sync skipped: $e');
    }
  }
}

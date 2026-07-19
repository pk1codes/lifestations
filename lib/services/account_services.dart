import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'firebase_bootstrap.dart';
import 'media_upload_service.dart';

class TrustFlags {
  const TrustFlags({
    this.aadhaar = false,
    this.drivingLicence = false,
    this.address = false,
    this.rc = false,
  });
  final bool aadhaar;
  final bool drivingLicence;
  final bool address;
  final bool rc;

  bool get idPlus => aadhaar && drivingLicence;
  bool get verifiedUser => aadhaar;
  bool get trustedId => drivingLicence;

  TrustFlags copyWith({
    bool? aadhaar,
    bool? drivingLicence,
    bool? address,
    bool? rc,
  }) => TrustFlags(
    aadhaar: aadhaar ?? this.aadhaar,
    drivingLicence: drivingLicence ?? this.drivingLicence,
    address: address ?? this.address,
    rc: rc ?? this.rc,
  );

  Map<String, Object?> toSafeJson() => {
    'aadhaarSelfAttested': aadhaar,
    'dlSelfAttested': drivingLicence,
    'addressSelfAttested': address,
    'rcSelfAttested': rc,
    'idPlus': idPlus,
  };
}

class TrustService extends ChangeNotifier {
  TrustService({MediaUploadService? media, this.firestore})
    : _media = media ?? MediaUploadService(),
      super();

  final MediaUploadService _media;
  final FirebaseFirestore? firestore;
  TrustFlags flags = const TrustFlags();

  FirebaseFirestore get _db {
    final injected = firestore;
    if (injected != null) return injected;
    if (!FirebaseBootstrap.ready) {
      throw StateError('Firestore unavailable until bootstrap succeeds');
    }
    return FirebaseFirestore.instance;
  }

  void applySelfAttested(TrustFlags value) {
    flags = value;
    notifyListeners();
  }

  /// Self-attested document flow: stage → set flag → fan-out → delete staging.
  Future<void> attestDocument({
    required String uid,
    required String docType,
    required Uint8List bytes,
  }) async {
    await _media.uploadVerifyStaging(uid: uid, docType: docType, bytes: bytes);
    switch (docType) {
      case 'aadhaar':
        flags = flags.copyWith(aadhaar: true);
      case 'dl':
      case 'driving_licence':
        flags = flags.copyWith(drivingLicence: true);
      case 'address':
        flags = flags.copyWith(address: true);
      case 'rc':
        flags = flags.copyWith(rc: true);
    }
    notifyListeners();
    if (FirebaseBootstrap.ready) {
      await _db.doc('users/$uid').set({
        'trust': flags.toSafeJson(),
        'trustUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}

class BillingService extends ChangeNotifier {
  BillingService({bool listenToPurchases = true}) {
    if (listenToPurchases && available) {
      try {
        _subscription = InAppPurchase.instance.purchaseStream.listen(
          _onPurchases,
          onError: (_) {},
        );
      } catch (_) {
        // Binding may be unavailable in pure unit tests.
      }
    }
  }

  static const productId = 'flut_boost_week';
  DateTime? boostUntil;
  bool loading = false;
  String? lastError;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool get active => boostUntil?.isAfter(DateTime.now()) ?? false;
  bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String get webMessage =>
      'Boost purchases are available on the Android app only.';

  Future<ProductDetails?> loadProduct() async {
    if (!available) return null;
    loading = true;
    notifyListeners();
    try {
      final response = await InAppPurchase.instance.queryProductDetails({
        productId,
      });
      return response.productDetails.firstOrNull;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> buyBoost() async {
    if (!available) {
      lastError = webMessage;
      notifyListeners();
      return;
    }
    final product = await loadProduct();
    if (product == null) {
      lastError = 'Boost product unavailable';
      notifyListeners();
      return;
    }
    final param = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  /// Debug-only grant — never expose in release UX.
  void debugGrant(DateTime now) {
    assert(() {
      applyVerifiedEntitlement(now);
      return true;
    }());
  }

  void applyVerifiedEntitlement(DateTime purchaseTime) {
    boostUntil = purchaseTime.add(const Duration(days: 7));
    lastError = null;
    notifyListeners();
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        applyVerifiedEntitlement(DateTime.now());
        if (purchase.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchase);
        }
      }
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}

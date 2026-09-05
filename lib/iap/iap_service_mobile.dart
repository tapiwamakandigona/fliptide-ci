/// Play Billing via `in_app_purchase` (directive 02O-1). Android only; this file
/// is reached solely through iap_service_io.dart.
///
/// No fake purchase path: debug builds go through the real Play Billing flow
/// with licence-tester accounts (Play returns test cards there). Ownership is
/// whatever the store reports; the screen persists it locally.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'iap_service.dart';

class PlayIapService extends IapService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  bool _available = false;
  Completer<PurchaseOutcome>? _pending;

  @override
  bool get supported => true;

  @override
  Future<void> init() async {
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        debugPrint('iap stream error: $e');
        _finish(PurchaseOutcome.error);
      },
    );
    try {
      _available = await _iap.isAvailable();
      if (!_available) return;
      final resp = await _iap.queryProductDetails({kSupporterProductId});
      if (resp.productDetails.isNotEmpty) {
        _product = resp.productDetails.first;
        price.value = _product!.price;
      }
      // Startup restore (owner directive): past purchases arrive on purchaseStream.
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('iap init: $e');
    }
  }

  @override
  Future<PurchaseOutcome> buy() async {
    if (owned.value) return PurchaseOutcome.owned;
    if (!_available || _product == null) return PurchaseOutcome.unavailable;
    if (_pending != null) return _pending!.future;
    final c = _pending = Completer<PurchaseOutcome>();
    try {
      final started = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: _product!));
      if (!started) _finish(PurchaseOutcome.error);
    } catch (e) {
      debugPrint('iap buy: $e');
      _finish(PurchaseOutcome.error);
    }
    return c.future;
  }

  @override
  Future<bool> restore() async {
    if (!_available) return owned.value;
    try {
      await _iap.restorePurchases();
      // Restored purchases are delivered asynchronously; give the stream a moment.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    } catch (e) {
      debugPrint('iap restore: $e');
    }
    return owned.value;
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != kSupporterProductId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          owned.value = true;
          _finish(PurchaseOutcome.owned);
        case PurchaseStatus.pending:
          _finish(PurchaseOutcome.pending);
        case PurchaseStatus.canceled:
          _finish(PurchaseOutcome.cancelled);
        case PurchaseStatus.error:
          debugPrint('iap error: ${p.error}');
          _finish(PurchaseOutcome.error);
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (e) {
          debugPrint('iap complete: $e');
        }
      }
    }
  }

  void _finish(PurchaseOutcome o) {
    final c = _pending;
    if (c != null && !c.isCompleted) c.complete(o);
    if (o != PurchaseOutcome.pending) _pending = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

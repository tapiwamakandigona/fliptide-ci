/// Supporter unlock (directive 02O-1): one non-consumable Play Billing product
/// that removes every ad. The game never touches plugin types; the platform
/// implementation lives behind iap_service_platform.dart so the web build links
/// nothing and shows no purchase UI.
library;

import 'package:flutter/foundation.dart';

/// Play Console product id (non-consumable, USD 1.99).
const String kSupporterProductId = 'fliptide_supporter';

/// Shown when the store has not returned a localised price yet.
const String kSupporterFallbackPrice = r'$1.99';

enum PurchaseOutcome { owned, pending, cancelled, unavailable, error }

abstract class IapService {
  /// False on web/desktop/tests: no store, no UI.
  bool get supported;

  /// True once the store confirmed the supporter product is owned (purchase or
  /// restore). The screen persists it via [onOwned].
  final ValueNotifier<bool> owned = ValueNotifier(false);

  /// Localised price from the store, e.g. "US$1.99"; null until queried.
  final ValueNotifier<String?> price = ValueNotifier(null);

  /// Connect to the store, query the product and restore past purchases
  /// (startup restore, directive 02O-1). Safe to call once.
  Future<void> init();

  /// Start the purchase flow. Completes when the store answered.
  Future<PurchaseOutcome> buy();

  /// Explicit "Restore" button: re-query owned purchases. True if owned after.
  Future<bool> restore();

  void dispose() {}
}

/// Web, desktop, tests: no store, nothing ever owned.
class NoIapService extends IapService {
  @override
  bool get supported => false;
  @override
  Future<void> init() async {}
  @override
  Future<PurchaseOutcome> buy() async => PurchaseOutcome.unavailable;
  @override
  Future<bool> restore() async => false;
}

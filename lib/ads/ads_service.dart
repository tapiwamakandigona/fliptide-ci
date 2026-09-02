/// Thin wrapper around the ad SDK so the game never touches plugin types and
/// the web build never links the plugin (see ads_service_platform.dart).
library;

import 'package:flutter/foundation.dart';

abstract class AdsService {
  /// False on web/desktop/iOS: every call is a no-op.
  bool get supported;

  /// SDK init + request configuration + UMP consent. Safe to call once.
  Future<void> init();

  final ValueNotifier<bool> rewardedReady = ValueNotifier(false);
  final ValueNotifier<bool> interstitialReady = ValueNotifier(false);

  void loadRewarded();
  void loadInterstitial();

  /// Completes true when the user earned the reward (watched to the end).
  Future<bool> showRewarded();

  /// Completes when the interstitial is dismissed (false if it could not show).
  Future<bool> showInterstitial();
}

/// Web, desktop, tests: no SDK, nothing ever loads.
class NoAdsService extends AdsService {
  @override
  bool get supported => false;
  @override
  Future<void> init() async {}
  @override
  void loadRewarded() {}
  @override
  void loadInterstitial() {}
  @override
  Future<bool> showRewarded() async => false;
  @override
  Future<bool> showInterstitial() async => false;
}

/// google_mobile_ads implementation — Android only (directive 02k).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ads_service.dart';

class MobileAdsService extends AdsService {
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _inited = false;
  bool _canRequestAds = false;

  @override
  bool get supported => true;

  @override
  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    // Play 13+ audience: cap content at T; child-directed treatment left unspecified.
    await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(maxAdContentRating: MaxAdContentRating.t));
    // UMP consent (required in EEA/UK, no-op elsewhere). Ads are requested only
    // once the SDK says consent state allows it.
    final consent = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!consent.isCompleted) consent.complete();
      },
      (err) {
        debugPrint('UMP: ${err.message}');
        if (!consent.isCompleted) consent.complete();
      },
    );
    await consent.future.timeout(const Duration(seconds: 15), onTimeout: () {});
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    if (_canRequestAds) await MobileAds.instance.initialize();
  }

  @override
  void loadRewarded() {
    if (!_canRequestAds || _rewarded != null) return;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          rewardedReady.value = true;
        },
        onAdFailedToLoad: (e) => debugPrint('rewarded load failed: ${e.code} ${e.message}'),
      ),
    );
  }

  @override
  void loadInterstitial() {
    if (!_canRequestAds || _interstitial != null) return;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          interstitialReady.value = true;
        },
        onAdFailedToLoad: (e) => debugPrint('interstitial load failed: ${e.code} ${e.message}'),
      ),
    );
  }

  @override
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;
    rewardedReady.value = false;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }

  @override
  Future<bool> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) return false;
    _interstitial = null;
    interstitialReady.value = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );
    await ad.show();
    return done.future;
  }
}

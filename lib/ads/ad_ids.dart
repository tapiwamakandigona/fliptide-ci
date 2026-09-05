/// AdMob identifiers (directive 02k). These ship inside every APK, so they are
/// public by design. Debug/profile builds use Google's published test units;
/// only release builds request the real ones.
library;

import 'package:flutter/foundation.dart';

class AdIds {
  /// AndroidManifest `com.google.android.gms.ads.APPLICATION_ID`.
  static const appId = 'ca-app-pub-5182383335652302~6877765460';

  static const _rewardedSecondChance = 'ca-app-pub-5182383335652302/2421796507';
  static const _interstitialSessionBreak = 'ca-app-pub-5182383335652302/6829664002';

  // Google's published Android test unit IDs.
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';

  static String get rewarded => kReleaseMode ? _rewardedSecondChance : _testRewarded;
  static String get interstitial => kReleaseMode ? _interstitialSessionBreak : _testInterstitial;
}

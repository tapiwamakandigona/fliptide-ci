// Regression: ownership can arrive while UMP / ad initialization is awaiting.
// The existing tests are unchanged; this file adds async boundary coverage.
import 'dart:async';

import 'package:fliptide/ads/ads_service.dart';
import 'package:fliptide/iap/iap_service.dart';
import 'package:fliptide/main.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DeferredAds extends AdsService {
  final initialization = Completer<void>();
  int inits = 0;
  int interstitialLoads = 0;

  @override
  bool get supported => true;

  @override
  Future<void> init() {
    inits++;
    return initialization.future;
  }

  @override
  void loadInterstitial() => interstitialLoads++;

  @override
  void loadRewarded() {}

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<bool> showRewarded() async => false;
}

class _ControlledIap extends IapService {
  @override
  bool get supported => true;

  @override
  Future<void> init() async {}

  @override
  Future<PurchaseOutcome> buy() async => PurchaseOutcome.unavailable;

  @override
  Future<bool> restore() async => owned.value;
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _start(
  WidgetTester tester,
  _DeferredAds ads,
  _ControlledIap iap,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: PlayScreen(
        seed: codeToSeed('400C1S'),
        adsService: ads,
        iapService: iap,
      ),
    ),
  );
  await _flush(tester);
  expect(ads.inits, 1);
  expect(ads.interstitialLoads, 0);
}

void main() {
  testWidgets('restored supporter during ad initialization never loads an interstitial', (tester) async {
    final ads = _DeferredAds();
    final iap = _ControlledIap();
    await _start(tester, ads, iap);

    // A real purchaseStream restore can arrive while the consent UI is open.
    iap.owned.value = true;
    await _flush(tester);
    expect(find.byKey(const Key('supporter-mark')), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('supporter'), isTrue);

    ads.initialization.complete();
    await _flush(tester);
    await tester.pump(const Duration(seconds: 2)); // let the thank-you toast expire
    expect(ads.interstitialLoads, 0, reason: 'ownership must be rechecked after awaiting ad initialization');
  });

  testWidgets('disposed play screen does not preload after ad initialization completes', (tester) async {
    final ads = _DeferredAds();
    await _start(tester, ads, _ControlledIap());
    await tester.pumpWidget(const SizedBox.shrink());

    ads.initialization.complete();
    await _flush(tester);
    expect(ads.interstitialLoads, 0, reason: 'an abandoned screen must not start a new ad request');
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-supporter still preloads after ad initialization', (tester) async {
    final ads = _DeferredAds();
    await _start(tester, ads, _ControlledIap());

    ads.initialization.complete();
    await _flush(tester);
    expect(ads.interstitialLoads, 1);
  });
}

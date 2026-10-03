// Directive 02k: the death overlay's rewarded offer obeys the policy, and the
// supporter flag stops every load before it reaches the SDK.
import 'package:fliptide/ads/ads_service.dart';
import 'package:fliptide/main.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAds extends AdsService {
  int inits = 0, rewardedLoads = 0, interstitialLoads = 0, rewardedShows = 0;
  @override
  bool get supported => true;
  @override
  Future<void> init() async => inits++;
  @override
  void loadRewarded() {
    rewardedLoads++;
    rewardedReady.value = true; // "loaded" instantly
  }

  @override
  void loadInterstitial() {
    interstitialLoads++;
    interstitialReady.value = true;
  }

  @override
  Future<bool> showRewarded() async {
    rewardedShows++;
    rewardedReady.value = false;
    return true;
  }

  @override
  Future<bool> showInterstitial() async => true;
}

Future<void> _pumpUntil(WidgetTester tester, Finder f, {int maxFrames = 2400}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('never found $f');
}

Future<void> _dieOnce(WidgetTester tester) async {
  await tester.tapAt(const Offset(195, 422));
  await _pumpUntil(tester, find.byKey(const Key('death-card')));
}

void main() {
  testWidgets('attempts 1–2: no offer; rewarded preloads from death 2, never on death 1', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ads = FakeAds();
    await tester.pumpWidget(MaterialApp(home: PlayScreen(seed: codeToSeed('400C1S'), adsService: ads)));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(ads.inits, 1);
    expect(ads.interstitialLoads, 1, reason: 'interstitial may preload at boot for non-supporters');

    await _dieOnce(tester); // attempt 1
    expect(find.text('attempt 1'), findsOneWidget);
    expect(ads.rewardedLoads, 0);
    expect(find.byKey(const Key('second-chance')), findsNothing);
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _dieOnce(tester); // attempt 2
    expect(find.text('attempt 2'), findsOneWidget);
    expect(ads.rewardedLoads, 1, reason: 'preload so attempt 3 can offer');
    expect(find.byKey(const Key('second-chance')), findsNothing, reason: 'attempt 2 never offers');
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _dieOnce(tester); // attempt 3 — dies at the first obstacle, so no checkpoint → still no offer
    expect(find.text('attempt 3'), findsOneWidget);
    expect(find.byKey(const Key('second-chance')), findsNothing, reason: 'no checkpoint passed');
    expect(ads.rewardedShows, 0);
  });

  testWidgets('supporter: SDK never initialised, nothing ever loads', (tester) async {
    SharedPreferences.setMockInitialValues({'supporter': true});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ads = FakeAds();
    await tester.pumpWidget(MaterialApp(home: PlayScreen(seed: codeToSeed('400C1S'), adsService: ads)));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    for (var n = 1; n <= 3; n++) {
      await _dieOnce(tester);
      expect(find.text('attempt $n'), findsOneWidget);
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    expect(ads.inits, 0);
    expect(ads.rewardedLoads, 0);
    expect(ads.interstitialLoads, 0);
    expect(find.byKey(const Key('second-chance')), findsNothing);
  });
}

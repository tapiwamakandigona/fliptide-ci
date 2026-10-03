// Directive 02O-1: Supporter unlock. Flag persistence, ad suppression after
// purchase, the restore path, and no purchase UI where there is no store (web).
import 'package:fliptide/ads/ad_policy.dart';
import 'package:fliptide/ads/ads_service.dart';
import 'package:fliptide/iap/iap_service.dart';
import 'package:fliptide/main.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:fliptide/store/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAds extends AdsService {
  int inits = 0, rewardedLoads = 0, interstitialLoads = 0, rewardedShows = 0, interstitialShows = 0;
  @override
  bool get supported => true;
  @override
  Future<void> init() async => inits++;
  @override
  void loadRewarded() {
    rewardedLoads++;
    rewardedReady.value = true;
  }

  @override
  void loadInterstitial() {
    interstitialLoads++;
    interstitialReady.value = true;
  }

  @override
  Future<bool> showRewarded() async {
    rewardedShows++;
    return true;
  }

  @override
  Future<bool> showInterstitial() async {
    interstitialShows++;
    return true;
  }
}

/// A store that answers like Play would: [buyResult] on buy, [restoreOwned] on restore.
class FakeIap extends IapService {
  FakeIap({this.buyResult = PurchaseOutcome.owned, this.restoreOwned = false, this.storePrice = 'US\$1.99'});
  final PurchaseOutcome buyResult;
  final bool restoreOwned;
  final String storePrice;
  int inits = 0, buys = 0, restores = 0;
  @override
  bool get supported => true;
  @override
  Future<void> init() async {
    inits++;
    price.value = storePrice;
  }

  @override
  Future<PurchaseOutcome> buy() async {
    buys++;
    if (buyResult == PurchaseOutcome.owned) owned.value = true;
    return buyResult;
  }

  @override
  Future<bool> restore() async {
    restores++;
    if (restoreOwned) owned.value = true;
    return restoreOwned;
  }
}

Future<void> _pumpUntil(WidgetTester tester, Finder f, {int maxFrames = 6000}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('never found $f');
}

Future<void> _settle(WidgetTester tester, [int frames = 3]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _dieOnce(WidgetTester tester) async {
  await tester.tapAt(const Offset(195, 422));
  await _pumpUntil(tester, find.byKey(const Key('death-card')));
  await _settle(tester, 14);
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('Store: supporter flag persists across opens; default false', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await Store.open();
    expect(a.supporter, isFalse);
    await a.setSupporter(true);
    final b = await Store.open();
    expect(b.supporter, isTrue);
  });

  test('AdPolicy: supporter suppresses every load and show, whatever else is true', () {
    final p = AdPolicy(supporter: false, appStartMs: 0, installMs: 0)..firstTapSeen = true;
    const now = 10 * 60 * 1000;
    expect(p.mayLoad, isTrue);
    expect(p.canOfferSecondChance(attempt: 5, checkpointPassed: true, usedToday: false, adReady: true), isTrue);
    expect(p.canShowInterstitial(kind: SessionBreak.cleared, nowMs: now, inAttempt: false, adReady: true), isTrue);
    p.supporter = true; // purchase mid-session
    expect(p.mayLoad, isFalse);
    expect(p.canOfferSecondChance(attempt: 5, checkpointPassed: true, usedToday: false, adReady: true), isFalse);
    expect(p.canShowRewarded(attempt: 5, checkpointPassed: true, usedToday: false, adReady: true, msSinceDeath: 5000), isFalse);
    expect(p.canShowInterstitial(kind: SessionBreak.cleared, nowMs: now, inAttempt: false, adReady: true), isFalse);
    expect(p.canShowInterstitial(kind: SessionBreak.resumedFromBackground, nowMs: now, inAttempt: false, adReady: true), isFalse);
  });

  testWidgets('title screen: SUPPORT + Restore shown with the store price; nothing on the death card', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _phone(tester);
    final iap = FakeIap();
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(seed: codeToSeed('400C1S'), adsService: FakeAds(), iapService: iap),
      ),
    );
    await _settle(tester);
    expect(iap.inits, 1, reason: 'store queried + startup restore at boot');
    expect(find.byKey(const Key('support')), findsOneWidget);
    expect(find.byKey(const Key('restore')), findsOneWidget);
    expect(find.textContaining('US\$1.99'), findsOneWidget, reason: 'localised store price, not the fallback');
    expect(find.byKey(const Key('supporter-mark')), findsNothing);
    await _dieOnce(tester);
    expect(find.byKey(const Key('death-card')), findsOneWidget);
    expect(find.byKey(const Key('support')), findsNothing, reason: 'no purchase UI on the death card');
    expect(find.byKey(const Key('support-cleared')), findsNothing);
    expect(find.byKey(const Key('restore')), findsNothing);
  });

  testWidgets('purchase: flag persisted, mark shown, ads never load or show afterwards', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _phone(tester);
    final ads = FakeAds();
    final iap = FakeIap();
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(seed: codeToSeed('400C1S'), adsService: ads, iapService: iap),
      ),
    );
    await _settle(tester);
    expect(ads.interstitialLoads, 1, reason: 'non-supporter preloads at boot');
    await tester.tap(find.byKey(const Key('support')));
    await _settle(tester);
    expect(iap.buys, 1);
    expect(find.byKey(const Key('supporter-mark')), findsOneWidget);
    expect(find.byKey(const Key('support')), findsNothing);
    expect(find.text('Thank you — ads removed'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('supporter'), isTrue);
    // Play on: three deaths would normally preload + offer the rewarded unit.
    for (var n = 1; n <= 3; n++) {
      await _dieOnce(tester);
      expect(find.text('attempt $n'), findsOneWidget);
    }
    expect(ads.rewardedLoads, 0);
    expect(ads.rewardedShows, 0);
    expect(ads.interstitialShows, 0);
    expect(ads.interstitialLoads, 1, reason: 'no new loads after the purchase');
    expect(find.byKey(const Key('second-chance')), findsNothing);
  });

  testWidgets('purchase cancelled / unavailable: nothing changes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _phone(tester);
    final iap = FakeIap(buyResult: PurchaseOutcome.cancelled);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(seed: codeToSeed('400C1S'), adsService: FakeAds(), iapService: iap),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const Key('support')));
    await _settle(tester);
    expect(find.byKey(const Key('supporter-mark')), findsNothing);
    expect(find.byKey(const Key('support')), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('supporter'), isNull);
  });

  testWidgets('restore button: owned on the account → flag persisted + mark; not owned → told so', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _phone(tester);
    final iap = FakeIap(restoreOwned: true);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(seed: codeToSeed('400C1S'), adsService: FakeAds(), iapService: iap),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const Key('restore')));
    await _settle(tester);
    expect(iap.restores, 1);
    expect(find.byKey(const Key('supporter-mark')), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('supporter'), isTrue);
    await tester.pump(const Duration(seconds: 2)); // toast timer
  });

  testWidgets('restore button: nothing owned → no flag, message shown', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _phone(tester);
    final iap = FakeIap(restoreOwned: false);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(seed: codeToSeed('400C1S'), adsService: FakeAds(), iapService: iap),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const Key('restore')));
    await _settle(tester);
    expect(find.byKey(const Key('supporter-mark')), findsNothing);
    expect(find.text('No Supporter purchase found for this account'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('supporter'), isNull);
    await tester.pump(const Duration(seconds: 2)); // toast timer
  });

  testWidgets('startup restore: store reports owned during init → supporter without any tap', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _phone(tester);
    final ads = FakeAds();
    final iap = _OwnedAtInitIap();
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(seed: codeToSeed('400C1S'), adsService: ads, iapService: iap),
      ),
    );
    await _settle(tester);
    expect(find.byKey(const Key('supporter-mark')), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('supporter'), isTrue);
    await _dieOnce(tester);
    await _dieOnce(tester);
    await _dieOnce(tester);
    expect(ads.rewardedLoads, 0, reason: 'restored supporter: no rewarded loads');
  });

  testWidgets('already a supporter: mark on the title, no SUPPORT/Restore, SDK never initialised', (tester) async {
    SharedPreferences.setMockInitialValues({'supporter': true});
    _phone(tester);
    final ads = FakeAds();
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(seed: codeToSeed('400C1S'), adsService: ads, iapService: FakeIap()),
      ),
    );
    await _settle(tester);
    expect(find.byKey(const Key('supporter-mark')), findsOneWidget);
    expect(find.byKey(const Key('support')), findsNothing);
    expect(find.byKey(const Key('restore')), findsNothing);
    expect(ads.inits, 0);
  });

  testWidgets('no store (web/desktop): no purchase UI anywhere — title, death, CLEARED', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(seed: codeToSeed('400C1S'), autoplay: true, iapService: NoIapService()),
      ),
    );
    await _settle(tester);
    expect(find.byKey(const Key('support')), findsNothing);
    expect(find.byKey(const Key('restore')), findsNothing);
    expect(find.byKey(const Key('supporter-mark')), findsNothing);
    await tester.tapAt(const Offset(195, 422)); // start; the solver clears the course
    await _pumpUntil(tester, find.text('CLEARED'));
    await _settle(tester, 30);
    expect(find.byKey(const Key('support-cleared')), findsNothing);
    expect(find.textContaining('REMOVE ADS'), findsNothing);
  });

  testWidgets('CLEARED card: one "REMOVE ADS" line for non-supporters with a store', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(seed: codeToSeed('400C1S'), autoplay: true, adsService: FakeAds(), iapService: FakeIap()),
      ),
    );
    await _settle(tester);
    await tester.tapAt(const Offset(195, 422));
    await _pumpUntil(tester, find.text('CLEARED'));
    await _settle(tester, 30);
    expect(find.byKey(const Key('support-cleared')), findsOneWidget);
    expect(find.textContaining('REMOVE ADS · US\$1.99'), findsOneWidget);
  });
}

class _OwnedAtInitIap extends FakeIap {
  @override
  Future<void> init() async {
    await super.init();
    owned.value = true;
  }
}

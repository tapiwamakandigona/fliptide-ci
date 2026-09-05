// Directive 02k / DEMAND §3: the ad cadence rules, pinned.
import 'package:fliptide/ads/ad_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const start = 1000000;
  AdPolicy fresh({bool supporter = false, int installAgoMs = kFreshInstallGuardMs * 10}) =>
      AdPolicy(supporter: supporter, appStartMs: start, installMs: start - installAgoMs);

  group('second chance (rewarded, opt-in)', () {
    test('never on attempt 1–2, even with a checkpoint and a loaded ad', () {
      final p = fresh();
      for (final a in [0, 1, 2]) {
        expect(p.canOfferSecondChance(attempt: a, checkpointPassed: true, usedToday: false, adReady: true), isFalse, reason: 'attempt $a');
      }
      expect(p.canOfferSecondChance(attempt: 3, checkpointPassed: true, usedToday: false, adReady: true), isTrue);
    });

    test('needs a checkpoint, an unused Daily and a loaded ad', () {
      final p = fresh();
      expect(p.canOfferSecondChance(attempt: 5, checkpointPassed: false, usedToday: false, adReady: true), isFalse);
      expect(p.canOfferSecondChance(attempt: 5, checkpointPassed: true, usedToday: true, adReady: true), isFalse, reason: 'once per Daily');
      expect(p.canOfferSecondChance(attempt: 5, checkpointPassed: true, usedToday: false, adReady: false), isFalse);
    });

    test('no ad within 300 ms of death (die → restart path untouched)', () {
      final p = fresh();
      bool show(int ms) => p.canShowRewarded(attempt: 3, checkpointPassed: true, usedToday: false, adReady: true, msSinceDeath: ms);
      expect(show(0), isFalse);
      expect(show(kDeathAdGuardMs - 1), isFalse);
      expect(show(kDeathAdGuardMs), isTrue);
    });
  });

  group('supporter', () {
    test('flag suppresses loads and every offer', () {
      final p = fresh(supporter: true)..firstTapSeen = true;
      expect(p.mayLoad, isFalse);
      expect(p.canOfferSecondChance(attempt: 9, checkpointPassed: true, usedToday: false, adReady: true), isFalse);
      expect(p.canShowInterstitial(kind: SessionBreak.cleared, nowMs: start + kAppStartGuardMs * 5, inAttempt: false, adReady: true), isFalse);
    });
  });

  group('interstitial (session break only)', () {
    test('never before the first tap, never inside an attempt', () {
      final p = fresh();
      final now = start + kAppStartGuardMs * 5;
      expect(p.canShowInterstitial(kind: SessionBreak.resumedFromBackground, nowMs: now, inAttempt: false, adReady: true), isFalse);
      p.firstTapSeen = true;
      expect(p.canShowInterstitial(kind: SessionBreak.resumedFromBackground, nowMs: now, inAttempt: true, adReady: true), isFalse);
      expect(p.canShowInterstitial(kind: SessionBreak.resumedFromBackground, nowMs: now, inAttempt: false, adReady: true), isTrue);
    });

    test('never within 60 s of app start', () {
      final p = fresh()..firstTapSeen = true;
      expect(p.canShowInterstitial(kind: SessionBreak.cleared, nowMs: start + kAppStartGuardMs - 1, inAttempt: false, adReady: true), isFalse);
      expect(p.canShowInterstitial(kind: SessionBreak.cleared, nowMs: start + kAppStartGuardMs, inAttempt: false, adReady: true), isTrue);
    });

    test('never in the first 3 minutes of a fresh install (DEMAND §3)', () {
      final p = fresh(installAgoMs: 0)..firstTapSeen = true;
      expect(p.canShowInterstitial(kind: SessionBreak.cleared, nowMs: start + kFreshInstallGuardMs - 1, inAttempt: false, adReady: true), isFalse);
      expect(p.canShowInterstitial(kind: SessionBreak.cleared, nowMs: start + kFreshInstallGuardMs, inAttempt: false, adReady: true), isTrue);
    });

    test('at most one per 3 minutes', () {
      final p = fresh()..firstTapSeen = true;
      final t0 = start + kAppStartGuardMs;
      expect(p.canShowInterstitial(kind: SessionBreak.cleared, nowMs: t0, inAttempt: false, adReady: true), isTrue);
      p.markInterstitialShown(t0);
      expect(p.canShowInterstitial(kind: SessionBreak.cleared, nowMs: t0 + kInterstitialGapMs - 1, inAttempt: false, adReady: true), isFalse);
      expect(p.canShowInterstitial(kind: SessionBreak.cleared, nowMs: t0 + kInterstitialGapMs, inAttempt: false, adReady: true), isTrue);
    });

    test('nothing to show → no', () {
      final p = fresh()..firstTapSeen = true;
      expect(p.canShowInterstitial(kind: SessionBreak.cleared, nowMs: start + kAppStartGuardMs, inAttempt: false, adReady: false), isFalse);
    });
  });
}

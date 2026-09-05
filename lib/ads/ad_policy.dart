/// The ad cadence rules as one pure state machine (DEMAND §3 + directive 02k).
/// No plugin code here so every rule is unit-testable with fake clocks.
library;

/// Rewarded "second chance" is never offered on attempts 1–2.
const int kSecondChanceMinAttempt = 3;

/// No ad of any kind within this many ms of a death (die → restart stays <300 ms).
const int kDeathAdGuardMs = 300;

/// Interstitials: at most one per 3 minutes.
const int kInterstitialGapMs = 3 * 60 * 1000;

/// Interstitials: never within 60 s of app start.
const int kAppStartGuardMs = 60 * 1000;

/// DEMAND §3: never within the first 3 minutes of a fresh install.
const int kFreshInstallGuardMs = 3 * 60 * 1000;

enum SessionBreak { cleared, resumedFromBackground }

class AdPolicy {
  AdPolicy({required this.supporter, required this.appStartMs, required this.installMs});

  /// Supporter IAP owned → every ad is off, including loads.
  bool supporter;

  /// Epoch ms of this process start.
  final int appStartMs;

  /// Epoch ms of the first ever launch (persisted).
  final int installMs;

  /// Nothing before the first tap of a session.
  bool firstTapSeen = false;

  int? lastInterstitialMs;

  /// Gate for every `load*` call — checked before the SDK is asked for anything.
  bool get mayLoad => !supporter;

  /// May the death overlay offer the opt-in "Second chance" button?
  bool canOfferSecondChance({
    required int attempt,
    required bool checkpointPassed,
    required bool usedToday,
    required bool adReady,
  }) =>
      mayLoad && attempt >= kSecondChanceMinAttempt && checkpointPassed && !usedToday && adReady;

  /// May the rewarded ad be shown right now (the button was tapped)?
  bool canShowRewarded({
    required int attempt,
    required bool checkpointPassed,
    required bool usedToday,
    required bool adReady,
    required int msSinceDeath,
  }) =>
      canOfferSecondChance(attempt: attempt, checkpointPassed: checkpointPassed, usedToday: usedToday, adReady: adReady) &&
      msSinceDeath >= kDeathAdGuardMs;

  /// Interstitial only at a real session break, never inside an attempt.
  bool canShowInterstitial({
    required SessionBreak kind,
    required int nowMs,
    required bool inAttempt,
    required bool adReady,
  }) {
    if (!mayLoad || !adReady) return false;
    if (!firstTapSeen) return false;
    if (inAttempt) return false;
    if (nowMs - appStartMs < kAppStartGuardMs) return false;
    if (nowMs - installMs < kFreshInstallGuardMs) return false;
    final last = lastInterstitialMs;
    if (last != null && nowMs - last < kInterstitialGapMs) return false;
    return true;
  }

  void markInterstitialShown(int nowMs) => lastInterstitialMs = nowMs;
}

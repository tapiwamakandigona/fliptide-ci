import 'dart:async';

import 'package:flame/game.dart';

import 'package:flutter/material.dart';

import 'ads/ad_policy.dart';
import 'ads/ads_service.dart';
import 'ads/ads_service_platform.dart';
import 'game/flip_game.dart';
import 'game/palette.dart';
import 'sim/course_code.dart';
import 'sim/generator.dart';
import 'sim/physics.dart';
import 'iap/iap_service.dart';
import 'iap/iap_service_platform.dart';
import 'store/store.dart';
import 'ui/save_image.dart';
import 'ui/share_card.dart';
import 'ui/share_sink.dart';
import 'ui/share_text.dart';
import 'ui/debug_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlipApp());
}

class FlipApp extends StatelessWidget {
  const FlipApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Web deep links: ?code=XXXXXX plays that course, ?auto=1 lets the solver
    // play (verification of the win path). Harmless elsewhere.
    final q = Uri.base.queryParameters;
    final seed = q['code'] == null ? null : codeToSeed(q['code']!);
    final auto = q['auto'] == '1';
    final perf = q['perf'] == '1';
    return MaterialApp(
      title: kGameName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.bg,
        colorScheme: const ColorScheme.dark(primary: Palette.player, surface: Palette.bg),
        fontFamily: 'Inter',
      ),
      home: PlayScreen(seed: seed, autoplay: auto, perf: perf),
    );
  }
}

/// One course: the Daily (seed == null) or a shared code. Generate, play, log, share.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, this.seed, this.autoplay = false, this.perf = false, this.adsService, this.iapService});

  /// null → today's Daily.
  final int? seed;
  final bool autoplay;

  /// Injected in tests; null → platform default (Android SDK, no-op elsewhere).
  final AdsService? adsService;

  /// Injected in tests; null → platform default (Play Billing on Android, no-op elsewhere).
  final IapService? iapService;

  /// `?perf=1`: show restart timings (F3 evidence).
  final bool perf;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with WidgetsBindingObserver implements FlipListener {
  Store? _store;
  DailyRecord? _rec;
  int _recKey = 0;

  // Ads (directive 02k). Android only; every load goes through _policy.mayLoad.
  late final AdsService _ads = widget.adsService ?? createAdsService();
  AdPolicy? _policy;
  final _secondChance = ValueNotifier<bool>(false);

  // Supporter unlock (directive 02O-1). Android only; web has no purchase UI.
  late final IapService _iap = widget.iapService ?? createIapService();
  final _supporter = ValueNotifier<bool>(false);
  bool _wasPaused = false;
  static final int _appStartMs = DateTime.now().millisecondsSinceEpoch;
  GeneratedCourse? _gen;
  FlipGame? _game;
  int? _dailyNo; // null when playing a code
  late String _code;

  final _progress = ValueNotifier<double>(0);
  final _attempts = ValueNotifier<int>(0);
  final _phase = ValueNotifier<RunState>(RunState.running);
  final _lastPct = ValueNotifier<int>(0);
  final List<double> _deathXs = [];
  bool _busy = false;
  String? _toast;

  bool get _isDaily => widget.seed == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ads.rewardedReady.addListener(_refreshSecondChance);
    _iap.owned.addListener(_onIapOwned);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ads.rewardedReady.removeListener(_refreshSecondChance);
    _iap.owned.removeListener(_onIapOwned);
    _iap.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _wasPaused = true;
    if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      _sessionBreak(SessionBreak.resumedFromBackground);
    }
  }

  Future<void> _boot() async {
    final store = await Store.open();
    final now = DateTime.now().toUtc();
    final spec = widget.seed == null ? GenSpec(seed: dailySeed(now)) : GenSpec.fromCode(widget.seed!);
    final gen = generate(spec);
    // Records are keyed per course so a code course keeps its own best/ghost.
    final recKey = _isDaily ? dailyNumber(now) : -spec.packedCode;
    final rec = store.daily(recKey);
    final installMs = await store.installMs();
    final policy = AdPolicy(supporter: store.supporter, appStartMs: _appStartMs, installMs: installMs);
    _supporter.value = store.supporter;
    setState(() {
      _store = store;
      _recKey = recKey;
      _policy = policy;
      _dailyNo = _isDaily ? dailyNumber(now) : null;
      _code = seedToCode(spec.packedCode);
      _gen = gen;
      _rec = rec;
      _attempts.value = 0; // 0 = not started yet → start card
      _game = FlipGame(course: gen.course, listener: this, ghost: rec.ghost, autoFlips: widget.autoplay ? gen.solution.flips : const [])..attempts = rec.attempts;
    });
    // Store first: startup restore may flip the supporter flag (02O-1). Not awaited
    // so the title screen never waits on Play.
    if (_iap.supported) unawaited(_iap.init());
    // Rule 4: the supporter flag is checked before the SDK is even initialised.
    if (policy.mayLoad && _ads.supported) {
      await _ads.init();
      // Consent initialization can outlive this screen or a Supporter restore.
      // Recheck at the load boundary; owned covers the async persistence window.
      if (mounted && identical(_policy, policy) && policy.mayLoad && !_iap.owned.value) _ads.loadInterstitial();
    }
  }

  // ---- supporter IAP (directive 02O-1) -----------------------------------

  /// Store said the product is owned (purchase or restore): persist, and every
  /// ad path goes dark through the policy flag — loaded units are never shown.
  Future<void> _onIapOwned() async {
    if (!_iap.owned.value || _store == null) return;
    final wasSupporter = _store!.supporter;
    await _store!.setSupporter(true);
    _policy?.supporter = true;
    _supporter.value = true;
    _refreshSecondChance();
    if (!wasSupporter && mounted) _showToast('Thank you — ads removed');
  }

  Future<void> _supportTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await _iap.buy();
      if (!mounted) return;
      switch (r) {
        case PurchaseOutcome.owned:
          await _onIapOwned();
        case PurchaseOutcome.pending:
          _showToast('Purchase pending — it unlocks when Play confirms');
        case PurchaseOutcome.cancelled:
          break;
        case PurchaseOutcome.unavailable:
          _showToast('Store not available right now');
        case PurchaseOutcome.error:
          _showToast('Purchase did not go through');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await _iap.restore();
      if (!mounted) return;
      if (ok) {
        await _onIapOwned();
      } else {
        _showToast('No Supporter purchase found for this account');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- ads -------------------------------------------------------------

  bool get _inAttempt => _phase.value == RunState.running && _attempts.value > 0;

  void _refreshSecondChance() {
    final game = _game;
    final policy = _policy;
    if (game == null || policy == null) {
      _secondChance.value = false;
      return;
    }
    _secondChance.value = _phase.value == RunState.dead && policy.canOfferSecondChance(attempt: _attempts.value, checkpointPassed: game.checkpoints.hasCheckpoint, usedToday: _store!.secondChanceUsed(_recKey), adReady: _ads.rewardedReady.value);
  }

  /// Preload the rewarded unit from the second death on, so it is ready when
  /// the offer first becomes legal (attempt 3). Never loads for supporters.
  void _maybePreloadRewarded(int attempts) {
    final policy = _policy;
    if (policy == null || !policy.mayLoad || !_ads.supported) return;
    if (attempts < kSecondChanceMinAttempt - 1 || _store!.secondChanceUsed(_recKey)) return;
    _ads.loadRewarded();
  }

  Future<void> _secondChanceTap() async {
    final game = _game!;
    final policy = _policy!;
    final ok = policy.canShowRewarded(attempt: _attempts.value, checkpointPassed: game.checkpoints.hasCheckpoint, usedToday: _store!.secondChanceUsed(_recKey), adReady: _ads.rewardedReady.value, msSinceDeath: (game.secondsSinceDeath * 1000).round());
    if (!ok || _busy) return;
    setState(() => _busy = true);
    try {
      final earned = await _ads.showRewarded();
      if (!mounted) return;
      if (earned) {
        await _store!.setSecondChanceUsed(_recKey);
        final pct = (game.checkpoints.frac * 100).round();
        if (game.resumeFromCheckpoint()) _showToast('Second chance · from $pct%');
      } else {
        _showToast('No second chance — ad not finished');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _refreshSecondChance();
    }
  }

  Future<void> _sessionBreak(SessionBreak kind) async {
    final policy = _policy;
    if (policy == null || _game == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!policy.canShowInterstitial(kind: kind, nowMs: now, inAttempt: _inAttempt, adReady: _ads.interstitialReady.value)) return;
    policy.markInterstitialShown(now);
    await _ads.showInterstitial();
    if (policy.mayLoad) _ads.loadInterstitial();
  }

  // ---- FlipListener ----------------------------------------------------

  @override
  void onProgress(double progress) => _progress.value = progress;

  @override
  void onAttempt(int attempts) {
    _policy?.firstTapSeen = true;
    _attempts.value = attempts;
    _progress.value = 0;
    _phase.value = RunState.running;
    _secondChance.value = false;
    publishState('running:$attempts');
    if (_game != null) publishRestartMs(_game!.restartMs);
  }

  @override
  void onDeath(double progress, int attempts, DeathCause cause) {
    final rec = _rec!;
    rec.attempts = attempts;
    _deathXs.add(progress * _gen!.course.length);
    if (progress > rec.best && !rec.won) {
      rec.best = progress;
      rec.ghost = List.of(_game!.sim.flips); // best dying run = ghost until cleared
    }
    _store!.save(rec);
    if (_dailyNo != null) _store!.touchDay(_dailyNo!);
    _store!.addDeath();
    _attempts.value = attempts;
    _progress.value = progress; // HUD bar/percent = the death frame, same as the overlay
    _lastPct.value = percentOf(progress);
    _phase.value = RunState.dead;
    publishState('dead:$attempts:${_lastPct.value}');
    _maybePreloadRewarded(attempts);
    _refreshSecondChance();
  }

  @override
  void onWin(int attempts, int frames) {
    final rec = _rec!;
    rec.attempts = attempts;
    rec.won = true;
    rec.best = 1;
    rec.ghost = List.of(_game!.sim.flips);
    _store!.save(rec);
    if (_dailyNo != null) _store!.touchDay(_dailyNo!);
    _attempts.value = attempts;
    _progress.value = 1;
    _lastPct.value = 100;
    _phase.value = RunState.won;
    _secondChance.value = false;
    publishState('won:$attempts');
    // Session break: after the CLEARED card has faded in (02j-3), never before.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _sessionBreak(SessionBreak.cleared);
    });
  }

  // ---- actions ---------------------------------------------------------

  Future<void> _shareText() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final rec = _rec!;
      final text = shareText(course: _gen!.course, dailyNumber: _dailyNo, progress: rec.won ? 1 : (_lastPct.value / 100), attempts: rec.attempts, won: rec.won, streak: _store!.streak);
      _showToast(await shareTextOut(text));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareCard() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final rec = _rec!;
      final png = await renderShareCard(ShareCardData(dailyNumber: _dailyNo ?? 0, progress: rec.won ? 1 : (_lastPct.value / 100), attempts: rec.attempts, course: _gen!.course, won: rec.won, streak: _store!.streak, deathXs: _deathXs));
      await saveImage(png, 'fliptide-${_isDaily ? "daily-$_dailyNo" : "course-$_code"}.png');
      _showToast('Card saved');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enterCode() async {
    final game = _game;
    if (game == null) return;
    final wasPaused = game.paused;
    var switchedCourse = false;
    // A modal takes the controls away: preserve the attempt until it closes.
    game.pauseEngine();
    final ctrl = TextEditingController();
    try {
      final code = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Palette.slab,
          title: const Text('Play a course code', style: TextStyle(fontWeight: FontWeight.w900)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 7,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4),
            decoration: const InputDecoration(hintText: 'ABC-123', counterText: ''),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('PLAY')),
          ],
        ),
      );
      if (code == null || !mounted) return;
      final seed = codeToSeed(code);
      if (seed == null) {
        _showToast('That code is not valid');
        return;
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PlayScreen(seed: seed)));
      switchedCourse = true;
    } finally {
      // Undo only this dialog's pause, never revive a replaced/disposed game.
      if (mounted && identical(_game, game) && !wasPaused && !switchedCourse) game.resumeEngine();
    }
  }

  void _goDaily() => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PlayScreen()));

  void _showToast(String msg) {
    setState(() => _toast = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Palette.player)),
      );
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: game, autofocus: true),
          _Hud(
            label: _dailyNo != null ? 'DAILY #$_dailyNo' : 'COURSE ${prettyCode(_code)}',
            code: prettyCode(_code),
            progress: _progress,
            attempts: _attempts,
            phase: _phase,
            lastPct: _lastPct,
            onRetry: game.retry,
            onShareText: _shareText,
            onShareCard: _shareCard,
            onEnterCode: _enterCode,
            onDaily: _isDaily ? null : _goDaily,
            secondChance: _secondChance,
            onSecondChance: _secondChanceTap,
            supporter: _supporter,
            iapSupported: _iap.supported,
            price: _iap.price,
            onSupport: _supportTap,
            onRestore: _restoreTap,
            checkpointPct: () => (game.checkpoints.frac * 100).round(),
            busy: _busy,
            best: _rec?.best ?? 0,
            seconds: nominalSeconds(_gen!.course),
          ),
          if (widget.perf)
            Positioned(
              left: 8,
              bottom: 8,
              child: ValueListenableBuilder<int>(
                valueListenable: _attempts,
                builder: (_, _, _) => Text(
                  'restart ms: ${game.restartMs.join(" ")}',
                  key: const Key('perf-restart'),
                  style: const TextStyle(fontSize: 12, color: Palette.textDim, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            ),
          if (_toast != null)
            Positioned(
              bottom: MediaQuery.sizeOf(context).height * 0.20 + 8, // above the button band
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Palette.slab, borderRadius: BorderRadius.circular(12)),
                  child: Text(_toast!, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.label,
    required this.code,
    required this.progress,
    required this.attempts,
    required this.phase,
    required this.lastPct,
    required this.onRetry,
    required this.onShareText,
    required this.onShareCard,
    required this.onEnterCode,
    required this.onDaily,
    required this.secondChance,
    required this.onSecondChance,
    required this.supporter,
    required this.iapSupported,
    required this.price,
    required this.onSupport,
    required this.onRestore,
    required this.checkpointPct,
    required this.busy,
    required this.best,
    required this.seconds,
  });

  final String label;
  final String code;
  final ValueNotifier<double> progress;
  final ValueNotifier<int> attempts;
  final ValueNotifier<RunState> phase;
  final ValueNotifier<int> lastPct;
  final VoidCallback onRetry;
  final VoidCallback onShareText;
  final VoidCallback onShareCard;
  final VoidCallback onEnterCode;
  final VoidCallback? onDaily;

  /// True while the rewarded "second chance" may be offered (directive 02k rule 2).
  final ValueNotifier<bool> secondChance;
  final VoidCallback onSecondChance;

  /// Supporter unlock (directive 02O-1): entry point on the title screen and one
  /// line on the CLEARED card; nothing on the death card; no UI when unsupported (web).
  final ValueNotifier<bool> supporter;
  final bool iapSupported;
  final ValueNotifier<String?> price;
  final VoidCallback onSupport;
  final VoidCallback onRestore;
  final int Function() checkpointPct;
  final bool busy;
  final double best;
  final double seconds;

  static const _dim = TextStyle(color: Palette.textDim, fontWeight: FontWeight.w700, fontSize: 13);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Palette.textDim, fontSize: 13),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ValueListenableBuilder<double>(
                    valueListenable: progress,
                    builder: (_, p, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(height: 10, color: Palette.corridor),
                          FractionallySizedBox(
                            widthFactor: best.clamp(0, 1),
                            child: Container(height: 10, color: Palette.slabEdge),
                          ),
                          FractionallySizedBox(
                            widthFactor: p.clamp(0, 1),
                            child: Container(height: 10, color: Palette.player),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (_, p, _) => SizedBox(
                    width: 64, // fits "100%" at w900/18 px — 52 wrapped it onto two lines on CLEARED
                    child: Text(
                      '${percentOf(p)}%',
                      key: const Key('hud-pct'),
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: attempts,
                  builder: (_, a, _) => Text('attempt $a', style: _dim),
                ),
                const Spacer(),
                Text('~${seconds.round()}s', style: _dim),
                const SizedBox(width: 12),
                _MiniBtn(label: 'CODE', onTap: onEnterCode),
                if (onDaily != null) ...[const SizedBox(width: 6), _MiniBtn(label: 'DAILY', onTap: onDaily!)],
              ],
            ),
          ),
          // Middle band: title / percent text only. IgnorePointer so every tap here
          // (the corridor, where the thumb already is) reaches the game and restarts.
          Expanded(
            child: IgnorePointer(
              child: Center(
                child: ValueListenableBuilder<RunState>(
                  valueListenable: phase,
                  builder: (_, ph, _) {
                    if (ph == RunState.running) {
                      return ValueListenableBuilder<int>(
                        valueListenable: attempts,
                        builder: (_, a, _) => a == 0 ? _Card(title: kGameName, line: 'tap to start · tap to flip gravity\ncode $code', accent: Palette.player) : const SizedBox.shrink(),
                      );
                    }
                    final won = ph == RunState.won;
                    final card = _Card(key: const Key('death-card'), title: won ? 'CLEARED' : '${lastPct.value}%', line: won ? 'attempt ${attempts.value} · tell someone' : 'tap anywhere to retry', accent: won ? Palette.finish : Palette.text);
                    if (!won) return card;
                    // CLEARED: the player sprite fades out first (kWonFadeS, in the game),
                    // then the caption fades in — they never overlap (directive 02j-3).
                    return TweenAnimationBuilder<double>(
                      key: const Key('won-fade'),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 300),
                      curve: const Interval(0.5, 1),
                      builder: (_, o, child) => Opacity(opacity: o, child: child),
                      child: card,
                    );
                  },
                ),
              ),
            ),
          ),
          // Bottom fifth: the button row, below the corridor and out of the flip-tap zone
          // (directive 02h-1b). Only the buttons themselves catch taps.
          LayoutBuilder(
            builder: (context, _) {
              final h = MediaQuery.sizeOf(context).height;
              return SizedBox(
                height: h * 0.20,
                child: Center(
                  child: ValueListenableBuilder<RunState>(
                    valueListenable: phase,
                    builder: (_, ph, _) {
                      if (ph == RunState.running) {
                        // Title screen (attempt 0): the Supporter entry point lives here.
                        return ValueListenableBuilder<int>(valueListenable: attempts, builder: (_, a, _) => a == 0 ? _supportRow() : const SizedBox.shrink());
                      }
                      final won = ph == RunState.won;
                      final row = Row(
                        key: const Key('death-buttons'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!won) _Btn(label: 'RETRY', onTap: onRetry, primary: true),
                          const SizedBox(width: 10),
                          _Btn(label: busy ? '…' : 'SHARE', onTap: onShareText, primary: won),
                          const SizedBox(width: 10),
                          _Btn(label: 'CARD', onTap: onShareCard),
                        ],
                      );
                      if (won) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            row,
                            if (iapSupported) ...[
                              const SizedBox(height: 8),
                              ValueListenableBuilder<bool>(
                                valueListenable: supporter,
                                builder: (_, s, _) => s
                                    ? const SizedBox.shrink()
                                    : ValueListenableBuilder<String?>(
                                        valueListenable: price,
                                        builder: (_, pr, _) => _MiniBtn(key: const Key('support-cleared'), label: 'REMOVE ADS · ${pr ?? kSupporterFallbackPrice}', onTap: onSupport),
                                      ),
                              ),
                            ],
                          ],
                        );
                      }
                      // Opt-in rewarded offer: its own line above the row, never on the
                      // retry path (tapping the corridor still restarts instantly).
                      return ValueListenableBuilder<bool>(
                        valueListenable: secondChance,
                        builder: (_, offer, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (offer) ...[
                              _Btn(key: const Key('second-chance'), label: 'SECOND CHANCE', onTap: onSecondChance),
                              const SizedBox(height: 4),
                              IgnorePointer(
                                child: Text(
                                  'watch an ad · resume from ${checkpointPct()}%',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.textDim),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            row,
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Title-screen Supporter row (02O-1). Web/desktop: nothing at all.
extension on _Hud {
  Widget _supportRow() {
    if (!iapSupported) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: supporter,
      builder: (_, s, _) {
        if (s) {
          return const Text(
            '♥ SUPPORTER · no ads',
            key: Key('supporter-mark'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Palette.finish),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: price,
              builder: (_, pr, _) => _MiniBtn(key: const Key('support'), label: busy ? '…' : 'SUPPORT · ${pr ?? kSupporterFallbackPrice} · REMOVES ADS', onTap: onSupport),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              key: const Key('restore'),
              behavior: HitTestBehavior.opaque,
              onTap: onRestore,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  'Restore purchase',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.textDim),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.title, required this.line, this.accent = Palette.text});
  final String title;
  final String line;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w900,
            color: accent,
            height: 1,
            letterSpacing: -2,
            shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 24)],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          line,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.textDim, height: 1.5),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({super.key, required this.label, required this.onTap, this.primary = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? Palette.player : Palette.slab,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: primary ? Palette.bg : Palette.text),
          ),
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.corridor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Palette.textDim),
          ),
        ),
      ),
    );
  }
}

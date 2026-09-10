import 'dart:async';

import 'package:flame/game.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'audio/flip_audio.dart';
import 'audio/flip_audio_players.dart';
import 'ads/ad_policy.dart';
import 'ads/ads_service.dart';
import 'ads/ads_service_platform.dart';
import 'game/flip_game.dart';
import 'game/palette.dart';
import 'sim/campaign.dart';
import 'sim/deep.dart';
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
import 'ui/more_games.dart';
import 'ui/feel.dart';
import 'ui/language.dart';
import 'ui/title_screen.dart';
import 'ui/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlipAudio.instance = PlayersAudio();
  runApp(const FlipApp());
}

class FlipApp extends StatefulWidget {
  const FlipApp({super.key});

  @override
  State<FlipApp> createState() => _FlipAppState();
}

class _FlipAppState extends State<FlipApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(FlipLanguage.load());
    unawaited(Feel.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Music stops the moment the app leaves the foreground and comes back
  /// with it; the run itself is paused by PlayScreen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        FlipAudio.instance.pauseAll();
      case AppLifecycleState.resumed:
        FlipAudio.instance.resumeAll();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Web deep links: ?code=XXXXXX plays that course, ?auto=1 lets the solver
    // play (verification of the win path). Harmless elsewhere.
    final q = Uri.base.queryParameters;
    final seed = q['code'] == null ? null : codeToSeed(q['code']!);
    final auto = q['auto'] == '1';
    final perf = q['perf'] == '1';
    final level = q['level'] == null ? null : levelById(q['level']!);
    final deep = q['deep'] == '1';
    return ValueListenableBuilder<String>(
      valueListenable: FlipLanguage.choice,
      builder: (_, choice, _) => MaterialApp(
        title: kGameName,
        debugShowCheckedModeBanner: false,
        supportedLocales: flipLocales,
        locale: FlipLanguage.locale(choice),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Palette.bg,
          colorScheme: const ColorScheme.dark(
            primary: Palette.player,
            surface: Palette.bg,
          ),
          fontFamily: 'Inter',
        ),
        // A shared link opens its course directly; everything else starts at the title.
        home: seed != null || level != null || auto || perf || deep
            ? PlayScreen(
                seed: seed,
                level: level,
                autoplay: auto,
                perf: perf,
                deep: deep,
              )
            : const TitleScreen(),
      ),
    );
  }
}

/// One course: the Daily (seed == null) or a shared code. Generate, play, log, share.
class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    this.seed,
    this.level,
    this.autoplay = false,
    this.perf = false,
    this.adsService,
    this.iapService,
    this.audio,
    this.deep = false,
    this.deepSeed,
  });

  /// null → today's Daily (unless [level] is set).
  final int? seed;

  /// The Deep (endless). A new corridor every dive; score = depth in metres.
  final bool deep;

  /// Fixed dive seed (tests / deterministic replays); null → random.
  final int? deepSeed;

  /// Injected in tests; null → the app-wide [FlipAudio.instance].
  final FlipAudio? audio;

  /// A campaign course (The Tides). Takes precedence over [seed].
  final CampaignLevel? level;
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

class _PlayScreenState extends State<PlayScreen>
    with WidgetsBindingObserver
    implements FlipListener {
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

  bool get _isCampaign => widget.level != null;
  bool get _isDeep => widget.deep;
  bool get _isDaily => widget.seed == null && !_isCampaign && !_isDeep;

  FlipAudio get _audio => widget.audio ?? FlipAudio.instance;

  // The Deep: depth reached this dive, best ever, and whether this dive set it.
  final _depth = ValueNotifier<int>(0);
  int _deepBest = 0;
  bool _deepNewBest = false;
  int _flipsThisAttempt = 0;

  /// Attempts in this sitting (stars are judged on these, not lifetime).
  int _sessionAttempts = 0;
  int _earnedStars = 0;

  /// Star chimes scheduled on a clear; cancelled if the screen goes away first.
  final List<Timer> _chimes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ads.rewardedReady.addListener(_refreshSecondChance);
    _iap.owned.addListener(_onIapOwned);
    _audio.music(Track.run);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ads.rewardedReady.removeListener(_refreshSecondChance);
    _iap.owned.removeListener(_onIapOwned);
    _iap.dispose();
    for (final t in _chimes) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasPaused = true;
    }
    if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      _sessionBreak(SessionBreak.resumedFromBackground);
    }
  }

  Future<void> _boot() async {
    final store = await Store.open();
    final now = DateTime.now().toUtc();
    final deepSeed = _isDeep ? (widget.deepSeed ?? newDeepSeed()) : null;
    final spec = _isCampaign
        ? widget.level!.spec
        : _isDeep
        ? GenSpec(seed: deepSeed!)
        : widget.seed == null
        ? GenSpec(seed: dailySeed(now))
        : GenSpec.fromCode(widget.seed!);
    final gen =
        widget.level?.buildCourse() ??
        (_isDeep ? generateDeep(deepSeed!) : generate(spec));
    // Records are keyed per course so a code course keeps its own best/ghost.
    // Campaign courses use a key derived from the level id so they never
    // collide with a Daily or a shared code.
    final recKey = _isCampaign
        ? widget.level!.recordKey
        : _isDeep
        ? kDeepRecordKey
        : (_isDaily ? dailyNumber(now) : -spec.packedCode);
    // The Deep keeps no per-corridor record (every dive is new); an in-memory
    // record carries the attempt counter for the HUD only.
    final rec = _isDeep ? DailyRecord(number: recKey) : store.daily(recKey);
    _deepBest = store.deepBest;
    final installMs = await store.installMs();
    final policy = AdPolicy(
      supporter: store.supporter,
      appStartMs: _appStartMs,
      installMs: installMs,
    );
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
      _game = FlipGame(
        course: gen.course,
        listener: this,
        ghost: rec.ghost,
        autoFlips: widget.autoplay ? gen.solution.flips : const [],
      )..attempts = rec.attempts;
    });
    // Store first: startup restore may flip the supporter flag (02O-1). Not awaited
    // so the title screen never waits on Play.
    if (_iap.supported) unawaited(_iap.init());
    // Rule 4: the supporter flag is checked before the SDK is even initialised.
    if (policy.mayLoad && _ads.supported) {
      await _ads.init();
      // Consent initialization can outlive this screen or a Supporter restore.
      // Recheck at the load boundary; owned covers the async persistence window.
      if (mounted &&
          identical(_policy, policy) &&
          policy.mayLoad &&
          !_iap.owned.value) {
        _ads.loadInterstitial();
      }
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

  bool get _inAttempt =>
      _phase.value == RunState.running && _attempts.value > 0;

  void _refreshSecondChance() {
    final game = _game;
    final policy = _policy;
    if (game == null || policy == null) {
      _secondChance.value = false;
      return;
    }
    _secondChance.value =
        _phase.value == RunState.dead &&
        policy.canOfferSecondChance(
          attempt: _attempts.value,
          checkpointPassed: game.checkpoints.hasCheckpoint,
          usedToday: _store!.secondChanceUsed(_recKey),
          adReady: _ads.rewardedReady.value,
        );
  }

  /// Preload the rewarded unit from the second death on, so it is ready when
  /// the offer first becomes legal (attempt 3). Never loads for supporters.
  void _maybePreloadRewarded(int attempts) {
    final policy = _policy;
    if (policy == null || !policy.mayLoad || !_ads.supported) return;
    if (attempts < kSecondChanceMinAttempt - 1 ||
        _store!.secondChanceUsed(_recKey)) {
      return;
    }
    _ads.loadRewarded();
  }

  Future<void> _secondChanceTap() async {
    final game = _game!;
    final policy = _policy!;
    final ok = policy.canShowRewarded(
      attempt: _attempts.value,
      checkpointPassed: game.checkpoints.hasCheckpoint,
      usedToday: _store!.secondChanceUsed(_recKey),
      adReady: _ads.rewardedReady.value,
      msSinceDeath: (game.secondsSinceDeath * 1000).round(),
    );
    if (!ok || _busy) return;
    setState(() => _busy = true);
    try {
      final earned = await _ads.showRewarded();
      if (!mounted) return;
      if (earned) {
        await _store!.setSecondChanceUsed(_recKey);
        final pct = (game.checkpoints.frac * 100).round();
        if (game.resumeFromCheckpoint()) {
          _showToast('Second chance · from $pct%');
        }
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
    if (!policy.canShowInterstitial(
      kind: kind,
      nowMs: now,
      inAttempt: _inAttempt,
      adReady: _ads.interstitialReady.value,
    )) {
      return;
    }
    policy.markInterstitialShown(now);
    await _ads.showInterstitial();
    if (policy.mayLoad) _ads.loadInterstitial();
  }

  // ---- FlipListener ----------------------------------------------------

  @override
  void onProgress(double progress) {
    _progress.value = progress;
    if (_isDeep) {
      _depth.value = deepMetres(progress * _gen!.course.length, _gen!.course);
    }
  }

  @override
  void onFlip() {
    _flipsThisAttempt++;
    _audio.sfx(Sfx.flip);
    Feel.tap();
  }

  @override
  void onLand() => _audio.sfx(Sfx.land);

  @override
  void onAttempt(int attempts) {
    _policy?.firstTapSeen = true;
    _flipsThisAttempt = 0;
    _deepNewBest = false;
    _sessionAttempts++;
    _attempts.value = attempts;
    _progress.value = 0;
    _phase.value = RunState.running;
    _secondChance.value = false;
    publishState('running:$attempts');
    if (_game != null) publishRestartMs(_game!.restartMs);
  }

  @override
  void onDeath(double progress, int attempts, DeathCause cause) {
    _audio.sfx(Sfx.death);
    Feel.death();
    final rec = _rec!;
    rec.attempts = attempts;
    _deathXs.add(progress * _gen!.course.length);
    if (progress > rec.best && !rec.won) {
      rec.best = progress;
      rec.ghost = List.of(
        _game!.sim.flips,
      ); // best dying run = ghost until cleared
    }
    if (_isDeep) {
      final metres = deepMetres(progress * _gen!.course.length, _gen!.course);
      _depth.value = metres;
      unawaited(
        _store!.recordDive(metres).then((newBest) {
          if (!mounted) return;
          if (newBest) {
            _deepBest = metres;
            _audio.sfx(Sfx.star);
          }
          setState(() => _deepNewBest = newBest);
        }),
      );
    } else {
      _store!.save(rec);
    }
    if (_dailyNo != null) _store!.touchDay(_dailyNo!);
    _store!.addDeath();
    _store!.addFlips(_flipsThisAttempt);
    _attempts.value = attempts;
    _progress.value =
        progress; // HUD bar/percent = the death frame, same as the overlay
    _lastPct.value = percentOf(progress);
    _phase.value = RunState.dead;
    publishState('dead:$attempts:${_lastPct.value}');
    _maybePreloadRewarded(attempts);
    _refreshSecondChance();
  }

  @override
  void onWin(int attempts, int frames) {
    _audio.sfx(Sfx.win);
    Feel.win();
    final rec = _rec!;
    rec.attempts = attempts;
    rec.won = true;
    rec.best = 1;
    rec.ghost = List.of(_game!.sim.flips);
    _store!.addFlips(_flipsThisAttempt);
    if (_isDeep) {
      // Touching the bottom: the whole corridor counts.
      final metres = _gen!.course.length;
      _depth.value = metres;
      unawaited(
        _store!.recordDive(metres).then((newBest) {
          if (mounted) setState(() => _deepNewBest = newBest);
        }),
      );
    } else {
      _store!.save(rec);
    }
    if (_isCampaign) {
      _earnedStars = starsFor(_sessionAttempts);
      _store!.clearLevel(widget.level!.id, _earnedStars);
      // One chime per star, in step with the StarRow reveal (kStarRevealStep).
      for (var i = 0; i < _earnedStars; i++) {
        _chimes.add(
          Timer(kStarRevealDelay + kStarRevealStep * i, () {
            if (mounted) _audio.sfx(Sfx.star);
          }),
        );
      }
      if (mounted) {
        setState(
          () {},
        ); // the CLEARED card reads the stars from the widget tree
      }
    }
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
      final text = _isDeep
          ? deepShareText(
              metres: _depth.value,
              best: _deepBest,
              attempts: rec.attempts,
            )
          : _isCampaign
          ? campaignShareText(
              level: widget.level!,
              attempts: _sessionAttempts,
              won: rec.won,
              progress: rec.won ? 1 : _lastPct.value / 100,
            )
          : shareText(
              course: _gen!.course,
              dailyNumber: _dailyNo,
              progress: rec.won ? 1 : (_lastPct.value / 100),
              attempts: rec.attempts,
              won: rec.won,
              streak: _store!.streak,
            );
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
      final png = await renderShareCard(
        ShareCardData(
          dailyNumber: _dailyNo ?? 0,
          progress: rec.won ? 1 : (_lastPct.value / 100),
          attempts: rec.attempts,
          course: _gen!.course,
          won: rec.won,
          streak: _store!.streak,
          deathXs: _deathXs,
          campaignLabel: widget.level?.label,
          campaignName: widget.level?.name,
          campaignUrl: _isCampaign
              ? '$kShareUrl/?level=${widget.level!.id}'
              : null,
        ),
      );
      await saveImage(
        png,
        'fliptide-${_isDaily ? "daily-$_dailyNo" : "course-$_code"}.png',
      );
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
    try {
      final code = await promptCourseCode(context);
      if (code == null || !mounted) return;
      final seed = codeToSeed(code);
      if (seed == null) {
        _showToast('That code is not valid');
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PlayScreen(seed: seed)),
      );
      switchedCourse = true;
    } finally {
      // Undo only this dialog's pause, never revive a replaced/disposed game.
      if (mounted && identical(_game, game) && !wasPaused && !switchedCourse) {
        game.resumeEngine();
      }
    }
  }

  void _goMenu() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const TitleScreen()),
      );
    }
  }

  void _goNext() {
    final next = nextLevel(widget.level!);
    if (next == null) return _goMenu();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PlayScreen(level: next)),
    );
  }

  void _goDaily() => Navigator.of(
    context,
  ).pushReplacement(MaterialPageRoute(builder: (_) => const PlayScreen()));

  /// The Deep: every dive is a new corridor. The game swaps its course in
  /// place (no route change, same widget), so the dive counter, HUD and music
  /// carry on; the death-tap guard is honoured exactly like a normal retry.
  void _diveAgain() {
    final game = _game;
    if (game == null) return;
    final seed = newDeepSeed();
    final gen = generateDeep(seed);
    final ok = game.replaceCourse(
      gen.course,
      autoFlips: widget.autoplay ? gen.solution.flips : const [],
    );
    if (!ok) return;
    _deathXs.clear();
    _depth.value = 0;
    setState(() {
      _gen = gen;
      _code = seedToCode(gen.course.seed);
      _deepNewBest = false;
    });
  }

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
            label: _isDeep
                ? ft(context, 'THE DEEP')
                : _isCampaign
                ? '${ft(context, 'TIDE {number}', args: {'number': widget.level!.tide})} · ${widget.level!.index}'
                : (_dailyNo != null
                      ? ft(
                          context,
                          'DAILY #{number}',
                          args: {'number': _dailyNo!},
                        )
                      : 'COURSE ${prettyCode(_code)}'),
            code: prettyCode(_code),
            levelName: _isCampaign ? widget.level!.name : null,
            levelHint: widget.level?.hint,
            levelStory: widget.level?.story,
            stars: _earnedStars,
            onMenu: _goMenu,
            onNext: _isCampaign ? _goNext : null,
            hasNext: _isCampaign && nextLevel(widget.level!) != null,
            progress: _progress,
            attempts: _attempts,
            phase: _phase,
            lastPct: _lastPct,
            onRetry: _isDeep ? _diveAgain : game.retry,
            onShareText: _shareText,
            onShareCard: _isDeep ? null : _shareCard,
            onEnterCode: _isCampaign || _isDeep ? null : _enterCode,
            onDaily: _isDaily || _isCampaign || _isDeep ? null : _goDaily,
            showPromo: !_isCampaign && !_isDeep,
            deep: _isDeep,
            depth: _depth,
            deepBest: _deepBest,
            deepNewBest: _deepNewBest,
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Palette.textDim,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          if (_toast != null)
            Positioned(
              bottom:
                  MediaQuery.sizeOf(context).height * 0.20 +
                  8, // above the button band
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.slab,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _toast!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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
    this.deep = false,
    this.depth,
    this.deepBest = 0,
    this.deepNewBest = false,
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
    this.showPromo = true,
    required this.busy,
    required this.best,
    required this.seconds,
    required this.onMenu,
    this.onNext,
    this.hasNext = false,
    this.levelName,
    this.levelHint,
    this.levelStory,
    this.stars = 0,
  });

  final String label;
  final String code;
  final ValueNotifier<double> progress;
  final ValueNotifier<int> attempts;
  final ValueNotifier<RunState> phase;
  final ValueNotifier<int> lastPct;
  final VoidCallback onRetry;
  final VoidCallback onShareText;

  /// null → no CARD button (The Deep has no course card yet).
  final VoidCallback? onShareCard;

  /// The Deep: depth counter replaces the percent, best depth on the death card.
  final bool deep;
  final ValueNotifier<int>? depth;
  final int deepBest;
  final bool deepNewBest;
  final VoidCallback? onEnterCode;
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

  /// Cross-promo footer on the start card (title-like surface only, 05b).
  final bool showPromo;
  final bool busy;
  final double best;
  final double seconds;
  final VoidCallback onMenu;
  final VoidCallback? onNext;
  final bool hasNext;
  final String? levelName;
  final String? levelHint;
  final String? levelStory;
  final int stars;

  static const _dim = TextStyle(
    color: Palette.textDim,
    fontWeight: FontWeight.w700,
    fontSize: 13,
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                _MiniBtn(key: const Key('hud-menu'), label: '‹', onTap: onMenu),
                const SizedBox(width: 8),
                // Loose-flex label: a long "COURSE XXX-XXX" ellipsises on 360-wide phones
                // before the bar collapses; short campaign labels take only what they need.
                Flexible(
                  flex: 3,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Palette.textDim,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                if (deep && depth != null)
                  Expanded(
                    flex: 2,
                    child: ValueListenableBuilder<int>(
                      valueListenable: depth!,
                      builder: (_, m, _) {
                        // The bar races your best: full at the record, green beyond it.
                        final target = deepBest < 50 ? 50 : deepBest;
                        final past = deepBest > 0 && m > deepBest;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Stack(
                            children: [
                              Container(height: 10, color: Palette.corridor),
                              AnimatedFractionallySizedBox(
                                duration: Duration(milliseconds: m == 0 ? 0 : 120),
                                curve: Curves.easeOut,
                                alignment: Alignment.centerLeft,
                                widthFactor: (m / target).clamp(0.0, 1.0),
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: past
                                          ? const [Palette.finish, Palette.finish]
                                          : const [Palette.playerDark, Palette.player],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                else
                Expanded(
                  flex: 2,
                  child: ValueListenableBuilder<double>(
                    valueListenable: progress,
                    builder: (_, p, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(height: 10, color: Palette.corridor),
                          FractionallySizedBox(
                            widthFactor: best.clamp(0, 1),
                            child: Container(
                              height: 10,
                              color: Palette.slabEdge,
                            ),
                          ),
                          // The fill eases towards the sim value so restarts snap back and progress glides.
                          AnimatedFractionallySizedBox(
                            duration: Duration(milliseconds: p == 0 ? 0 : 120),
                            curve: Curves.easeOut,
                            alignment: Alignment.centerLeft,
                            widthFactor: p.clamp(0, 1),
                            child: Container(
                              height: 10,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Palette.playerDark, Palette.player],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                if (deep && depth != null)
                  ValueListenableBuilder<int>(
                    valueListenable: depth!,
                    builder: (_, m, _) => SizedBox(
                      width: 72,
                      child: Text(
                        '$m m',
                        key: const Key('hud-depth'),
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  )
                else
                  ValueListenableBuilder<double>(
                    valueListenable: progress,
                    builder: (_, p, _) => SizedBox(
                      width:
                          64, // fits "100%" at w900/18 px — 52 wrapped it onto two lines on CLEARED
                      child: Text(
                        '${percentOf(p)}%',
                        key: const Key('hud-pct'),
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
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
                // Flexible: on the narrowest phones (and the wide test font) the
                // attempt label yields before the CODE / DAILY buttons do.
                Flexible(
                  child: ValueListenableBuilder<int>(
                    valueListenable: attempts,
                    builder: (_, a, _) => Text(
                      ft(context, deep ? 'dive {number}' : 'attempt {number}', args: {'number': a}),
                      style: _dim,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const Spacer(),
                if (deep)
                  Text(
                    '${ft(context, 'best')} $deepBest m',
                    key: const Key('hud-deep-best'),
                    style: _dim,
                  )
                else
                  Text('~${seconds.round()}s', style: _dim),
                const SizedBox(width: 12),
                if (onEnterCode != null)
                  _MiniBtn(label: ft(context, 'CODE'), onTap: onEnterCode!),
                if (onDaily != null) ...[
                  const SizedBox(width: 6),
                  _MiniBtn(label: ft(context, 'DAILY'), onTap: onDaily!),
                ],
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
                        builder: (_, a, _) => a == 0
                            ? (deep
                                  ? _Card(
                                      title: ft(context, 'THE DEEP'),
                                      line: ft(
                                        context,
                                        'no finish line · how deep can you go?',
                                      ),
                                      accent: Palette.finish,
                                      titleSize: 44,
                                    )
                                  : levelName != null
                                  ? _Card(
                                      title: ft(context, levelName!),
                                      line: ft(
                                        context,
                                        levelHint ??
                                            'tap to start · tap to flip gravity',
                                      ),
                                      accent: Palette.player,
                                      titleSize: 44,
                                    )
                                  : _Card(
                                      title: kGameName,
                                      line:
                                          '${ft(context, 'tap to start · tap to flip gravity')}\n${ft(context, 'CODE')} $code',
                                      accent: Palette.player,
                                    ))
                            : const SizedBox.shrink(),
                      );
                    }
                    final won = ph == RunState.won;
                    if (deep) {
                      final m = depth?.value ?? 0;
                      final deepCard = _Card(
                        key: const Key('death-card'),
                        title: won ? ft(context, 'THE BOTTOM') : '$m m',
                        line: won
                            ? ft(context, 'you touched the bottom of the Deep')
                            : deepNewBest
                            ? '${ft(context, 'new best depth')} · ${ft(context, 'tap anywhere to dive again')}'
                            : '${ft(context, 'best')} $deepBest m · ${ft(context, 'tap anywhere to dive again')}',
                        accent: won
                            ? Palette.finish
                            : (deepNewBest ? Palette.player : Palette.text),
                      );
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(
                          'deep-pop-${attempts.value}-$deepNewBest',
                        ),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutBack,
                        builder: (_, k, child) => Opacity(
                          opacity: k.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.86 + 0.14 * k,
                            child: child,
                          ),
                        ),
                        child: deepCard,
                      );
                    }
                    final card = _Card(
                      key: const Key('death-card'),
                      title: won ? ft(context, 'CLEARED') : '${lastPct.value}%',
                      line: won
                          ? (onNext != null
                                ? ft(
                                    context,
                                    'attempt {number}',
                                    args: {'number': attempts.value},
                                  )
                                : '${ft(context, 'attempt {number}', args: {'number': attempts.value})} · ${ft(context, 'tell someone')}')
                          : ft(context, 'tap anywhere to retry'),
                      accent: won ? Palette.finish : Palette.text,
                      stars: won && onNext != null ? stars : null,
                    );
                    if (won) {
                      // CLEARED: the sprite fades out first (kWonFadeS, in the game), then the caption fades in.
                      return TweenAnimationBuilder<double>(
                        key: const Key('won-fade'),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 300),
                        curve: const Interval(0.5, 1),
                        builder: (_, o, child) =>
                            Opacity(opacity: o, child: child),
                        child: card,
                      );
                    }
                    // Death: the percent pops in (scale + fade, 140 ms) instead of appearing.
                    return TweenAnimationBuilder<double>(
                      key: ValueKey('death-pop-${attempts.value}'),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOutBack,
                      builder: (_, k, child) => Opacity(
                        opacity: k.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.86 + 0.14 * k,
                          child: child,
                        ),
                      ),
                      child: card,
                    );
                  },
                ),
              ),
            ),
          ),
          // Bottom fifth normally; larger translated controls get a taller
          // band instead of tiny type. The corridor centre remains tap-through.
          LayoutBuilder(
            builder: (context, _) {
              final h = MediaQuery.sizeOf(context).height;
              final largeText = MediaQuery.textScalerOf(context).scale(14) > 17;
              return SizedBox(
                height: h * (largeText ? 0.34 : 0.20),
                child: Center(
                  child: ValueListenableBuilder<RunState>(
                    valueListenable: phase,
                    builder: (_, ph, _) {
                      if (ph == RunState.running) {
                        // Start card (attempt 0), Daily / code only: the Supporter entry point,
                        // then the cross-promo footer (directive 05b). Both vanish the moment the
                        // first run starts; neither is ever on the death / CLEARED cards. Campaign
                        // starts show the level name alone.
                        return ValueListenableBuilder<int>(
                          valueListenable: attempts,
                          builder: (_, a, _) => a == 0
                              ? !showPromo
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                        child: Text(
                                          ft(
                                            context,
                                            deep
                                                ? 'Every dive is a new corridor. It gets harder the deeper you go.'
                                                : (levelStory ?? 'Follow the current.'),
                                          ),
                                          key: const Key('campaign-story'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: Palette.textDim,
                                          ),
                                        ),
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _supportRow(),
                                          const SizedBox(height: 8),
                                          const MoreFromTsoro(compact: true),
                                        ],
                                      )
                              : const SizedBox.shrink(),
                        );
                      }
                      final won = ph == RunState.won;
                      final row = _Rise(
                        key: ValueKey(
                          'rise-${attempts.value}-${won ? 'w' : 'd'}',
                        ),
                        delay: won
                            ? const Duration(milliseconds: 150)
                            : Duration.zero,
                        child: Wrap(
                          key: const Key('death-buttons'),
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            if (!won || deep)
                              _Btn(
                                key: const Key('retry-btn'),
                                label: deep
                                    ? ft(context, 'DIVE AGAIN')
                                    : 'RETRY',
                                onTap: onRetry,
                                primary: true,
                              ),
                            if (won && onNext != null)
                              _Btn(
                                key: const Key('next-level'),
                                label: hasNext ? 'NEXT' : 'THE TIDES',
                                onTap: onNext!,
                                primary: true,
                              ),
                            _Btn(
                              label: busy ? '…' : 'SHARE',
                              onTap: onShareText,
                              primary: won && onNext == null,
                            ),
                            if (onShareCard != null)
                              _Btn(label: 'CARD', onTap: onShareCard!),
                          ],
                        ),
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
                                        builder: (_, pr, _) => _MiniBtn(
                                          key: const Key('support-cleared'),
                                          label:
                                              'REMOVE ADS · ${pr ?? kSupporterFallbackPrice}',
                                          onTap: onSupport,
                                        ),
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
                              _Btn(
                                key: const Key('second-chance'),
                                label: 'SECOND CHANCE',
                                onTap: onSecondChance,
                              ),
                              const SizedBox(height: 4),
                              IgnorePointer(
                                child: Text(
                                  'watch an ad · resume from ${checkpointPct()}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Palette.textDim,
                                  ),
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Palette.finish,
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: price,
              builder: (_, pr, _) => _MiniBtn(
                key: const Key('support'),
                label: busy
                    ? '…'
                    : 'SUPPORT · ${pr ?? kSupporterFallbackPrice} · REMOVES ADS',
                onTap: onSupport,
              ),
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Palette.textDim,
                  ),
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
  const _Card({
    super.key,
    required this.title,
    required this.line,
    this.accent = Palette.text,
    this.titleSize = 72,
    this.stars,
  });
  final String title;
  final String line;
  final Color accent;
  final double titleSize;

  /// Campaign clears show the stars just earned.
  final int? stars;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Scale down rather than wrap: "CLEARED" at 72 px is wider than a 300 px phone (from PR #6).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                color: accent,
                height: 1,
                letterSpacing: -2,
                shadows: const [
                  Shadow(color: Color(0xAA000000), blurRadius: 24),
                ],
              ),
            ),
          ),
        ),
        if (stars != null) ...[
          const SizedBox(height: 8),
          StarRow(
            key: const Key('cleared-stars'),
            earned: stars!,
            size: 30,
            animate: true,
          ),
        ],
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            line,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Palette.textDim,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fade-and-rise entrance (180 ms) for a band of controls. Pure paint: hit
/// testing follows the transform, so a tap during the rise still lands.
class _Rise extends StatelessWidget {
  const _Rise({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 180) + delay,
      curve: Interval(
        delay.inMilliseconds / (180 + delay.inMilliseconds),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (_, k, c) => Opacity(
        opacity: k,
        child: Transform.translate(offset: Offset(0, (1 - k) * 14), child: c),
      ),
      child: child,
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? Palette.player : Palette.slab,
      borderRadius: BorderRadius.circular(14),
      elevation: primary ? 6 : 0,
      shadowColor: primary
          ? Palette.player.withValues(alpha: 0.45)
          : Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: primary
                ? null
                : Border.all(
                    color: Palette.slabEdge.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
          ),
          // Narrow phones (< 360): trim horizontal padding only; label size stays (from PR #6).
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 360 ? 16 : 22,
            vertical: 14,
          ),
          child: Text(
            ft(context, label),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: primary ? Palette.bg : Palette.text,
            ),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Palette.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/flip_game.dart';
import 'game/palette.dart';
import 'sim/course_code.dart';
import 'sim/generator.dart';
import 'sim/physics.dart';
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
  const PlayScreen({super.key, this.seed, this.autoplay = false, this.perf = false});

  /// null → today's Daily.
  final int? seed;
  final bool autoplay;

  /// `?perf=1`: show restart timings (F3 evidence).
  final bool perf;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> implements FlipListener {
  Store? _store;
  DailyRecord? _rec;
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
    _boot();
  }

  Future<void> _boot() async {
    final store = await Store.open();
    final now = DateTime.now().toUtc();
    final spec = widget.seed == null ? GenSpec(seed: dailySeed(now)) : GenSpec.fromCode(widget.seed!);
    final gen = generate(spec);
    // Records are keyed per course so a code course keeps its own best/ghost.
    final recKey = _isDaily ? dailyNumber(now) : -spec.packedCode;
    final rec = store.daily(recKey);
    setState(() {
      _store = store;
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
  }

  // ---- FlipListener ----------------------------------------------------

  @override
  void onProgress(double progress) => _progress.value = progress;

  @override
  void onAttempt(int attempts) {
    _attempts.value = attempts;
    _progress.value = 0;
    _phase.value = RunState.running;
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
    publishState('won:$attempts');
  }

  // ---- actions ---------------------------------------------------------

  Future<void> _shareText() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final rec = _rec!;
      final text = shareText(
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
      final png = await renderShareCard(ShareCardData(
        dailyNumber: _dailyNo ?? 0,
        progress: rec.won ? 1 : (_lastPct.value / 100),
        attempts: rec.attempts,
        course: _gen!.course,
        won: rec.won,
        streak: _store!.streak,
        deathXs: _deathXs,
      ));
      await saveImage(png, 'fliptide-${_isDaily ? "daily-$_dailyNo" : "course-$_code"}.png');
      _showToast('Card saved');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enterCode() async {
    final ctrl = TextEditingController();
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
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Palette.player)));
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
                Text(label, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Palette.textDim, fontSize: 13)),
                const SizedBox(width: 14),
                Expanded(
                  child: ValueListenableBuilder<double>(
                    valueListenable: progress,
                    builder: (_, p, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(height: 10, color: Palette.corridor),
                          FractionallySizedBox(widthFactor: best.clamp(0, 1), child: Container(height: 10, color: Palette.slabEdge)),
                          // The fill eases towards the sim value so restarts snap back and progress glides.
                          AnimatedFractionallySizedBox(
                            duration: Duration(milliseconds: p == 0 ? 0 : 120),
                            curve: Curves.easeOut,
                            alignment: Alignment.centerLeft,
                            widthFactor: p.clamp(0, 1),
                            child: Container(height: 10, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Palette.playerDark, Palette.player]))),
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
                    child: Text('${percentOf(p)}%', key: const Key('hud-pct'), maxLines: 1, softWrap: false, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                ValueListenableBuilder<int>(valueListenable: attempts, builder: (_, a, _) => Text('attempt $a', style: _dim)),
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
                        builder: (_, a, _) => a == 0
                            ? _Card(title: kGameName, line: 'tap to start · tap to flip gravity\ncode $code', accent: Palette.player)
                            : const SizedBox.shrink(),
                      );
                    }
                    final won = ph == RunState.won;
                    final card = _Card(
                      key: const Key('death-card'),
                      title: won ? 'CLEARED' : '${lastPct.value}%',
                      line: won ? 'attempt ${attempts.value} · tell someone' : 'tap anywhere to retry',
                      accent: won ? Palette.finish : Palette.text,
                    );
                    if (won) {
                      // CLEARED: the sprite fades out first (kWonFadeS, in the game), then the caption fades in.
                      return TweenAnimationBuilder<double>(
                        key: const Key('won-fade'),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 300),
                        curve: const Interval(0.5, 1),
                        builder: (_, o, child) => Opacity(opacity: o, child: child),
                        child: card,
                      );
                    }
                    // Death: the percent pops in (scale + fade, 140 ms) instead of appearing.
                    return TweenAnimationBuilder<double>(
                      key: ValueKey('death-pop-${attempts.value}'),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOutBack,
                      builder: (_, k, child) => Opacity(opacity: k.clamp(0.0, 1.0), child: Transform.scale(scale: 0.86 + 0.14 * k, child: child)),
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
                      if (ph == RunState.running) return const SizedBox.shrink();
                      final won = ph == RunState.won;
                      return _Rise(
                        key: ValueKey('rise-${attempts.value}-${won ? 'w' : 'd'}'),
                        delay: won ? const Duration(milliseconds: 150) : Duration.zero,
                        child: Row(
                          key: const Key('death-buttons'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!won) _Btn(label: 'RETRY', onTap: onRetry, primary: true),
                            const SizedBox(width: 10),
                            _Btn(label: busy ? '…' : 'SHARE', onTap: onShareText, primary: won),
                            const SizedBox(width: 10),
                            _Btn(label: 'CARD', onTap: onShareCard),
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
        Text(title, style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: accent, height: 1, letterSpacing: -2, shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 24)])),
        const SizedBox(height: 6),
        Text(line, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.textDim, height: 1.5)),
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
      curve: Interval(delay.inMilliseconds / (180 + delay.inMilliseconds), 1, curve: Curves.easeOutCubic),
      builder: (_, k, c) => Opacity(opacity: k, child: Transform.translate(offset: Offset(0, (1 - k) * 14), child: c)),
      child: child,
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.onTap, this.primary = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? Palette.player : Palette.slab,
      borderRadius: BorderRadius.circular(14),
      elevation: primary ? 6 : 0,
      shadowColor: primary ? Palette.player.withValues(alpha: 0.45) : Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: primary ? null : Border.all(color: Palette.slabEdge.withValues(alpha: 0.6), width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: primary ? Palette.bg : Palette.text)),
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.label, required this.onTap});
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
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Palette.textDim)),
        ),
      ),
    );
  }
}

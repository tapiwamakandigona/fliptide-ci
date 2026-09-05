/// Flame renderer + input for one course. The sim is authoritative; this
/// class only accumulates time, steps the sim at 120 Hz and draws it.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../sim/course.dart';
import '../sim/physics.dart';
import 'palette.dart';

/// What the game tells the Flutter shell.
abstract class FlipListener {
  void onDeath(double progress, int attempts, DeathCause cause);
  void onWin(int attempts, int frames);
  void onProgress(double progress);

  /// A new attempt began (first start or restart). [attempts] is 1-based.
  void onAttempt(int attempts);
}

/// Taps within this many seconds after death are ignored (directive 02h-1c).
const double kDeathTapGuardS = 0.15;

/// Seconds over which the player sprite fades out after clearing the course.
const double kWonFadeS = 0.15;

class FlipGame extends FlameGame with TapCallbacks, KeyboardEvents {
  FlipGame({required this.course, required this.listener, List<int> ghost = const [], List<int> autoFlips = const []}) : _ghostFlips = ghost.toSet(), _autoFlips = autoFlips.toSet();

  final Course course;
  final FlipListener listener;
  final Set<int> _ghostFlips;

  /// Debug/verification: frames at which the game taps itself (`?auto=1`).
  final Set<int> _autoFlips;

  late Sim sim;
  Sim? _ghost;
  SimState? _prev; // previous sim state for interpolation
  double _acc = 0;
  bool _tap = false;
  int attempts = 0;
  double lastDeathX = -1;
  double _deathTimer = 0;
  double _wonTimer = 0;
  double _squash = 0;
  final List<_Particle> _particles = [];
  bool _started = false;

  // ---- render-only state (never touches the sim) ----
  /// Wall time accumulated for ambient animation (finish pulse, blink, gate).
  double _clock = 0;

  /// 0..1 flip animation: the sprite turns over (scaleY +1 → −1) after a flip.
  double _flipAnim = 1;
  Side _visSide = Side.floor;

  /// Airborne stretch factor 0..1 derived from |vy|.
  double _stretch = 0;

  /// Recent interpolated positions for the motion trail (world tiles).
  final List<_Trail> _trail = [];

  /// Camera shake: remaining seconds and amplitude (px).
  double _shakeT = 0;
  double _shakeAmp = 0;

  /// Red vignette flash after death, seconds remaining.
  double _flash = 0;

  /// F3 instrumentation: wall-clock ms from death to the first sim step of the
  /// next attempt that accepted input. Read via `?perf=1` HUD or debug log.
  final List<int> restartMs = [];
  DateTime? _deathAt;
  bool _awaitingFirstStep = false;

  /// Tiles visible across the viewport width.
  double get tilesAcross => size.x > size.y ? 15 : 9;
  double get tile => size.x / tilesAcross;

  /// Player's screen x as a fraction of width.
  static const _playerScreenX = 0.32;

  @override
  Color backgroundColor() => Palette.bg;

  @override
  Future<void> onLoad() async {
    _reset();
  }

  void _reset() {
    sim = Sim(course);
    _prev = sim.s.copy();
    _acc = 0;
    _tap = false;
    _deathTimer = 0;
    _wonTimer = 0;
    _squash = 0;
    _particles.clear();
    _trail.clear();
    _flipAnim = 1;
    _visSide = Side.floor;
    _stretch = 0;
    _shakeT = 0;
    _flash = 0;
    _ghost = _ghostFlips.isEmpty ? null : Sim(course);
    attempts++;
    if (_deathAt != null) _awaitingFirstStep = true;
    if (_started) listener.onAttempt(attempts);
  }

  /// A press from any input path.
  void press() {
    if (!_started) {
      _started = true;
      listener.onAttempt(attempts);
      return;
    }
    if (sim.s.state == RunState.dead) {
      if (_deathTimer > kDeathTapGuardS) _reset(); // the tap that killed you is not a retry
      return;
    }
    if (sim.s.state == RunState.won) return;
    _tap = true;
  }

  /// Restart from the HUD retry button (same post-death guard as a tap).
  void retry() {
    if (sim.s.state == RunState.dead && _deathTimer <= kDeathTapGuardS) return;
    _reset();
  }

  /// Player sprite opacity: 1 while running/dead-burst, fading to 0 within
  /// [kWonFadeS] after the run is won.
  double get playerAlpha => sim.s.state == RunState.won ? (1 - _wonTimer / kWonFadeS).clamp(0.0, 1.0) : 1.0;

  /// True once the post-death guard has elapsed (taps now restart).
  bool get canRetry => sim.s.state == RunState.dead && _deathTimer > kDeathTapGuardS;

  @override
  void onTapDown(TapDownEvent event) => press();

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW || k == LogicalKeyboardKey.enter) {
        press();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final clamped = math.min(dt, 0.1);
    _clock += clamped;
    if (!_started) return;
    for (final p in _particles) {
      p.update(clamped);
    }
    _particles.removeWhere((p) => p.life <= 0);
    _squash = math.max(0, _squash - clamped * 6);
    _flipAnim = math.min(1, _flipAnim + clamped / kFlipAnimS);
    if (_shakeT > 0) _shakeT = math.max(0, _shakeT - clamped);
    if (_flash > 0) _flash = math.max(0, _flash - clamped);
    for (final tr in _trail) {
      tr.life -= clamped * 5;
    }
    _trail.removeWhere((tr) => tr.life <= 0);

    if (sim.s.state == RunState.dead) {
      _deathTimer += clamped;
      return;
    }
    if (sim.s.state == RunState.won) {
      _wonTimer += clamped;
      return;
    }

    _acc += clamped;
    while (_acc >= kDt) {
      _acc -= kDt;
      _prev = sim.s.copy();
      final wasGrounded = sim.s.grounded;
      final wasSide = sim.s.side;
      if (_awaitingFirstStep) {
        _awaitingFirstStep = false;
        restartMs.add(DateTime.now().difference(_deathAt!).inMilliseconds);
        _deathAt = null;
      }
      sim.step(tap: _tap || _autoFlips.contains(sim.s.frame));
      _tap = false;
      _ghost?.step(tap: _ghostFlips.contains(_ghost!.s.frame));
      if (sim.s.side != wasSide) {
        // Left the surface: start the turn-over and kick off a little dust.
        _flipAnim = 0;
        _visSide = wasSide;
        _dust(sim.s, wasSide, 4);
      }
      if (!wasGrounded && sim.s.grounded) {
        _squash = 1;
        _dust(sim.s, sim.s.side, 6);
      }
      if (sim.s.state == RunState.dead) {
        lastDeathX = sim.s.x;
        _deathAt = DateTime.now();
        _burst(sim.s);
        _shakeT = kShakeS;
        _shakeAmp = 1;
        _flash = kFlashS;
        _trail.clear();
        listener.onDeath(sim.progress, attempts, sim.s.cause);
        break;
      }
      if (sim.s.state == RunState.won) {
        _confetti(sim.s);
        _trail.clear();
        listener.onWin(attempts, sim.s.frame);
        break;
      }
    }
    // Airborne stretch follows vertical speed; grounded it relaxes to 0.
    final target = sim.s.grounded ? 0.0 : (sim.s.vy.abs() / 22).clamp(0.0, 1.0);
    _stretch += (target - _stretch) * math.min(1, clamped * 18);
    if (sim.s.state == RunState.running) listener.onProgress(sim.progress);
  }

  void _burst(SimState s) {
    final rnd = math.Random(s.frame);
    for (var i = 0; i < 26; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final sp = 4 + rnd.nextDouble() * 10;
      final white = i % 4 == 0;
      _particles.add(
        _Particle(
          s.x + 0.4,
          s.y + 0.4,
          math.cos(a) * sp,
          math.sin(a) * sp,
          0.5 + rnd.nextDouble() * 0.45,
          size: white ? 0.10 : 0.14 + rnd.nextDouble() * 0.1,
          color: white ? Palette.spikeTip : Palette.player,
          gravity: 30,
          spin: rnd.nextDouble() * 12 - 6,
        ),
      );
    }
  }

  /// Small puff where the creature leaves or meets a surface.
  void _dust(SimState s, Side side, int n) {
    final rnd = math.Random(s.frame * 7 + n);
    final y = side == Side.floor ? s.y + 0.05 : s.y + 0.75;
    final dir = side == Side.floor ? 1.0 : -1.0;
    for (var i = 0; i < n; i++) {
      final vx = -(1.5 + rnd.nextDouble() * 3);
      final vy = dir * (0.5 + rnd.nextDouble() * 2.5);
      _particles.add(
        _Particle(s.x + 0.1 + rnd.nextDouble() * 0.6, y, vx, vy, 0.25 + rnd.nextDouble() * 0.2, size: 0.08 + rnd.nextDouble() * 0.08, color: Palette.dust, gravity: 0, drag: 4, round: true),
      );
    }
  }

  /// CLEARED: a short shower in finish-green and white (never player-yellow,
  /// so the caption rect stays clean — directive 02j-3).
  void _confetti(SimState s) {
    final rnd = math.Random(s.frame + 99);
    for (var i = 0; i < 22; i++) {
      final a = -math.pi / 2 + (rnd.nextDouble() - 0.5) * 1.6;
      final sp = 6 + rnd.nextDouble() * 8;
      _particles.add(
        _Particle(
          s.x + 0.4,
          s.y + 0.4,
          math.cos(a) * sp,
          math.sin(a) * sp,
          0.35 + rnd.nextDouble() * 0.25,
          size: 0.08 + rnd.nextDouble() * 0.08,
          color: i.isEven ? Palette.finish : Palette.spikeTip,
          gravity: 24,
          spin: rnd.nextDouble() * 10 - 5,
        ),
      );
    }
  }

  // ---- drawing ---------------------------------------------------------

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final t = tile;
    final h = course.height;
    final w = size.x;
    final vh = size.y;

    // Interpolated player position.
    final alpha = sim.s.state == RunState.running ? (_acc / kDt).clamp(0.0, 1.0) : 1.0;
    final p = _prev ?? sim.s;
    final px = p.x + (sim.s.x - p.x) * alpha;
    final py = p.y + (sim.s.y - p.y) * alpha;

    // Camera: player at 32% of width; corridor vertically centred.
    final camX = px - _playerScreenX * tilesAcross;
    final corridorTop = (vh - h * t) / 2;
    final corridorBot = corridorTop + h * t;
    double sx(double x) => (x - camX) * t;
    double sy(double y) => corridorTop + (h - y) * t; // world y up → screen down

    // Camera shake (death only): small, decaying, deterministic per frame.
    canvas.save();
    if (_shakeT > 0) {
      final k = _shakeT / kShakeS;
      final rnd = math.Random((_clock * 1000).floor());
      final amp = t * 0.12 * k * k * _shakeAmp;
      canvas.translate((rnd.nextDouble() * 2 - 1) * amp, (rnd.nextDouble() * 2 - 1) * amp);
    }

    // Corridor interior with a soft vertical gradient (lighter towards the
    // middle) so the two surfaces read as walls, not as a flat band.
    final interior = Rect.fromLTWH(0, corridorTop, w, h * t);
    canvas.drawRect(interior, Paint()..shader = Gradient.linear(interior.topLeft, interior.bottomLeft, [Palette.corridorDeep, Palette.corridor, Palette.corridorDeep], [0, 0.5, 1]));

    // Parallax backdrop: faint pillars drifting at half speed behind the grid.
    final far = Paint()..color = Palette.pillar;
    final farCam = camX * 0.5;
    final farFirst = farCam.floor();
    for (var cx = farFirst - 1; cx <= farFirst + tilesAcross + 2; cx++) {
      final hsh = _hash(cx);
      if (hsh % 3 != 0) continue;
      final x = (cx - farCam) * t;
      final pw = t * (0.35 + (hsh % 5) * 0.08);
      final ph = h * t * (0.25 + (hsh % 7) * 0.09);
      final fromTop = hsh % 2 == 0;
      final r = fromTop ? Rect.fromLTWH(x, corridorTop, pw, ph) : Rect.fromLTWH(x, corridorBot - ph, pw, ph);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(pw * 0.3)), far);
    }

    // Grid lines every tile (subtle, gives speed).
    final gridPaint = Paint()
      ..color = Palette.grid
      ..strokeWidth = 1;
    final firstCol = camX.floor();
    for (var cx = firstCol; cx <= firstCol + tilesAcross + 1; cx++) {
      final x = sx(cx.toDouble());
      canvas.drawLine(Offset(x, corridorTop), Offset(x, corridorBot), gridPaint);
    }

    // Slabs (outside the corridor) so floor/ceiling read as solid; each has a
    // lit inner edge and a soft shadow cast into the corridor.
    final slab = Paint()..color = Palette.slab;
    // The slabs darken away from the corridor so the play band is the bright core.
    final topSlab = Rect.fromLTRB(0, 0, w, corridorTop);
    final botSlab = Rect.fromLTRB(0, corridorBot, w, vh);
    if (topSlab.height > 0) {
      canvas.drawRect(topSlab, Paint()..shader = Gradient.linear(topSlab.bottomLeft, topSlab.topLeft, [Palette.slab, Palette.slabFar]));
    }
    if (botSlab.height > 0) {
      canvas.drawRect(botSlab, Paint()..shader = Gradient.linear(botSlab.topLeft, botSlab.bottomLeft, [Palette.slab, Palette.slabFar]));
    }
    final edgeW = math.max(2.0, t * 0.08);
    final edge = Paint()
      ..color = Palette.slabEdge
      ..strokeWidth = edgeW;
    final shadowH = t * 0.35;
    canvas.drawRect(
      Rect.fromLTWH(0, corridorTop, w, shadowH),
      Paint()..shader = Gradient.linear(Offset(0, corridorTop), Offset(0, corridorTop + shadowH), [Palette.shadow, Palette.shadow.withValues(alpha: 0)]),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, corridorBot - shadowH, w, shadowH),
      Paint()..shader = Gradient.linear(Offset(0, corridorBot), Offset(0, corridorBot - shadowH), [Palette.shadow, Palette.shadow.withValues(alpha: 0)]),
    );
    canvas.drawLine(Offset(0, corridorTop), Offset(w, corridorTop), edge);
    canvas.drawLine(Offset(0, corridorBot), Offset(w, corridorBot), edge);
    // Faint seams every tile on the slabs, moving with the world.
    final seam = Paint()
      ..color = Palette.seam
      ..strokeWidth = 1;
    for (var cx = firstCol; cx <= firstCol + tilesAcross + 1; cx++) {
      final x = sx(cx.toDouble());
      canvas.drawLine(Offset(x, 0), Offset(x, corridorTop - edgeW), seam);
      canvas.drawLine(Offset(x, corridorBot + edgeW), Offset(x, vh), seam);
    }

    // Columns.
    final spikePaint = Paint()..color = Palette.spike;
    final spikeGlow = Paint()..color = Palette.spike.withValues(alpha: 0.10);
    final tipPaint = Paint()..color = Palette.spikeTip;
    final blockLight = Paint()..color = Palette.slabLight;
    for (var cx = firstCol - 1; cx <= firstCol + tilesAcross + 2; cx++) {
      final col = course.at(cx);
      final x0 = sx(cx.toDouble());
      final x1 = x0 + t;
      if (cx < 0 || cx >= course.length) continue;
      if (col.isPit) {
        // Pit: darkness below the floor line, with a faint depth gradient.
        final pit = Rect.fromLTRB(x0, sy(0), x1, vh);
        canvas.drawRect(pit, Paint()..shader = Gradient.linear(pit.topLeft, Offset(x0, math.min(vh, sy(0) + t * 1.5)), [Palette.corridorDeep, Palette.bg]));
        // Pit walls: only where a neighbour is solid, so a wide pit reads as one hole.
        final wall = Paint()
          ..color = Palette.slabEdge.withValues(alpha: 0.55)
          ..strokeWidth = math.max(1.5, t * 0.05);
        if (cx > 0 && !course.at(cx - 1).isPit) canvas.drawLine(pit.topLeft, pit.bottomLeft, wall);
        if (cx + 1 < course.length && !course.at(cx + 1).isPit) canvas.drawLine(pit.topRight, pit.bottomRight, wall);
      } else if (col.floorH > 0) {
        final r = Rect.fromLTRB(x0, sy(col.floorH.toDouble()), x1, sy(0));
        canvas.drawRect(r, slab);
        // Left face catches the light; top edge is the walkable rim.
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, math.max(1.5, t * 0.06), r.height), blockLight);
        canvas.drawLine(r.topLeft, r.topRight, edge);
      }
      if (col.ceilH > 0) {
        final r = Rect.fromLTRB(x0, sy(h.toDouble()), x1, sy((h - col.ceilH).toDouble()));
        canvas.drawRect(r, slab);
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, math.max(1.5, t * 0.06), r.height), blockLight);
        canvas.drawLine(r.bottomLeft, r.bottomRight, edge);
      }
      if (col.floorSpike && !col.isPit) {
        _drawSpike(canvas, x0, x1, t, sy(col.floorH.toDouble()), -1, spikePaint, spikeGlow, tipPaint);
      }
      if (col.ceilSpike) {
        _drawSpike(canvas, x0, x1, t, sy((h - col.ceilH).toDouble()), 1, spikePaint, spikeGlow, tipPaint);
      }
    }

    // Finish gate: a pulsing checker column with a soft green wash before it.
    final fx = sx((course.length - kFinishColumns).toDouble());
    if (fx > -t * 3 && fx < w + t) {
      final pulse = 0.75 + 0.25 * math.sin(_clock * 5);
      final wash = Rect.fromLTRB(fx - t * 2.5, corridorTop, fx, corridorBot);
      canvas.drawRect(wash, Paint()..shader = Gradient.linear(wash.centerLeft, wash.centerRight, [Palette.finish.withValues(alpha: 0), Palette.finish.withValues(alpha: 0.10 * pulse)]));
      final fp = Paint()
        ..color = Palette.finish.withValues(alpha: pulse)
        ..strokeWidth = math.max(3, t * 0.12)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < h * 2; i++) {
        if (i.isEven) {
          canvas.drawLine(Offset(fx, corridorTop + i * t / 2 + 2), Offset(fx, corridorTop + (i + 1) * t / 2 - 2), fp);
        }
      }
    }

    // Last-death marker.
    if (lastDeathX >= 0 && sim.s.state == RunState.running) {
      final mx = sx(lastDeathX + 0.4);
      if (mx > -t && mx < w + t) {
        final mp = Paint()
          ..color = Palette.marker.withValues(alpha: 0.85)
          ..strokeWidth = math.max(2, t * 0.09)
          ..strokeCap = StrokeCap.round;
        final my = corridorTop - t * 0.55;
        final r = t * 0.22;
        canvas.drawLine(Offset(mx - r, my - r), Offset(mx + r, my + r), mp);
        canvas.drawLine(Offset(mx - r, my + r), Offset(mx + r, my - r), mp);
      }
    }

    // Ghost.
    final g = _ghost;
    if (g != null && g.s.state == RunState.running) {
      _drawCreature(canvas, sx(g.s.x), sy(g.s.y), t, g.s.side, 0, Palette.ghost, ghost: true);
    }

    // Motion trail (airborne only): fading afterimages behind the creature.
    if (sim.s.state == RunState.running) {
      if (!sim.s.grounded) {
        _trail.add(_Trail(px, py, sim.s.side, 1));
        if (_trail.length > kTrailLen) _trail.removeAt(0);
      }
      for (final tr in _trail) {
        final a = 0.28 * tr.life * tr.life;
        _drawCreature(canvas, sx(tr.x), sy(tr.y), t, tr.side, 0, Palette.player.withValues(alpha: a), ghost: true, scale: 0.85 + 0.15 * tr.life);
      }
    }

    // Player. On CLEARED it fades out over kWonFadeS so the overlay caption
    // never has the sprite drawn on top of it (directive 02j-3).
    if (sim.s.state != RunState.dead && playerAlpha > 0) {
      _drawCreature(
        canvas,
        sx(px),
        sy(py),
        t,
        sim.s.side,
        _squash,
        Palette.player.withValues(alpha: playerAlpha),
        flip: _flipAnim,
        fromSide: _visSide,
        stretch: _stretch,
        vy: sim.s.vy,
        blink: _blink,
      );
    }

    // Particles.
    for (final pt in _particles) {
      final pp = Paint()..color = pt.color.withValues(alpha: pt.life.clamp(0.0, 1.0));
      final s = t * pt.size;
      canvas.save();
      canvas.translate(sx(pt.x), sy(pt.y));
      if (pt.round) {
        canvas.drawCircle(Offset.zero, s / 2, pp);
      } else {
        canvas.rotate(pt.angle);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s, height: s), pp);
      }
      canvas.restore();
    }
    canvas.restore(); // shake

    // Death flash: a brief red vignette from the edges.
    if (_flash > 0) {
      final k = _flash / kFlashS;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, vh),
        Paint()
          ..shader = Gradient.radial(
            Offset(w / 2, vh / 2),
            math.max(w, vh) * 0.75,
            [Palette.spike.withValues(alpha: 0), Palette.spike.withValues(alpha: 0), Palette.spike.withValues(alpha: 0.28 * k)],
            [0, 0.45, 1],
          ),
      );
    }

    // Start hint.
    if (!_started) {
      final overlay = Paint()..color = const Color(0x66000000);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, vh), overlay);
    }
  }

  /// Eye blink: closed for ~90 ms roughly every 3.2 s (render-only).
  bool get _blink => (_clock % 3.2) > 3.11;

  static int _hash(int n) {
    var x = n * 0x45d9f3b;
    x = ((x >> 16) ^ x) * 0x45d9f3b;
    x = (x >> 16) ^ x;
    return x & 0x7fffffff;
  }

  void _drawSpike(Canvas canvas, double x0, double x1, double t, double base, double dir, Paint fill, Paint glow, Paint tip) {
    // dir −1 = points up from the floor, +1 = points down from the ceiling.
    final apex = base + dir * t * 0.78;
    final glowPath = Path()
      ..moveTo(x0 + t * 0.05, base)
      ..lineTo(x0 + t * 0.5, apex + dir * t * 0.10)
      ..lineTo(x1 - t * 0.05, base)
      ..close();
    canvas.drawPath(glowPath, glow);
    final path = Path()
      ..moveTo(x0 + t * 0.12, base)
      ..lineTo(x0 + t * 0.5, apex)
      ..lineTo(x1 - t * 0.12, base)
      ..close();
    canvas.drawPath(path, fill);
    // Lit left facet.
    final facet = Path()
      ..moveTo(x0 + t * 0.12, base)
      ..lineTo(x0 + t * 0.5, apex)
      ..lineTo(x0 + t * 0.5, base)
      ..close();
    canvas.drawPath(facet, Paint()..color = Palette.spikeTip.withValues(alpha: 0.16));
    canvas.drawCircle(Offset(x0 + t * 0.5, apex - dir * t * 0.06), t * 0.06, tip);
  }

  /// Player: a rounded square with two eyes looking forward. [squash] 0..1
  /// flattens it on landing; [stretch] 0..1 lengthens it in the air; [flip]
  /// 0..1 turns it over (from [fromSide]) after a gravity flip. Drawn with the
  /// given bottom-left world→screen.
  void _drawCreature(
    Canvas canvas,
    double x,
    double yBottom,
    double t,
    Side side,
    double squash,
    Color color, {
    bool ghost = false,
    double flip = 1,
    Side? fromSide,
    double stretch = 0,
    double vy = 0,
    bool blink = false,
    double scale = 1,
  }) {
    const pw = 0.8;
    const ph = 0.8;
    final sqW = (1 + squash * 0.25 - stretch * 0.12) * scale;
    final sqH = (1 - squash * 0.25 + stretch * 0.18) * scale;
    final w = pw * t * sqW;
    final h = ph * t * sqH;
    // Anchor to the surface the creature is on.
    final left = x - (w - pw * t) / 2;
    final top = side == Side.floor ? yBottom - h : yBottom - ph * t;
    final cx = left + w / 2;
    final cy = top + h / 2;

    // Turn-over: the body's vertical scale runs +1 → −1 relative to the side
    // it came from, so the eyes swing from one surface to the other.
    // Sign convention: "up" for the creature is away from its surface.
    final upNow = side == Side.floor ? -1.0 : 1.0; // screen-y direction of "up"
    double eyeDir = upNow;
    double bodyScaleY = 1;
    if (flip < 1 && fromSide != null && fromSide != side) {
      final c = math.cos(flip * math.pi); // 1 → −1
      bodyScaleY = c.abs().clamp(0.12, 1.0);
      eyeDir = c >= 0 ? -upNow : upNow;
    }

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(1, bodyScaleY);
    canvas.translate(-cx, -cy);

    final body = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), Radius.circular(t * 0.18));
    if (!ghost) {
      // Soft drop shadow towards the surface.
      canvas.drawRRect(body.shift(Offset(0, -upNow * t * 0.05)), Paint()..color = Palette.shadow.withValues(alpha: 0.35 * color.a));
    }
    canvas.drawRRect(body, Paint()..color = color);
    if (ghost) {
      canvas.restore();
      return;
    }
    // Belly shade on the surface side, highlight on the sky side.
    final bellyTop = upNow < 0 ? top + h * 0.7 : top;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, bellyTop, w, h * 0.3), Radius.circular(t * 0.14)), Paint()..color = Palette.playerDark.withValues(alpha: 0.5 * color.a));
    final glossTop = upNow < 0 ? top + h * 0.08 : top + h * 0.78;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left + w * 0.12, glossTop, w * 0.5, h * 0.14), Radius.circular(t * 0.1)),
      Paint()..color = Palette.spikeTip.withValues(alpha: 0.22 * color.a),
    );
    // Eyes: near the leading (right) edge, on the side away from the surface,
    // glancing up or down with vertical speed.
    final eyeY = (eyeDir < 0 ? top + h * 0.34 : top + h * 0.66) + (vy.clamp(-20, 20) / 20) * -upNow * h * 0.03;
    final eyeR = t * 0.11 * scale;
    for (final ex in [left + w * 0.52, left + w * 0.78]) {
      if (blink) {
        canvas.drawRect(Rect.fromCenter(center: Offset(ex, eyeY), width: eyeR * 2, height: math.max(1.5, eyeR * 0.35)), Paint()..color = Palette.eyeDark.withValues(alpha: color.a));
        continue;
      }
      canvas.drawCircle(Offset(ex, eyeY), eyeR, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: color.a));
      canvas.drawCircle(Offset(ex + eyeR * 0.35, eyeY + eyeDir * eyeR * 0.1), eyeR * 0.5, Paint()..color = Palette.eyeDark.withValues(alpha: color.a));
    }
    canvas.restore();
  }
}

/// Render-only tuning.
const double kFlipAnimS = 0.16;
const double kShakeS = 0.28;
const double kFlashS = 0.35;
const int kTrailLen = 5;

class _Trail {
  _Trail(this.x, this.y, this.side, this.life);
  final double x, y;
  final Side side;
  double life;
}

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.life, {this.size = 0.16, this.color = Palette.player, this.gravity = 30, this.drag = 0, this.spin = 0, this.round = false});
  double x, y, vx, vy, life;
  final double size;
  final Color color;
  final double gravity;
  final double drag;
  final double spin;
  final bool round;
  double angle = 0;
  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy -= gravity * dt;
    if (drag > 0) {
      vx -= vx * drag * dt;
      vy -= vy * drag * dt;
    }
    angle += spin * dt;
    life -= dt * 1.6;
  }
}

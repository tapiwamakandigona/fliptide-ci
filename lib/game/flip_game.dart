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
import '../sim/checkpoint.dart';
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
  FlipGame({required this.course, required this.listener, List<int> ghost = const [], List<int> autoFlips = const []})
      : _ghostFlips = ghost.toSet(),
        _autoFlips = autoFlips.toSet();

  final Course course;
  final FlipListener listener;
  final Set<int> _ghostFlips;

  /// Second-chance checkpoints of the current attempt (directive 02k).
  final CheckpointTracker checkpoints = CheckpointTracker();

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
    _ghost = _ghostFlips.isEmpty ? null : Sim(course);
    checkpoints.reset();
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

  /// Seconds since the current death (0 while alive).
  double get secondsSinceDeath => sim.s.state == RunState.dead ? _deathTimer : 0;

  /// Rewarded second chance: rewind the dead attempt to its deepest checkpoint.
  /// The attempt counter does not move — this is a resume, not a retry.
  bool resumeFromCheckpoint() {
    final cp = checkpoints.state;
    if (sim.s.state != RunState.dead || cp == null) return false;
    sim.resumeFrom(cp);
    _prev = sim.s.copy();
    _acc = 0;
    _tap = false;
    _deathTimer = 0;
    _squash = 0;
    _particles.clear();
    _deathAt = null; // not a restart: keep F3 timings honest
    _awaitingFirstStep = false;
    checkpoints.continueFrom(checkpoints.frac);
    // Ghost: rebuild and fast-forward to the same frame so it stays in sync.
    if (_ghostFlips.isNotEmpty) {
      final g = Sim(course);
      while (g.s.frame < sim.s.frame && g.s.state == RunState.running) {
        g.step(tap: _ghostFlips.contains(g.s.frame));
      }
      _ghost = g;
    }
    listener.onAttempt(attempts);
    return true;
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
    if (!_started) return;
    final clamped = math.min(dt, 0.1);
    for (final p in _particles) {
      p.update(clamped);
    }
    _particles.removeWhere((p) => p.life <= 0);
    _squash = math.max(0, _squash - clamped * 6);

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
      if (_awaitingFirstStep) {
        _awaitingFirstStep = false;
        restartMs.add(DateTime.now().difference(_deathAt!).inMilliseconds);
        _deathAt = null;
      }
      sim.step(tap: _tap || _autoFlips.contains(sim.s.frame));
      _tap = false;
      _ghost?.step(tap: _ghostFlips.contains(_ghost!.s.frame));
      if (!wasGrounded && sim.s.grounded) _squash = 1;
      checkpoints.observe(sim);
      if (sim.s.state == RunState.dead) {
        lastDeathX = sim.s.x;
        _deathAt = DateTime.now();
        _burst(sim.s);
        listener.onDeath(sim.progress, attempts, sim.s.cause);
        break;
      }
      if (sim.s.state == RunState.won) {
        listener.onWin(attempts, sim.s.frame);
        break;
      }
    }
    if (sim.s.state == RunState.running) listener.onProgress(sim.progress);
  }

  void _burst(SimState s) {
    final rnd = math.Random(s.frame);
    for (var i = 0; i < 18; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final sp = 4 + rnd.nextDouble() * 9;
      _particles.add(_Particle(s.x + 0.4, s.y + 0.4, math.cos(a) * sp, math.sin(a) * sp, 0.5 + rnd.nextDouble() * 0.4));
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
    double sx(double x) => (x - camX) * t;
    double sy(double y) => corridorTop + (h - y) * t; // world y up → screen down

    // Corridor interior.
    final interior = Rect.fromLTWH(0, corridorTop, w, h * t);
    canvas.drawRect(interior, Paint()..color = Palette.corridor);
    // Grid lines every tile (subtle, gives speed).
    final gridPaint = Paint()
      ..color = Palette.grid
      ..strokeWidth = 1;
    final firstCol = camX.floor();
    for (var cx = firstCol; cx <= firstCol + tilesAcross + 1; cx++) {
      final x = sx(cx.toDouble());
      canvas.drawLine(Offset(x, corridorTop), Offset(x, corridorTop + h * t), gridPaint);
    }

    // Slabs (outside the corridor) so floor/ceiling read as solid.
    final slab = Paint()..color = Palette.slab;
    canvas.drawRect(Rect.fromLTRB(0, 0, w, corridorTop), slab);
    canvas.drawRect(Rect.fromLTRB(0, corridorTop + h * t, w, vh), slab);
    final edge = Paint()
      ..color = Palette.slabEdge
      ..strokeWidth = math.max(2, t * 0.08);
    canvas.drawLine(Offset(0, corridorTop), Offset(w, corridorTop), edge);
    canvas.drawLine(Offset(0, corridorTop + h * t), Offset(w, corridorTop + h * t), edge);

    // Columns.
    final spikePaint = Paint()..color = Palette.spike;
    final tipPaint = Paint()..color = Palette.spikeTip;
    for (var cx = firstCol - 1; cx <= firstCol + tilesAcross + 2; cx++) {
      final col = course.at(cx);
      final x0 = sx(cx.toDouble());
      final x1 = x0 + t;
      if (cx < 0 || cx >= course.length) continue;
      if (col.isPit) {
        // Pit: darkness below the floor line.
        canvas.drawRect(Rect.fromLTRB(x0, sy(0), x1, vh), Paint()..color = Palette.bg);
      } else if (col.floorH > 0) {
        final r = Rect.fromLTRB(x0, sy(col.floorH.toDouble()), x1, sy(0));
        canvas.drawRect(r, slab);
        canvas.drawLine(r.topLeft, r.topRight, edge);
      }
      if (col.ceilH > 0) {
        final r = Rect.fromLTRB(x0, sy(h.toDouble()), x1, sy((h - col.ceilH).toDouble()));
        canvas.drawRect(r, slab);
        canvas.drawLine(r.bottomLeft, r.bottomRight, edge);
      }
      if (col.floorSpike && !col.isPit) {
        final base = sy(col.floorH.toDouble());
        final path = Path()
          ..moveTo(x0 + t * 0.12, base)
          ..lineTo(x0 + t * 0.5, base - t * 0.78)
          ..lineTo(x1 - t * 0.12, base)
          ..close();
        canvas.drawPath(path, spikePaint);
        canvas.drawCircle(Offset(x0 + t * 0.5, base - t * 0.72), t * 0.06, tipPaint);
      }
      if (col.ceilSpike) {
        final base = sy((h - col.ceilH).toDouble());
        final path = Path()
          ..moveTo(x0 + t * 0.12, base)
          ..lineTo(x0 + t * 0.5, base + t * 0.78)
          ..lineTo(x1 - t * 0.12, base)
          ..close();
        canvas.drawPath(path, spikePaint);
        canvas.drawCircle(Offset(x0 + t * 0.5, base + t * 0.72), t * 0.06, tipPaint);
      }
    }

    // Finish line.
    final fx = sx((course.length - kFinishColumns).toDouble());
    if (fx > -t && fx < w + t) {
      final fp = Paint()
        ..color = Palette.finish
        ..strokeWidth = math.max(3, t * 0.12);
      for (var i = 0; i < h * 2; i++) {
        if (i.isEven) {
          canvas.drawLine(Offset(fx, corridorTop + i * t / 2), Offset(fx, corridorTop + (i + 1) * t / 2), fp);
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

    // Player. On CLEARED it fades out over kWonFadeS so the overlay caption
    // never has the sprite drawn on top of it (directive 02j-3).
    if (sim.s.state != RunState.dead && playerAlpha > 0) {
      _drawCreature(canvas, sx(px), sy(py), t, sim.s.side, _squash, Palette.player.withValues(alpha: playerAlpha));
    }

    // Particles.
    for (final pt in _particles) {
      final pp = Paint()..color = Palette.player.withValues(alpha: pt.life.clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromCenter(center: Offset(sx(pt.x), sy(pt.y)), width: t * 0.16, height: t * 0.16), pp);
    }

    // Start hint.
    if (!_started) {
      final overlay = Paint()..color = const Color(0x66000000);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, vh), overlay);
    }
  }

  /// Player: a rounded square with two eyes looking forward. [squash] 0..1
  /// flattens it on landing. Drawn with the given bottom-left world→screen.
  void _drawCreature(Canvas canvas, double x, double yBottom, double t, Side side, double squash, Color color, {bool ghost = false}) {
    const pw = 0.8;
    const ph = 0.8;
    final sqW = 1 + squash * 0.25;
    final sqH = 1 - squash * 0.25;
    final w = pw * t * sqW;
    final h = ph * t * sqH;
    // Anchor to the surface the creature is on.
    final left = x - (w - pw * t) / 2;
    final top = side == Side.floor ? yBottom - h : yBottom - ph * t;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), Radius.circular(t * 0.18));
    canvas.drawRRect(body, Paint()..color = color);
    if (ghost) return;
    // Belly shade.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, top + h * 0.7, w, h * 0.3), Radius.circular(t * 0.14)),
      Paint()..color = Palette.playerDark.withValues(alpha: 0.5),
    );
    // Eyes: near the leading (right) edge, on the side away from the surface.
    final eyeY = side == Side.floor ? top + h * 0.34 : top + h * 0.66;
    final eyeR = t * 0.11;
    for (final ex in [left + w * 0.52, left + w * 0.78]) {
      canvas.drawCircle(Offset(ex, eyeY), eyeR, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(Offset(ex + eyeR * 0.35, eyeY), eyeR * 0.5, Paint()..color = const Color(0xFF1A1A2E));
    }
  }
}

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.life);
  double x, y, vx, vy, life;
  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy -= 30 * dt;
    life -= dt * 1.6;
  }
}

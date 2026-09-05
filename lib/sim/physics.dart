/// Deterministic fixed-step simulation. Pure Dart. The same code drives the
/// live game, the ghost, the solver and the tests, so a replay (a list of
/// flip frames) reproduces a run bit-for-bit.
library;

import 'course.dart';

/// Fixed simulation rate. The renderer interpolates; the sim never varies.
const int kSimHz = 120;
const double kDt = 1 / kSimHz;

class SimConfig {
  const SimConfig({
    this.gravity = 58,
    this.playerW = 0.8,
    this.playerH = 0.8,
    this.hitInset = 0.12,
    this.spikeHalfW = 0.22,
    this.spikeH = 0.62,
    this.inputBufferFrames = 12,
  });

  /// Tiles / s².
  final double gravity;
  final double playerW;
  final double playerH;

  /// Horizontal forgiveness on block side-hits (each side).
  final double hitInset;

  /// Spike hitbox half-width around the column centre; height from surface.
  final double spikeHalfW;
  final double spikeH;

  /// A tap up to this many sim frames before landing still counts.
  final int inputBufferFrames;

  static const standard = SimConfig();
}

enum Side { floor, ceiling }

enum RunState { running, dead, won }

enum DeathCause { none, blockSide, spike, pit }

class SimState {
  SimState({
    required this.x,
    required this.y,
    required this.vy,
    required this.side,
    required this.grounded,
    required this.frame,
    required this.state,
    required this.cause,
    required this.buffer,
  });

  factory SimState.start() => SimState(
        x: 1.0,
        y: 0,
        vy: 0,
        side: Side.floor,
        grounded: true,
        frame: 0,
        state: RunState.running,
        cause: DeathCause.none,
        buffer: 0,
      );

  /// Player left edge (tiles).
  double x;

  /// Player bottom edge (tiles), regardless of side.
  double y;
  double vy;
  Side side;
  bool grounded;
  int frame;
  RunState state;
  DeathCause cause;
  int buffer;

  SimState copy() => SimState(
        x: x,
        y: y,
        vy: vy,
        side: side,
        grounded: grounded,
        frame: frame,
        state: state,
        cause: cause,
        buffer: buffer,
      );

  /// Key for the solver's visited set — only meaningful when grounded.
  int groundedKey() => frame * 8 + (side == Side.floor ? 0 : 1) * 4 + (y * 1).round().clamp(0, 3);
}

class Sim {
  Sim(this.course, [this.cfg = SimConfig.standard]) : s = SimState.start();

  final Course course;
  final SimConfig cfg;
  SimState s;

  /// Flip frames of this run, in order — the replay.
  final List<int> flips = [];

  double get progress => (s.x / course.length).clamp(0.0, 1.0);

  int get totalFrames => (course.length / course.speed * kSimHz).ceil() + kSimHz;

  void reset() {
    s = SimState.start();
    flips.clear();
  }

  /// Advance one fixed step. [tap] = the player pressed this frame.
  void step({bool tap = false}) {
    if (s.state != RunState.running) return;
    final c = cfg;
    final h = course.height.toDouble();

    if (tap) s.buffer = c.inputBufferFrames;

    // 1. Flip (grounded only). Consumes the buffer.
    if (s.grounded && s.buffer > 0) {
      s.side = s.side == Side.floor ? Side.ceiling : Side.floor;
      s.grounded = false;
      s.vy = 0;
      s.buffer = 0;
      flips.add(s.frame);
    } else if (s.buffer > 0) {
      s.buffer--;
    }

    // 2. Horizontal.
    s.x += course.speed * kDt;

    // Columns the (inset) hitbox overlaps.
    final x0 = (s.x + c.hitInset).floor();
    final x1 = (s.x + c.playerW - c.hitInset).floor();

    // Surfaces across the overlapped columns.
    var floorTop = double.negativeInfinity; // highest floor
    var ceilBot = double.infinity; // lowest ceiling
    var anyPit = false;
    for (var cx = x0; cx <= x1; cx++) {
      final col = course.at(cx);
      if (col.isPit) {
        anyPit = true;
      } else if (col.floorTop > floorTop) {
        floorTop = col.floorTop;
      }
      final cb = col.ceilBottom(h);
      if (cb < ceilBot) ceilBot = cb;
    }
    if (floorTop == double.negativeInfinity) {
      floorTop = anyPit ? -100 : 0; // all pit
    }

    // 3. Vertical.
    if (s.grounded) {
      if (s.side == Side.floor) {
        if (floorTop < s.y - 1e-9) {
          // Walked off a ledge (or over a pit): fall.
          s.grounded = false;
        }
      } else {
        if (ceilBot > s.y + c.playerH + 1e-9) {
          s.grounded = false;
        }
      }
    }
    if (!s.grounded) {
      final g = s.side == Side.floor ? -c.gravity : c.gravity;
      s.vy += g * kDt;
      s.y += s.vy * kDt;
      if (s.side == Side.floor && s.y <= floorTop) {
        s.y = floorTop;
        s.vy = 0;
        s.grounded = true;
      } else if (s.side == Side.ceiling && s.y + c.playerH >= ceilBot) {
        s.y = ceilBot - c.playerH;
        s.vy = 0;
        s.grounded = true;
      }
    }

    // 4. Deaths.
    if (s.y < -1) {
      _die(DeathCause.pit);
      return;
    }
    // Block side-hit: any overlapped column whose solid intrudes into the box.
    for (var cx = x0; cx <= x1; cx++) {
      final col = course.at(cx);
      if (!col.isPit && col.floorTop > s.y + 1e-6) {
        _die(DeathCause.blockSide);
        return;
      }
      if (col.ceilBottom(h) < s.y + c.playerH - 1e-6) {
        _die(DeathCause.blockSide);
        return;
      }
    }
    // Spikes (full box vs spike hitbox).
    final bx0 = s.x;
    final bx1 = s.x + c.playerW;
    final by0 = s.y;
    final by1 = s.y + c.playerH;
    for (var cx = (bx0).floor(); cx <= (bx1).floor(); cx++) {
      final col = course.at(cx);
      final sx0 = cx + 0.5 - c.spikeHalfW;
      final sx1 = cx + 0.5 + c.spikeHalfW;
      if (bx1 <= sx0 || bx0 >= sx1) continue;
      if (col.floorSpike && !col.isPit) {
        final sy0 = col.floorTop;
        final sy1 = sy0 + c.spikeH;
        if (by1 > sy0 && by0 < sy1) {
          _die(DeathCause.spike);
          return;
        }
      }
      if (col.ceilSpike) {
        final sy1 = col.ceilBottom(h);
        final sy0 = sy1 - c.spikeH;
        if (by1 > sy0 && by0 < sy1) {
          _die(DeathCause.spike);
          return;
        }
      }
    }

    // 5. Win.
    if (s.x >= course.length - kFinishColumns) {
      s.state = RunState.won;
    }
    s.frame++;
  }

  void _die(DeathCause cause) {
    s.state = RunState.dead;
    s.cause = cause;
  }

  /// Replay a flip list from the start; returns the final state.
  static SimState replay(Course course, List<int> flipFrames, [SimConfig cfg = SimConfig.standard]) {
    final sim = Sim(course, cfg);
    final set = flipFrames.toSet();
    final limit = sim.totalFrames;
    while (sim.s.state == RunState.running && sim.s.frame < limit) {
      sim.step(tap: set.contains(sim.s.frame));
    }
    return sim.s;
  }
}

/// The finish pad is 8 columns; crossing into its second half wins.
const int kFinishColumns = 4;

/// THE percent rule. HUD, death overlay, share text and share card all use this
/// so one death never reads as two different numbers (owner directive 02h-2).
/// Floor: 0.049 → 4, 0.999 → 99, 1.0 → 100.
int percentOf(double progress) => (progress.clamp(0.0, 1.0) * 100).floor();

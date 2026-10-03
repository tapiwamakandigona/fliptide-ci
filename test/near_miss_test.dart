// Near misses (October 2026 pass, F-OCT-NEAR-MISS-20261003): flipping away
// from a hazard at the last moment and surviving earns a small burst of
// sparks and a glow pulse. Render-only — the sim never reads any of this.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fliptide/game/flip_game.dart';
import 'package:fliptide/game/gaze.dart';
import 'package:fliptide/sim/course.dart';
import 'package:fliptide/sim/physics.dart';

import 'support/recording_canvas.dart';

class _L implements FlipListener {
  bool dead = false;
  @override
  void onAttempt(int attempts) {}
  @override
  void onFlip() {}
  @override
  void onLand() {}
  @override
  void onDeath(double progress, int attempts, DeathCause cause) => dead = true;
  @override
  void onProgress(double progress) {}
  @override
  void onWin(int attempts, int frames) {}
}

Course withColumn(int at, Column hazard, {int length = 60}) {
  final cols = List<Column>.generate(length, (i) => i == at ? hazard : Column.flat);
  return Course(seed: 0, chunks: [Chunk('nm', 0, cols)], speed: 9);
}

/// Runs a game on [course]; flips once when the raw gaze alarm first reaches
/// [flipAt] (never if null). Returns (near misses, died).
Future<(int, bool)> run(Course course, {double? flipAt, int frames = 600}) async {
  final (game, l) = await start(course);
  _play(game, l, course, flipAt: flipAt, frames: frames);
  return (game.nearMisses, l.dead);
}

Future<(FlipGame, _L)> start(Course course) async {
  final l = _L();
  final game = FlipGame(course: course, listener: l);
  game.onGameResize(Vector2(390, 844));
  await game.onLoad();
  game.press(); // start
  return (game, l);
}

void _play(FlipGame game, _L l, Course course, {double? flipAt, int frames = 600}) {
  var flipped = false;
  for (var i = 0; i < frames && !l.dead; i++) {
    if (!flipped && flipAt != null && sparkGaze(course, game.sim.s.x, game.sim.s.side).alarm >= flipAt) {
      game.press();
      flipped = true;
    }
    game.update(1 / 60);
    final rec = ui.PictureRecorder();
    game.render(ui.Canvas(rec));
    rec.endRecording().dispose();
  }
}

void main() {
  test('sparkGaze reports which column it is looking at', () {
    final course = withColumn(10, const Column(floorSpike: true));
    expect(sparkGaze(course, 8.0, Side.floor).col, 10);
    expect(sparkGaze(course, 2.0, Side.floor).col, -1);
  });

  group('NearMissTracker', () {
    test('arms at high alarm and fires once when the back edge clears the hazard', () {
      final t = NearMissTracker();
      expect(t.step(const Gaze(0.5, GazeHazard.spike, 10), 8.0), isFalse);
      expect(t.armedCol, -1, reason: 'mild alarm does not arm');
      expect(t.step(const Gaze(0.9, GazeHazard.spike, 10), 9.0), isFalse);
      expect(t.armedCol, 10);
      expect(t.step(Gaze.calm, 10.5), isFalse, reason: 'still over the hazard');
      expect(t.step(Gaze.calm, 11.0), isTrue);
      expect(t.armedCol, -1);
      expect(t.step(Gaze.calm, 12.0), isFalse, reason: 'fires once');
    });

    test('a row of hazards is one near miss, counted from its first column', () {
      final t = NearMissTracker();
      t.step(const Gaze(0.85, GazeHazard.spike, 10), 9.0);
      t.step(const Gaze(0.95, GazeHazard.spike, 11), 10.0);
      expect(t.armedCol, 10);
      expect(t.step(Gaze.calm, 11.0), isTrue);
    });

    test('reset disarms', () {
      final t = NearMissTracker();
      t.step(const Gaze(0.9, GazeHazard.pit, 10), 9.0);
      t.reset();
      expect(t.armedCol, -1);
      expect(t.step(Gaze.calm, 20.0), isFalse);
    });
  });

  group('in a real game', () {
    test('a last-moment flip over a floor spike is a near miss', () async {
      final (n, died) = await run(withColumn(14, const Column(floorSpike: true)), flipAt: 0.7);
      expect(died, isFalse);
      expect(n, 1);
    });

    test('an early flip is not a near miss', () async {
      final (n, died) = await run(withColumn(14, const Column(floorSpike: true)), flipAt: 0.2);
      expect(died, isFalse);
      expect(n, 0);
    });

    test('running into the spike is a death, not a near miss', () async {
      final (n, died) = await run(withColumn(14, const Column(floorSpike: true)));
      expect(died, isTrue);
      expect(n, 0);
    });

    test('the count resets with each attempt', () async {
      final course = withColumn(14, const Column(floorSpike: true));
      final (game, l) = await start(course);
      _play(game, l, course, flipAt: 0.7);
      expect(l.dead, isFalse);
      expect(game.nearMisses, 1);
      game.retry(); // a new attempt
      expect(game.nearMisses, 0);
      _play(game, l, course, flipAt: 0.7);
      expect(l.dead, isFalse);
      expect(game.nearMisses, 1, reason: 'counted again in the new attempt');
    });
  });

  // Review follow-up (F-OCT-NEAR-MISS-EDGES-20261003).
  group('edge cases', () {
    test('a long spike row counts once, and only after the whole row is behind the spark', () async {
      // Floor spikes in columns 14..17: one row.
      final cols = List<Column>.generate(60, (i) => i >= 14 && i <= 17 ? const Column(floorSpike: true) : Column.flat);
      final course = Course(seed: 0, chunks: [Chunk('row', 0, cols)], speed: 9);
      final (game, l) = await start(course);
      var flipped = false;
      double? firedAt;
      for (var i = 0; i < 600 && !l.dead; i++) {
        if (!flipped && sparkGaze(course, game.sim.s.x, game.sim.s.side).alarm >= 0.7) {
          game.press();
          flipped = true;
        }
        final before = game.nearMisses;
        game.update(1 / 60);
        if (game.nearMisses > before) firedAt ??= game.sim.s.x;
      }
      expect(l.dead, isFalse);
      expect(game.nearMisses, 1, reason: 'a row counts once');
      expect(firedAt, isNotNull);
      expect(firedAt, greaterThanOrEqualTo(18.0), reason: 'fires once the back edge is past the last spike column (17), not the first');
    });

    /// Blocks one tall in columns 20..27; the spark goes to the ceiling early
    /// and then drops back so it lands on top of the block close to its left
    /// edge (back edge still over the flat column 19).
    Course blockRow() {
      final cols = List<Column>.generate(60, (i) => i >= 20 && i < 28 ? const Column(floorH: 1) : Column.flat);
      return Course(seed: 0, chunks: [Chunk('block', 0, cols)], speed: 9);
    }

    test('landing on top of a raised block near its edge is not a wall near miss', () async {
      final course = blockRow();
      // Find the drop-back flip that lands on the block top with the back
      // edge still over column 19 (pure sim search, deterministic).
      List<int>? flips;
      double landX = -1;
      for (var f2 = 60; f2 < 300 && flips == null; f2++) {
        final sim = Sim(course);
        while (sim.s.state == RunState.running && sim.s.x < 30) {
          final wasGrounded = sim.s.grounded;
          sim.step(tap: sim.s.frame == 10 || sim.s.frame == f2);
          if (sim.s.frame > f2 && !wasGrounded && sim.s.grounded && sim.s.side == Side.floor) {
            if (sim.s.y == 1 && sim.s.x >= 19.3 && sim.s.x < 19.6) {
              flips = [10, f2];
              landX = sim.s.x;
            }
            break;
          }
        }
      }
      expect(flips, isNotNull, reason: 'a drop-back flip that lands on the block edge exists');
      final l = _L();
      final game = FlipGame(course: course, listener: l, autoFlips: flips!);
      game.onGameResize(Vector2(390, 844));
      await game.onLoad();
      game.press();
      var stoodOnBlock = false;
      for (var i = 0; i < 600 && !l.dead && game.sim.s.state == RunState.running; i++) {
        game.update(1 / 60);
        if (game.sim.s.grounded && game.sim.s.side == Side.floor && game.sim.s.y == 1) stoodOnBlock = true;
        final rec = ui.PictureRecorder();
        game.render(ui.Canvas(rec));
        rec.endRecording().dispose();
      }
      expect(landX, lessThan(20.0));
      expect(stoodOnBlock, isTrue);
      expect(l.dead, isFalse);
      expect(game.nearMisses, 0, reason: 'standing or landing on a block is not escaping a wall');
    });

    test('sparkGaze reports where a row of hazards ends', () {
      final cols = List<Column>.generate(40, (i) => i >= 10 && i <= 13 ? const Column(floorSpike: true) : Column.flat);
      final course = Course(seed: 0, chunks: [Chunk('row', 0, cols)], speed: 9);
      final g = sparkGaze(course, 8.5, Side.floor);
      expect(g.col, 10);
      expect(g.endCol, 13);
      final single = withColumn(10, const Column(floorSpike: true));
      expect(sparkGaze(single, 8.5, Side.floor).endCol, 10, reason: 'a single hazard ends where it starts');
    });

    test('the tracker fires only once the back edge is past the end of the row', () {
      final t = NearMissTracker();
      t.step(const Gaze(0.9, GazeHazard.spike, 10, 13), 9.0);
      expect(t.armedCol, 10);
      expect(t.step(Gaze.calm, 11.0), isFalse, reason: 'still over the row');
      expect(t.step(Gaze.calm, 13.9), isFalse, reason: 'still over the last spike');
      expect(t.step(Gaze.calm, 14.0), isTrue);
      expect(t.step(Gaze.calm, 15.0), isFalse, reason: 'fires once');
    });

    test('a raised block is a wall only while the spark is below its top', () {
      final step = withColumn(10, const Column(floorH: 1));
      expect(sparkGaze(step, 9.3, Side.floor, y: 0).kind, GazeHazard.wall);
      expect(sparkGaze(step, 9.3, Side.floor, y: 1).kind, GazeHazard.none, reason: 'standing on it');
      expect(sparkGaze(step, 8.0, Side.floor, y: 3).kind, GazeHazard.none, reason: 'dropping onto it');
      final low = withColumn(10, const Column(ceilH: 1)); // ceiling bottom at 5
      expect(sparkGaze(low, 9.3, Side.ceiling, y: 5.2).kind, GazeHazard.wall);
      expect(sparkGaze(low, 9.3, Side.ceiling, y: 4.2).kind, GazeHazard.none, reason: 'hanging under it');
    });

    test('a wall the spark ends up standing on is disarmed; escaping to the other surface still fires', () {
      final t = NearMissTracker();
      t.step(const Gaze(0.95, GazeHazard.wall, 20, 27), 19.0, side: Side.floor);
      expect(t.armedCol, 20);
      expect(t.step(Gaze.calm, 19.45, side: Side.floor, grounded: true), isFalse);
      expect(t.armedCol, -1, reason: 'standing on top of the block it was alarmed about');
      expect(t.step(Gaze.calm, 28.0, side: Side.floor, grounded: true), isFalse);

      final u = NearMissTracker();
      u.step(const Gaze(0.95, GazeHazard.wall, 20, 27), 19.0, side: Side.floor);
      expect(u.step(Gaze.calm, 22.0, side: Side.ceiling, grounded: true), isFalse, reason: 'over the row, on the ceiling');
      expect(u.armedCol, 20);
      expect(u.step(Gaze.calm, 28.0, side: Side.ceiling, grounded: true), isTrue);
    });

    test('a checkpoint resume keeps the near-miss count of the attempt', () async {
      // Near miss over the floor spike at 14, checkpoint at 25 % on the
      // ceiling, then death on the ceiling spike at 34.
      final cols = List<Column>.generate(60, (i) {
        if (i == 14) return const Column(floorSpike: true);
        if (i == 34) return const Column(ceilSpike: true);
        return Column.flat;
      });
      final course = Course(seed: 0, chunks: [Chunk('cp', 0, cols)], speed: 9);
      final (game, l) = await start(course);
      _play(game, l, course, flipAt: 0.7);
      expect(l.dead, isTrue);
      expect(game.nearMisses, 1);
      expect(game.checkpoints.hasCheckpoint, isTrue);
      expect(game.resumeFromCheckpoint(), isTrue);
      expect(game.nearMisses, 1, reason: 'a resume is not a retry');
    });
  });

  // Review follow-up (F-OCT-WIN-FADE-EASE-20261003).
  group('win fade', () {
    test('the glow flare and the alarm keep easing while the sprite fades out', () async {
      // A near miss over the spike at 14 fires at x >= 15; the run is won at
      // x >= 16 (length 20 - kFinishColumns), so it ends mid-flare.
      final course = withColumn(14, const Column(floorSpike: true), length: 20);
      final (game, l) = await start(course);
      var flipped = false;
      for (var i = 0; i < 600 && game.sim.s.state == RunState.running; i++) {
        if (!flipped && sparkGaze(course, game.sim.s.x, game.sim.s.side).alarm >= 0.7) {
          game.press();
          flipped = true;
        }
        game.update(1 / 60);
      }
      expect(game.sim.s.state, RunState.won);
      expect(game.nearMisses, 1);
      // Frames of the fade: what is drawn, and the eased alarm.
      final flares = <double>[];
      final alarms = <double>[];
      while (game.playerAlpha > 0) {
        final rec = RecordingCanvas();
        game.render(rec);
        flares.add(glowFlare(rec));
        alarms.add(game.sparkAlarm);
        game.update(1 / 60);
      }
      expect(flares.length, greaterThanOrEqualTo(5), reason: 'the fade lasts kWonFadeS');
      expect(flares.first, greaterThan(0.3), reason: 'the run ended mid-flare');
      expect(alarms.first, greaterThan(0.05), reason: 'the eyes were still alarmed');
      for (var k = 1; k < flares.length; k++) {
        // Linear decay over kNearMissS (0.4 s), one 1/60 s step per frame.
        expect(flares[k], closeTo(flares[k - 1] - (1 / 60) / kNearMissS, 1e-6), reason: 'flare at fade frame $k');
        // Relaxing towards calm at rate 5, as when danger is behind.
        expect(alarms[k], closeTo(alarms[k - 1] * math.exp(-5 / 60), 1e-9), reason: 'alarm at fade frame $k');
      }
    });
  });
}

/// The glow flare drawn in [rec]: the glow is the shaded circle at the
/// origin; a flare scales the canvas by 1 + 0.6 * flare just before it.
double glowFlare(RecordingCanvas rec) {
  final calls = rec.calls;
  final i = calls.indexWhere((c) => c.name == 'drawCircle' && c.args[0] == ui.Offset.zero && c.shaded);
  expect(i, greaterThan(0), reason: 'glow drawn');
  for (var j = i - 1; j >= 0 && calls[j].name != 'save'; j--) {
    if (calls[j].name == 'scale') return ((calls[j].args[0] as double) - 1) / 0.6;
  }
  return 0;
}

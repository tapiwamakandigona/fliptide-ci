// Near misses (October 2026 pass, F-OCT-NEAR-MISS-20261003): flipping away
// from a hazard at the last moment and surviving earns a small burst of
// sparks and a glow pulse. Render-only — the sim never reads any of this.
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fliptide/game/flip_game.dart';
import 'package:fliptide/game/gaze.dart';
import 'package:fliptide/sim/course.dart';
import 'package:fliptide/sim/physics.dart';

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
}

// Additive regressions: rendering is read-only; trail timing is fixed-step.
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:fliptide/game/flip_game.dart';
import 'package:fliptide/sim/chunks.dart';
import 'package:fliptide/sim/course.dart';
import 'package:fliptide/sim/physics.dart';
import 'package:flutter_test/flutter_test.dart';

class SilentListener implements FlipListener {
  @override
  void onAttempt(int attempts) {}
  @override
  void onDeath(double progress, int attempts, DeathCause cause) {}
  @override
  void onProgress(double progress) {}
  @override
  void onWin(int attempts, int frames) {}
}

void renderFrame(FlipGame game) {
  final recorder = ui.PictureRecorder();
  game.render(ui.Canvas(recorder));
  recorder.endRecording().dispose();
}

Future<FlipGame> airborneGame(int hz) async {
  final game = FlipGame(
    course: Course(
      seed: 42,
      chunks: [kStart, kSpacers.first, kFinish],
      speed: 9,
    ),
    listener: SilentListener(),
  );
  game.onGameResize(Vector2(390, 844));
  await game.onLoad();
  game.press(); // Start, without flipping.
  game.press(); // First simulation step flips from the floor.
  for (var i = 0; i < hz ~/ 5; i++) {
    game.update(1 / hz);
    renderFrame(game);
  }
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repeated render calls do not mutate the trail or simulation', () async {
    final game = await airborneGame(60);
    expect(game.sim.s.grounded, isFalse);
    final before = game.debugTrailSnapshot;
    final frame = game.sim.s.frame;
    expect(before.length, kTrailLen);
    for (final sample in before) {
      expect(
        sample.$1,
        lessThanOrEqualTo(game.sim.s.x - game.course.speed * kDt + 1e-9),
      );
    }
    for (var i = 0; i < 8; i++) {
      renderFrame(game);
    }
    expect(game.debugTrailSnapshot, orderedEquals(before));
    expect(game.sim.s.frame, frame);
  });

  test(
    'same elapsed time gives the same bounded trail at 30/60/120 Hz',
    () async {
      final reference = await airborneGame(60);
      expect(reference.debugTrailSnapshot.length, kTrailLen);
      for (final hz in [30, 120]) {
        final game = await airborneGame(hz);
        expect(game.sim.s.frame, reference.sim.s.frame);
        expect(game.sim.flips, orderedEquals(reference.sim.flips));
        expect(
          game.debugTrailSnapshot,
          orderedEquals(reference.debugTrailSnapshot),
        );
        expect(game.debugTrailSnapshot.length, lessThanOrEqualTo(kTrailLen));
      }
    },
  );
}

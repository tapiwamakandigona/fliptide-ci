import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:fliptide/game/flip_game.dart';
import 'package:fliptide/sim/campaign.dart';
import 'package:fliptide/sim/physics.dart';
import 'package:flutter_test/flutter_test.dart';

class _L implements FlipListener {
  @override
  void onAttempt(int attempts) {}
  @override
  void onFlip() {}
  @override
  void onLand() {}
  @override
  void onDeath(double progress, int attempts, DeathCause cause) {}
  @override
  void onProgress(double progress) {}
  @override
  void onWin(int attempts, int frames) {}
}

void main() {
  test('render bench (VM, software canvas)', () async {
    final gen = kCampaign[7].buildCourse();
    final game = FlipGame(course: gen.course, listener: _L(), autoFlips: gen.solution.flips);
    game.onGameResize(Vector2(800, 400));
    await game.onLoad();
    game.press();
    // warm-up
    for (var i = 0; i < 60; i++) {
      game.update(1 / 60);
      final rec = ui.PictureRecorder();
      game.render(ui.Canvas(rec));
      rec.endRecording();
    }
    final sw = Stopwatch()..start();
    const frames = 600;
    for (var i = 0; i < frames; i++) {
      game.update(1 / 60);
      final rec = ui.PictureRecorder();
      game.render(ui.Canvas(rec));
      rec.endRecording().dispose();
    }
    sw.stop();
    // ignore: avoid_print
    print('BENCH render+update: ${sw.elapsedMicroseconds / frames} us/frame over $frames frames');
  });
}

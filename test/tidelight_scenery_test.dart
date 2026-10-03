// 0.4.1 "Tidelight": the sky/sea scenery outside the corridor is render-only
// and must degrade cleanly: full scene in phone portrait, nothing but the
// crust when the slabs are thin (landscape), and no exceptions over a run.
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fliptide/game/flip_game.dart';
import 'package:fliptide/game/scenery.dart';
import 'package:fliptide/sim/campaign.dart';
import 'package:fliptide/sim/physics.dart';

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

void _draw(
  Scenery s, {
  required double w,
  required double vh,
  required double t,
  required double top,
  required double bot,
  double camX = 0,
  double clock = 0,
}) {
  final rec = ui.PictureRecorder();
  s.render(
    ui.Canvas(rec),
    w: w,
    vh: vh,
    t: t,
    top: top,
    bot: bot,
    camX: camX,
    clock: clock,
  );
  rec.endRecording().dispose();
}

void main() {
  test('phone portrait: sky and sea both drawn, moon sits in the sky', () {
    final s = Scenery();
    _draw(s, w: 390, vh: 844, t: 390 / 9, top: 250, bot: 594);
    expect(s.hasSky, isTrue);
    expect(s.hasSea, isTrue);
    expect(s.moon.dy, inExclusiveRange(0, 250));
    expect(
      s.moon.dx,
      inExclusiveRange(390 * 0.5, 390),
    ); // away from the player column
  });

  test('thin slabs (landscape): scenery steps aside, crust only', () {
    final s = Scenery();
    _draw(s, w: 800, vh: 400, t: 800 / 15, top: 20, bot: 380);
    expect(s.hasSky, isFalse);
    expect(s.hasSea, isFalse);
  });

  test('scenery survives far camera positions and long clocks', () {
    final s = Scenery();
    for (final camX in [0.0, 13.7, 999.5, 123456.0]) {
      _draw(
        s,
        w: 390,
        vh: 844,
        t: 390 / 9,
        top: 250,
        bot: 594,
        camX: camX,
        clock: camX * 3,
      );
    }
    expect(s.hasSky, isTrue);
  });

  test(
    'full game renders 300 frames in portrait with the new scenery',
    () async {
      final gen = kCampaign[0].buildCourse();
      final game = FlipGame(
        course: gen.course,
        listener: _L(),
        autoFlips: gen.solution.flips,
      );
      game.onGameResize(Vector2(390, 844));
      await game.onLoad();
      game.press();
      for (var i = 0; i < 300; i++) {
        game.update(1 / 60);
        final rec = ui.PictureRecorder();
        game.render(ui.Canvas(rec));
        rec.endRecording().dispose();
      }
    },
  );
}

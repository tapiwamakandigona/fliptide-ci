// 0.4.1 "Tidelight": the sky/sea scenery outside the corridor is render-only
// and must degrade cleanly: full scene in phone portrait, nothing but the
// crust when the slabs are thin (landscape), and no exceptions over a run.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fliptide/game/flip_game.dart';
import 'package:fliptide/game/scenery.dart';
import 'package:fliptide/sim/campaign.dart';
import 'package:fliptide/sim/physics.dart';

import 'support/recording_canvas.dart';

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

  test('zero-size viewport (hidden embed): no exception, then recovers', () {
    final s = Scenery();
    _draw(s, w: 0, vh: 800, t: 0, top: 0, bot: 800);
    _draw(s, w: 0, vh: 0, t: 0, top: 0, bot: 0);
    expect(s.hasSky, isFalse);
    expect(s.hasSea, isFalse);
    _draw(s, w: 390, vh: 844, t: 390 / 9, top: 250, bot: 594);
    expect(s.hasSky, isTrue);
    expect(s.hasSea, isTrue);
  });

  test('full game survives a zero-size viewport and a resize back', () async {
    final gen = kCampaign[0].buildCourse();
    final game = FlipGame(
      course: gen.course,
      listener: _L(),
      autoFlips: gen.solution.flips,
    );
    game.onGameResize(Vector2.zero());
    await game.onLoad();
    game.press();
    void frame() {
      game.update(1 / 60);
      final rec = ui.PictureRecorder();
      game.render(ui.Canvas(rec));
      rec.endRecording().dispose();
    }

    for (var i = 0; i < 10; i++) {
      frame();
    }
    game.onGameResize(Vector2(390, 844));
    for (var i = 0; i < 10; i++) {
      frame();
    }
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

  // Review follow-up (F-OCT-SCENERY-NO-ALLOC-20261003): scenery render
  // builds nothing per frame, so the same state hands the canvas the very
  // same objects every time.
  test(
    'the same state renders with identical canvas arguments (nothing built per frame)',
    () {
      final s = Scenery();
      List<CanvasCall> frame(double camX, double clock) {
        final rec = RecordingCanvas();
        s.render(
          rec,
          w: 390,
          vh: 844,
          t: 390 / 9,
          top: 250,
          bot: 594,
          camX: camX,
          clock: clock,
        );
        return rec.calls;
      }

      void expectSameObjects(List<CanvasCall> a, List<CanvasCall> b) {
        expect(b.map((c) => c.name).toList(), a.map((c) => c.name).toList());
        final rebuilt = <String>[];
        for (var i = 0; i < a.length; i++) {
          for (var j = 0; j < a[i].args.length; j++) {
            final x = a[i].args[j];
            if (x == null || x is num || x is bool || x is Enum) continue;
            if (!identical(x, b[i].args[j])) {
              rebuilt.add('call $i ${a[i].name} arg $j ${x.runtimeType}');
            }
          }
        }
        expect(
          rebuilt,
          isEmpty,
          reason: 'objects built again for the same state',
        );
      }

      // Lighthouse on screen (camX 0) and both twinkle buckets in use.
      final first = frame(0, 1.25);
      expect(first.where((c) => c.name == 'drawRawPoints'), isNotEmpty);
      expectSameObjects(first, frame(0, 1.25));
      // Other frames in between do not change what the same state uses.
      for (var i = 1; i <= 20; i++) {
        frame(i * 0.37, 1.25 + i / 60);
      }
      expectSameObjects(first, frame(0, 1.25));
      final far = frame(731.4, 88.8);
      expectSameObjects(far, frame(731.4, 88.8));
    },
  );

  test(
    'the scenery render path builds no lists, views, rects, offsets, paints or paths',
    () {
      final src = File('lib/game/scenery.dart').readAsStringSync();
      final start = src.indexOf('  void render(');
      expect(start, greaterThan(0));
      // render() and everything after it (the per-frame helpers).
      final body = src.substring(start);
      final found = <String>[
        for (final p in [
          RegExp(r'sublistView\('),
          RegExp(r'Rect\.from'),
          RegExp(r'Offset\('),
          RegExp(r'Paint\(\)'),
          RegExp(r'Path\(\)'),
          RegExp(r'(\bin|=|\(|,)\s*\['), // a list literal
        ])
          for (final m in p.allMatches(body)) m[0]!,
      ];
      expect(found, isEmpty);
    },
  );
}

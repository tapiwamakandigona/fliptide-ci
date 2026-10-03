// What the spark's face, the near-miss burst and the glow flare actually
// draw (F-OCT-SPARK-DRAWING-TESTS-20261003). Real runs, rendered into a
// recording canvas, so these pin the pixels' geometry rather than the
// internal state that feeds them.
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fliptide/game/flip_game.dart';
import 'package:fliptide/game/gaze.dart';
import 'package:fliptide/game/palette.dart';
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

/// Flat corridor with one floor spike at column 14.
Course spikeAt14() {
  final cols = List<Column>.generate(
    60,
    (i) => i == 14 ? const Column(floorSpike: true) : Column.flat,
  );
  return Course(seed: 0, chunks: [Chunk('draw', 0, cols)], speed: 9);
}

Future<(FlipGame, _L)> start(Course course) async {
  final l = _L();
  final game = FlipGame(course: course, listener: l);
  game.onGameResize(Vector2(390, 844));
  await game.onLoad();
  game.press(); // start
  return (game, l);
}

RecordingCanvas draw(FlipGame game) {
  final rec = RecordingCanvas();
  game.render(rec);
  return rec;
}

int rgb(ui.Color c) => c.toARGB32() & 0xFFFFFF;

/// One frame of the player's face as drawn.
class Face {
  Face(this.alarm, this.eyeR, this.pupilDx, this.pupilDy, this.mouth);
  final double alarm;
  final double eyeR;
  final double pupilDx;
  final double pupilDy;

  /// The mouth oval, or null when none was drawn.
  final ui.Rect? mouth;
}

/// Reads the face from [rec]: eye whites are the opaque white circles, the
/// pupils and the mouth use the opaque eye-dark colour. Null while blinking.
Face? faceOf(RecordingCanvas rec, double alarm) {
  final whites = [
    for (final c in rec.named('drawCircle'))
      if (c.color?.toARGB32() == 0xFFFFFFFF) c,
  ];
  final pupils = [
    for (final c in rec.named('drawCircle'))
      if (c.color?.toARGB32() == Palette.eyeDark.toARGB32()) c,
  ];
  if (whites.isEmpty) return null;
  expect(whites.length, 2, reason: 'two eyes');
  expect(pupils.length, 2, reason: 'two pupils');
  final w = whites.first.args[0] as ui.Offset;
  final p = pupils.first.args[0] as ui.Offset;
  final mouths = [
    for (final c in rec.named('drawOval'))
      if (c.color?.toARGB32() == Palette.eyeDark.toARGB32())
        c.args[0] as ui.Rect,
  ];
  expect(mouths.length, lessThanOrEqualTo(1));
  return Face(
    alarm,
    whites.first.args[1] as double,
    p.dx - w.dx,
    p.dy - w.dy,
    mouths.isEmpty ? null : mouths.first,
  );
}

/// The glow flare drawn in [rec]: the glow is the shaded circle at the
/// origin, and a flare scales the canvas by 1 + 0.6 * flare just before it.
double flareOf(RecordingCanvas rec) {
  final calls = rec.calls;
  final i = calls.indexWhere(
    (c) => c.name == 'drawCircle' && c.args[0] == ui.Offset.zero && c.shaded,
  );
  expect(i, greaterThan(0), reason: 'glow drawn');
  for (var j = i - 1; j >= 0 && calls[j].name != 'save'; j--) {
    if (calls[j].name == 'scale') {
      return ((calls[j].args[0] as double) - 1) / 0.6;
    }
  }
  return 0;
}

/// Screen-x of the glow centre (the spark's centre) in [rec].
double glowX(RecordingCanvas rec) {
  final calls = rec.calls;
  final i = calls.indexWhere(
    (c) => c.name == 'drawCircle' && c.args[0] == ui.Offset.zero && c.shaded,
  );
  for (var j = i - 1; j >= 0; j--) {
    if (calls[j].name == 'translate') return calls[j].args[0] as double;
  }
  fail('no translate before the glow');
}

/// Screen-x of every near-miss burst spark in [rec]: round particles (a
/// circle at the origin after a translate) in the spark's or the spike-tip
/// colour. Dust is a different colour and the glow is shaded.
List<double> burstXs(RecordingCanvas rec) {
  final calls = rec.calls;
  final xs = <double>[];
  for (var i = 1; i < calls.length; i++) {
    final c = calls[i];
    if (c.name != 'drawCircle' || c.args[0] != ui.Offset.zero || c.shaded) {
      continue;
    }
    final k = rgb(c.color!);
    if (k != rgb(Palette.player) && k != rgb(Palette.spikeTip)) continue;
    expect(calls[i - 1].name, 'translate');
    xs.add(calls[i - 1].args[0] as double);
  }
  return xs;
}

bool near(double a, double b, [double tol = 1e-9]) => (a - b).abs() <= tol;

void main() {
  const t = 390 / 9; // portrait: 9 tiles across

  // Each test below makes ONE assertion: the list of mismatches is empty.
  // (Seen failing once against a deliberately broken renderer; see
  // progress.md, 2026-10-03, review findings 4.)

  group('the alarmed face', () {
    // Run straight at the spike (no flip) and read every frame's face.
    late List<Face> faces;
    setUpAll(() async {
      final (game, l) = await start(spikeAt14());
      faces = [];
      for (var i = 0; i < 600 && !l.dead; i++) {
        game.update(1 / 60);
        if (l.dead) break;
        final f = faceOf(draw(game), game.sparkAlarm);
        if (f != null) faces.add(f);
      }
      expect(l.dead, isTrue);
    });

    test('the sweep covers calm, alarmed and open-mouthed frames', () {
      expect([
        if (!(faces.first.alarm < 0.05))
          'first frame not calm: ${faces.first.alarm}',
        if (!(faces.last.alarm > 0.8))
          'last frame not alarmed: ${faces.last.alarm}',
        if (!faces.any((f) => f.alarm > 0.6)) 'no frame above 0.6',
      ], isEmpty);
    });

    test('eye size: t*0.11 when calm, up to +28 % as the alarm rises', () {
      expect([
        for (final f in faces)
          if (!near(f.eyeR, t * 0.11 * (1 + 0.28 * f.alarm)))
            'alarm ${f.alarm}: r ${f.eyeR}',
        if (!near(faces.first.eyeR, t * 0.11, t * 0.11 * 0.02))
          'calm r ${faces.first.eyeR}',
        if (!(faces.last.eyeR > t * 0.11 * 1.2)) 'alarmed r ${faces.last.eyeR}',
      ], isEmpty);
    });

    test('pupils slide forward with the alarm', () {
      expect([
        for (final f in faces)
          if (!near(f.pupilDx, f.eyeR * (0.35 + 0.12 * f.alarm)))
            'alarm ${f.alarm}: dx ${f.pupilDx}',
        if (!(faces.last.pupilDx > faces.first.pupilDx * 1.3))
          'dx ${faces.first.pupilDx} -> ${faces.last.pupilDx}',
      ], isEmpty);
    });

    test('pupils drop towards the spike on the floor with the alarm', () {
      // Screen y grows downwards: calm pupils sit a little up (-0.1 r); an
      // alarm about a floor spike pulls them down by 0.3 r * alarm.
      expect([
        for (final f in faces)
          if (!near(f.pupilDy, f.eyeR * (0.3 * f.alarm - 0.1)))
            'alarm ${f.alarm}: dy ${f.pupilDy}',
        if (!(faces.first.pupilDy < 0)) 'calm dy ${faces.first.pupilDy}',
        if (!(faces.last.pupilDy > 0)) 'alarmed dy ${faces.last.pupilDy}',
      ], isEmpty);
    });

    test('the "o" mouth opens only above alarm 0.55 and grows with it', () {
      final open = faces.where((f) => f.mouth != null).toList();
      expect([
        for (final f in faces)
          if (f.alarm <= 0.55 && f.mouth != null)
            'alarm ${f.alarm}: mouth drawn'
          else if (f.alarm > 0.55 && f.mouth == null)
            'alarm ${f.alarm}: no mouth'
          else if (f.mouth != null &&
              !(near(f.mouth!.height, t * 0.12 * (f.alarm - 0.55) / 0.45) &&
                  near(
                    f.mouth!.width,
                    t * 0.1 * (0.6 + 0.4 * (f.alarm - 0.55) / 0.45),
                  )))
            'alarm ${f.alarm}: mouth ${f.mouth!.size}',
        if (open.length < 2)
          'only ${open.length} open frames'
        else if (!(open.last.mouth!.height > open.first.mouth!.height))
          'mouth does not grow',
      ], isEmpty);
    });
  });

  group('a near miss', () {
    // Flip late over the spike; record from the near-miss frame on.
    late List<RecordingCanvas> after;
    setUpAll(() async {
      final course = spikeAt14();
      final (game, l) = await start(course);
      var flipped = false;
      after = [];
      for (var i = 0; i < 600 && !l.dead && after.length < 40; i++) {
        final s = game.sim.s;
        if (!flipped && sparkGaze(course, s.x, s.side).alarm >= 0.7) {
          game.press();
          flipped = true;
        }
        game.update(1 / 60);
        if (game.nearMisses == 1) after.add(draw(game));
      }
      expect(l.dead, isFalse);
      expect(game.nearMisses, 1);
      expect(after.length, 40);
    });

    test('bursts exactly 16 round sparks', () {
      expect(burstXs(after.first).length, 16);
    });

    test('the burst streams back behind the spark', () {
      final back = glowX(after[6]) - 0.4 * t; // the spark's back edge
      final xs = burstXs(after[6]);
      expect([
        if (xs.length != 16) '${xs.length} sparks',
        for (final x in xs)
          if (!(x < back - 0.5 * t))
            'spark at ${x - back} px from the back edge',
      ], isEmpty);
    });

    test('the glow flares to 1.6x and settles linearly within 0.4 s', () {
      final flares = [for (final r in after) flareOf(r)];
      // 1/60 s per frame: the 0.4 s flare lasts 24 frames; frame 24 is
      // 0.4 s to float precision, and from then on nothing flares.
      expect([
        for (var k = 0; k < 24; k++)
          if (!near(flares[k], 1 - k / 24, 1e-6)) 'frame $k: ${flares[k]}',
        for (var k = 24; k < flares.length; k++)
          if (!near(flares[k], 0)) 'frame $k: ${flares[k]} after 0.4 s',
        if (flares.last != 0) 'still flaring at frame ${flares.length - 1}',
      ], isEmpty);
    });
  });
}

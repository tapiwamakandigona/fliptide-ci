// The spark watches the danger (October 2026 pass, F-OCT-SPARK-GAZE-20261003).
//
// sparkGaze() is a pure, render-only read of the course: what hazard is ahead
// on the surface the spark runs on, and how alarmed it should look.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:fliptide/game/flip_game.dart';
import 'package:fliptide/game/gaze.dart';
import 'package:fliptide/sim/campaign.dart';
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

/// A course whose column [at] is [hazard]; everything else is flat floor.
Course withColumn(int at, Column hazard, {int length = 40}) {
  final cols = List<Column>.generate(length, (i) => i == at ? hazard : Column.flat);
  return Course(seed: 0, chunks: [Chunk('gaze', 0, cols)], speed: 9);
}

void main() {
  group('sparkGaze', () {
    test('nothing ahead: no alarm', () {
      final course = withColumn(39, Column.flat);
      final g = sparkGaze(course, 5.0, Side.floor);
      expect(g.alarm, 0);
      expect(g.kind, GazeHazard.none);
    });

    test('a floor spike ahead alarms a spark on the floor, more as it closes in', () {
      final course = withColumn(10, const Column(floorSpike: true));
      // Front edge = x + 0.8. Far (beyond 4 columns) → calm.
      expect(sparkGaze(course, 4.0, Side.floor).alarm, 0);
      final far = sparkGaze(course, 6.7, Side.floor); // front 7.5 → 2.5 cols
      final near = sparkGaze(course, 8.7, Side.floor); // front 9.5 → 0.5 cols
      expect(far.kind, GazeHazard.spike);
      expect(far.alarm, greaterThan(0));
      expect(near.alarm, greaterThan(far.alarm));
      expect(near.alarm, lessThanOrEqualTo(1));
      // Front edge inside the spike column → full alarm.
      expect(sparkGaze(course, 9.5, Side.floor).alarm, 1);
    });

    test('hazards on the other surface do not alarm', () {
      final floorSpike = withColumn(10, const Column(floorSpike: true));
      expect(sparkGaze(floorSpike, 8.0, Side.ceiling).alarm, 0);
      final ceilSpike = withColumn(10, const Column(ceilSpike: true));
      expect(sparkGaze(ceilSpike, 8.0, Side.floor).alarm, 0);
      final g = sparkGaze(ceilSpike, 8.0, Side.ceiling);
      expect(g.kind, GazeHazard.spike);
      expect(g.alarm, greaterThan(0));
    });

    test('pits and raised walls on the running surface count', () {
      final pit = withColumn(10, const Column(floorH: kPit));
      expect(sparkGaze(pit, 8.0, Side.floor).kind, GazeHazard.pit);
      expect(sparkGaze(pit, 8.0, Side.floor).alarm, greaterThan(0));
      final step = withColumn(10, const Column(floorH: 2));
      expect(sparkGaze(step, 8.0, Side.floor).kind, GazeHazard.wall);
      final lowCeil = withColumn(10, const Column(ceilH: 2));
      expect(sparkGaze(lowCeil, 8.0, Side.ceiling).kind, GazeHazard.wall);
      expect(sparkGaze(lowCeil, 8.0, Side.floor).alarm, 0);
    });

    test('safe past the end of the course and before its start', () {
      final course = withColumn(10, const Column(floorSpike: true), length: 12);
      expect(sparkGaze(course, 30.0, Side.floor).alarm, 0);
      expect(sparkGaze(course, -3.0, Side.floor).alarm, 0);
    });

    test('deterministic: same input, same answer', () {
      final course = withColumn(10, const Column(floorSpike: true));
      final a = sparkGaze(course, 7.3, Side.floor);
      final b = sparkGaze(course, 7.3, Side.floor);
      expect(a.alarm, b.alarm);
      expect(a.kind, b.kind);
    });
  });

  test('the creature draw path allocates no Paint objects per call', () {
    final src = File('lib/game/flip_game.dart').readAsStringSync();
    final start = src.indexOf('void _drawCreature(');
    expect(start, greaterThan(0));
    // The method ends at its closing brace at class-member indent.
    final rest = src.substring(start);
    final end = rest.indexOf('\n  }\n');
    expect(end, greaterThan(0));
    final body = rest.substring(0, end);
    expect(RegExp(r'Paint\(\)').allMatches(body).length, 0);
  });

  test('in a real run the spark is calm at the start and alarmed before it hits the first spikes', () async {
    final gen = kCampaign[0].buildCourse();
    final l = _L();
    final game = FlipGame(course: gen.course, listener: l);
    game.onGameResize(Vector2(390, 844));
    await game.onLoad();
    game.press();
    var maxAlarm = 0.0;
    double? first;
    for (var i = 0; i < 1200 && !l.dead; i++) {
      game.update(1 / 60);
      first ??= game.sparkAlarm;
      if (!l.dead) maxAlarm = game.sparkAlarm > maxAlarm ? game.sparkAlarm : maxAlarm;
      final rec = ui.PictureRecorder();
      game.render(ui.Canvas(rec));
      rec.endRecording().dispose();
    }
    expect(l.dead, isTrue, reason: 'no input: the run ends on the first hazard');
    expect(first, lessThan(0.05));
    expect(maxAlarm, greaterThan(0.8));
  });
}

import 'package:fliptide/sim/chunks.dart';
import 'package:fliptide/sim/course.dart';
import 'package:fliptide/sim/generator.dart';
import 'package:fliptide/sim/physics.dart';
import 'package:fliptide/sim/solver.dart';
import 'package:flutter_test/flutter_test.dart';

Course single(Chunk c) => Course(seed: 0, chunks: [kStart, kSpacers.first, c, kSpacers.first, kFinish], speed: 9);

void main() {
  group('chunk library', () {
    for (final c in kChunks) {
      test('${c.name} (tier ${c.tier}) is solvable with spacers', () {
        final res = solve(single(c));
        expect(res.solvable, isTrue, reason: '${c.name} unsolvable; furthest ${res.furthestX.toStringAsFixed(1)} of ${single(c).length}');
      });
      test('${c.name} threatens at least one idle line (floor or ceiling)', () {
        if (c.tier == 0) return;
        final onFloor = Sim.replay(single(c), const []);
        final onCeiling = Sim.replay(single(c), const [0]); // flip once at the start pad
        expect(onFloor.state == RunState.dead || onCeiling.state == RunState.dead, isTrue,
            reason: '${c.name} can be passed idle on both floor and ceiling');
      });
    }
    test('every chunk has at least one hazard', () {
      for (final c in kChunks) {
        expect(c.columns.any((k) => k.floorH != 0 || k.ceilH != 0 || k.floorSpike || k.ceilSpike), isTrue, reason: c.name);
      }
    });
  });

  group('determinism', () {
    test('replaying the solver solution reproduces the win frame', () {
      final g = generate(const GenSpec(seed: 42));
      final a = Sim.replay(g.course, g.solution.flips);
      final b = Sim.replay(g.course, g.solution.flips);
      expect(a.state, RunState.won);
      expect(a.frame, b.frame);
      expect(a.frame, g.solution.frames);
      expect(a.x, b.x);
    });
    test('same seed → identical course, different seed → different course', () {
      final a = generate(const GenSpec(seed: 7)).course;
      final b = generate(const GenSpec(seed: 7)).course;
      final c = generate(const GenSpec(seed: 8)).course;
      expect(a.chunks.map((e) => e.name).toList(), b.chunks.map((e) => e.name).toList());
      expect(a.chunks.map((e) => e.name).toList(), isNot(c.chunks.map((e) => e.name).toList()));
    });
    test('20 consecutive daily seeds all generate solvable courses', () {
      for (var i = 0; i < 20; i++) {
        final day = DateTime.utc(2026, 9, 1).add(Duration(days: i));
        final g = generate(GenSpec(seed: dailySeed(day)));
        expect(g.course.length, greaterThan(100), reason: 'day $i collapsed to fallback');
        expect(Sim.replay(g.course, g.solution.flips).state, RunState.won);
      }
    });
    test('F1: every daily seed of 2026 generates a solvable course (365-day sweep)', () {
      var rerolls = 0;
      var fallbacks = 0;
      for (var i = 0; i < 365; i++) {
        final day = DateTime.utc(2026, 1, 1).add(Duration(days: i));
        final g = generate(GenSpec(seed: dailySeed(day)));
        rerolls += g.rerolls;
        if (g.course.length < 100) fallbacks++;
        expect(Sim.replay(g.course, g.solution.flips).state, RunState.won, reason: 'day $i');
      }
      expect(fallbacks, 0, reason: 'flat-fallback courses issued');
      // Tuning signal, not a gate: how often the solver had to swap a chunk.
      // ignore: avoid_print
      print('365-day sweep: total chunk rerolls = $rerolls');
    });
    test('daily is keyed to the UTC day, not the local day (02e/02f reproducibility)', () {
      // 2026-09-02 23:30 in UTC-5 is 2026-09-03 04:30Z → must be Daily #246, same as any 03Z instant.
      final utcA = DateTime.utc(2026, 9, 3, 4, 30);
      final utcB = DateTime.utc(2026, 9, 3, 23, 59, 59);
      expect(dailyNumber(utcA), 246);
      expect(dailyNumber(utcA), dailyNumber(utcB));
      expect(dailySeed(utcA), dailySeed(utcB));
      expect(dailyNumber(DateTime.utc(2026, 9, 2, 23, 59, 59)), 245);
      // A non-UTC DateTime for the same instant gives the same daily.
      final sameInstantLocal = utcA.toLocal();
      expect(sameInstantLocal.isUtc, isFalse);
      expect(dailySeed(sameInstantLocal), dailySeed(utcA));
      expect(dailyNumber(sameInstantLocal), dailyNumber(utcA));
    });
    test('design constants pinned (DEMAND 02h / PROJECT.md)', () {
      expect(kSimHz, 120);
      expect(SimConfig.standard.inputBufferFrames, 12);
      expect(SimConfig.standard.gravity, 58);
    });
    test('daily seeds are distinct day to day', () {
      final seeds = {for (var i = 0; i < 365; i++) dailySeed(DateTime.utc(2026, 1, 1).add(Duration(days: i)))};
      expect(seeds.length, 365);
    });
  });

  group('physics feel', () {
    test('a flip from floor to ceiling on an open corridor lands within 4.5 tiles', () {
      final course = Course(seed: 0, chunks: [kStart, kSpacers[1], kSpacers[1], kFinish], speed: 9);
      final sim = Sim(course);
      sim.step(tap: true);
      final x0 = sim.s.x;
      while (!sim.s.grounded) {
        sim.step();
      }
      expect(sim.s.side, Side.ceiling);
      expect(sim.s.x - x0, lessThan(4.5));
      expect(sim.s.x - x0, greaterThan(2.5));
    });
    test('input buffered before landing fires on landing', () {
      final course = Course(seed: 0, chunks: [kStart, kSpacers[1], kSpacers[1], kSpacers[1], kFinish], speed: 9);
      final sim = Sim(course);
      sim.step(tap: true);
      // Tap again mid-air, a few frames before landing.
      while (!sim.s.grounded) {
        sim.step(tap: sim.s.vy > 0 && sim.s.y > 4.9);
      }
      final landFrame = sim.s.frame;
      sim.step();
      expect(sim.flips.length, 2, reason: 'buffered tap should flip on landing');
      expect(sim.flips.last - landFrame, lessThanOrEqualTo(1));
    });
    test('walking into a raised block dies with blockSide', () {
      final end = Sim.replay(single(chunkByName('step_up')!), const []);
      expect(end.cause, DeathCause.blockSide);
    });
    test('running over a pit without flipping dies in the pit', () {
      final end = Sim.replay(single(chunkByName('pit_short')!), const []);
      expect(end.cause, DeathCause.pit);
    });
  });
}

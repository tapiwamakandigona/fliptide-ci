import 'package:fliptide/sim/campaign.dart';
import 'package:fliptide/sim/chunks.dart';
import 'package:fliptide/sim/course.dart';
import 'package:fliptide/sim/physics.dart';
import 'package:fliptide/sim/solver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flat corridor whose middle chunk's bottom row is [bottomRow]; a single `o`
/// there drops one floor pad on otherwise empty ground.
Course _flatWith(String bottomRow, {double speed = 9}) {
  final empty = '.' * bottomRow.length;
  final mid = Chunk.parse('probe', 1, [empty, empty, empty, empty, empty, bottomRow]);
  return Course(
    seed: 0,
    chunks: [kStart, kSpacers.first, mid, kSpacers[1], kSpacers[1], kFinish],
    speed: speed,
  );
}

({SimState end, List<int> flips}) _runIdle(Course c) {
  final sim = Sim(c);
  final limit = sim.totalFrames;
  while (sim.s.state == RunState.running && sim.s.frame < limit) {
    sim.step();
  }
  return (end: sim.s, flips: List<int>.from(sim.flips));
}

void main() {
  group('gravity pad — parsing', () {
    test('`o` marks a floor pad and adds no block or spike', () {
      final c = Chunk.parse('p', 1, const ['....', '....', '....', '....', '....', '.o..']);
      expect(c.columns[1].pad, isTrue);
      expect(c.columns[0].pad, isFalse);
      expect(const Column().pad, isFalse);
      expect(c.columns[1].floorH, 0);
      expect(c.columns[1].floorSpike, isFalse);
    });

    test('a pad stacked on a block parses as raised floor + pad', () {
      final c = Chunk.parse('rp', 1, const ['......', '......', '......', '......', '.o....', '.#....']);
      expect(c.columns[1].floorH, 1);
      expect(c.columns[1].pad, isTrue);
    });
  });

  group('gravity pad — behaviour', () {
    test('running idle over a floor pad auto-flips the player to the ceiling', () {
      final r = _runIdle(_flatWith('......o.....'));
      expect(r.flips, isNotEmpty, reason: 'a pad must flip gravity with zero taps');
      expect(r.end.side, Side.ceiling);
      expect(r.end.state, RunState.won);
    });

    test('the identical corridor without a pad never flips (control)', () {
      final r = _runIdle(_flatWith('............'));
      expect(r.flips, isEmpty);
      expect(r.end.side, Side.floor);
      expect(r.end.state, RunState.won);
    });

    test('a pad run is deterministic (same flips, same finish frame)', () {
      final a = _runIdle(_flatWith('......o.....'));
      final b = _runIdle(_flatWith('......o.....'));
      expect(a.flips, b.flips);
      expect(a.end.frame, b.end.frame);
    });

    // Regression for the surface bug: a FLOOR pad must NOT trigger while the
    // player is grounded on the CEILING.
    test('a floor pad does nothing while the player runs the ceiling', () {
      final sim = Sim(_flatWith('..........o.........'));
      final limit = sim.totalFrames;
      sim.step(tap: true); // flip to the ceiling immediately
      while (sim.s.state == RunState.running && sim.s.frame < limit) {
        sim.step();
      }
      expect(sim.s.side, Side.ceiling, reason: 'the floor pad wrongly flipped the ceiling runner');
      expect(sim.flips.length, 1, reason: 'only the manual tap; the floor pad must not add a flip');
      expect(sim.s.state, RunState.won);
    });

    test('a pad over a pit never fires (no floor to launch from)', () {
      const pit = Column(floorH: kPit, pad: true);
      expect(pit.isPit, isTrue);
      expect(pit.pad, isTrue);
      final cols = <Column>[
        ...List.filled(4, Column.flat),
        pit, pit, pit,
        ...List.filled(6, Column.flat),
      ];
      final r = _runIdle(Course(seed: 0, chunks: [kStart, kSpacers.first, Chunk('pitpad', 1, cols), kSpacers[1], kFinish], speed: 9));
      expect(r.flips, isEmpty);
      expect(r.end.state, RunState.dead);
      expect(r.end.cause, DeathCause.pit);
    });

    test('a pad on a raised floor fires when grounded on that floor', () {
      final cols = List<Column>.generate(40, (i) => i == 20 ? const Column(floorH: 1, pad: true) : const Column(floorH: 1));
      final sim = Sim(Course(seed: 0, chunks: [Chunk('plateau', 1, cols)], speed: 9));
      sim.s = SimState(x: 19.5, y: 1, vy: 0, side: Side.floor, grounded: true, frame: 0, state: RunState.running, cause: DeathCause.none, buffer: 0);
      sim.step();
      expect(sim.flips, isNotEmpty);
      expect(sim.s.side, Side.ceiling);
    });
  });

  group('gravity pad — integration', () {
    test('a pad lifts the player over a floor spike that kills the control run', () {
      final withPad = _runIdle(_flatWith('...o........^...'));
      expect(withPad.end.state, RunState.won, reason: 'the pad should carry the player above the spike');
      final control = _runIdle(_flatWith('............^...'));
      expect(control.end.state, RunState.dead);
      expect(control.end.cause, DeathCause.spike);
    });

    test('a recorded pad run replays bit-for-bit', () {
      final c = _flatWith('......o.....');
      final live = _runIdle(c);
      final rep = Sim.replay(c, live.flips);
      expect(rep.state, live.end.state);
      expect(rep.frame, live.end.frame);
      expect(rep.x, live.end.x);
      expect(rep.side, live.end.side);
    });

    test('the solver finds and the replay wins a pad course', () {
      final c = _flatWith('......o.....');
      final res = solve(c);
      expect(res.solvable, isTrue);
      expect(Sim.replay(c, res.solution!.flips).state, RunState.won);
    });

    test('the shipped campaign level t1l7 actually contains a reachable pad', () {
      final lvl = levelById('t1l7');
      expect(lvl, isNotNull);
      expect(lvl!.isAuthored, isTrue);
      final gen = lvl.buildCourse();
      expect(gen.course.columns.any((c) => c.pad), isTrue, reason: 'the level ships with a pad');
      expect(Sim.replay(gen.course, gen.solution.flips).state, RunState.won);
    });
  });
}

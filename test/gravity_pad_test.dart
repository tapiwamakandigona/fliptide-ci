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

  group('gravity pad — surface contact', () {
    test('a lower pad the runner only overlaps from a higher floor does not fire', () {
      final cols = List<Column>.generate(40, (i) {
        if (i == 20) return const Column(floorH: 0, pad: true);
        if (i < 20) return const Column(floorH: 1);
        return const Column();
      });
      final sim = Sim(Course(seed: 0, chunks: [Chunk('ledge', 1, cols)], speed: 9));
      sim.s = SimState(x: 19.5, y: 1, vy: 0, side: Side.floor, grounded: true, frame: 0, state: RunState.running, cause: DeathCause.none, buffer: 0);
      sim.step();
      expect(sim.flips, isEmpty, reason: 'feet are on column 19 (floorTop 1), not on the pad at floorTop 0');
      expect(sim.s.side, Side.floor);
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
      _expectSameState(rep, live.end);
    });

    test('a tap on the same frame as a pad yields one flip, identical to the pad alone', () {
      final c = _flatWith('......o.....');
      final padOnly = _runIdle(c);
      final first = padOnly.flips.first;
      final sim = Sim(c);
      while (sim.s.state == RunState.running && sim.s.frame < sim.totalFrames) {
        sim.step(tap: sim.s.frame == first);
      }
      expect(sim.flips, padOnly.flips);
      _expectSameState(sim.s, padOnly.end);
      _expectSameState(Sim.replay(c, sim.flips), sim.s);
    });

    test('a tap buffered mid-air before landing on a pad produces a deterministic replayable run', () {
      final c = _flatWith('......o.....');
      final sim = Sim(c);
      var tapped = false;
      while (sim.s.state == RunState.running && sim.s.frame < sim.totalFrames) {
        final tap = !tapped && sim.flips.isNotEmpty && !sim.s.grounded;
        if (tap) tapped = true;
        sim.step(tap: tap);
      }
      expect(tapped, isTrue);
      _expectSameState(Sim.replay(c, sim.flips), sim.s);
      for (var i = 1; i < sim.flips.length; i++) {
        expect(sim.flips[i], greaterThan(sim.flips[i - 1]), reason: 'never two flips in one frame');
      }
    });

    test('the solver finds and the replay wins a pad course', () {
      final c = _flatWith('......o.....');
      final res = solve(c);
      expect(res.solvable, isTrue);
      expect(Sim.replay(c, res.solution!.flips).state, RunState.won);
    });

  });
}

void _expectSameState(SimState a, SimState b) {
  expect(a.x, b.x);
  expect(a.y, b.y);
  expect(a.vy, b.vy);
  expect(a.side, b.side);
  expect(a.grounded, b.grounded);
  expect(a.frame, b.frame);
  expect(a.state, b.state);
  expect(a.cause, b.cause);
  expect(a.buffer, b.buffer);
}

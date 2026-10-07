import 'package:fliptide/sim/chunks.dart';
import 'package:fliptide/sim/course.dart';
import 'package:fliptide/sim/physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a flat course whose middle chunk's bottom row is [bottomRow], so a
/// single `o` there drops one gravity pad on an otherwise empty corridor.
Course _course(String bottomRow) {
  final rows = <String>[
    '............',
    '............',
    '............',
    '............',
    '............',
    bottomRow,
  ];
  final mid = Chunk.parse('pad_probe', 1, rows);
  return Course(
    seed: 0,
    chunks: [kStart, kSpacers.first, mid, kSpacers[1], kSpacers[1], kFinish],
    speed: 9,
  );
}

/// Runs the course with no taps at all and returns the final state; any flips
/// that happened (there should only be auto-flips from pads) land in [flips].
SimState _runIdle(Course course, List<int> flips) {
  final sim = Sim(course);
  final limit = sim.totalFrames;
  while (sim.s.state == RunState.running && sim.s.frame < limit) {
    sim.step();
  }
  flips.addAll(sim.flips);
  return sim.s;
}

void main() {
  group('gravity pad (auto-flip)', () {
    test('`o` marks a floor pad and adds no block or spike', () {
      final c = Chunk.parse('p', 1, const [
        '....',
        '....',
        '....',
        '....',
        '....',
        '.o..',
      ]);
      expect(c.columns[1].pad, isTrue);
      expect(c.columns[0].pad, isFalse);
      expect(const Column().pad, isFalse);
      expect(c.columns[1].floorH, 0);
      expect(c.columns[1].floorSpike, isFalse);
    });

    test('running idle over a pad auto-flips the player to the ceiling', () {
      final flips = <int>[];
      final end = _runIdle(_course('......o.....'), flips);
      expect(flips, isNotEmpty, reason: 'a pad must flip gravity with zero taps');
      expect(end.side, Side.ceiling);
      expect(end.state, RunState.won);
    });

    test('the identical corridor without a pad never flips (control)', () {
      final flips = <int>[];
      final end = _runIdle(_course('............'), flips);
      expect(flips, isEmpty);
      expect(end.side, Side.floor);
      expect(end.state, RunState.won);
    });

    test('a pad run is deterministic (same flips, same finish frame)', () {
      final a = <int>[];
      final b = <int>[];
      final ea = _runIdle(_course('......o.....'), a);
      final eb = _runIdle(_course('......o.....'), b);
      expect(a, b);
      expect(ea.frame, eb.frame);
    });
  });
}

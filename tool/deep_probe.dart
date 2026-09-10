// ignore_for_file: avoid_print
import 'package:fliptide/sim/deep.dart';
import 'package:fliptide/sim/physics.dart';

void main() {
  final sw = Stopwatch()..start();
  for (final seed in [1, 2, 3, 12345, 99999]) {
    final t0 = sw.elapsedMilliseconds;
    final g = generateDeep(seed);
    final t1 = sw.elapsedMilliseconds;
    // replay the solution to prove it wins
    final sim = Sim(g.course);
    final flips = g.solution.flips.toSet();
    while (sim.s.state == RunState.running) {
      sim.step(tap: flips.contains(sim.s.frame));
    }
    print('seed $seed: len=${g.course.length} rerolls=${g.rerolls} flips=${g.solution.flips.length} gen=${t1 - t0}ms replay=${sim.s.state} depth=${deepMetres(sim.s.x, g.course)}');
  }
}

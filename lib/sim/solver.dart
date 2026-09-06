/// Breadth-first search over flip decisions. Because a flip is only possible
/// while grounded, the only decision points are grounded frames, so the state
/// space is tiny: (frame, side, surface height).
library;

import 'course.dart';
import 'physics.dart';

class Solution {
  const Solution({required this.flips, required this.frames});
  final List<int> flips;
  final int frames;
}

class SolveResult {
  const SolveResult({required this.solution, required this.furthestX, required this.explored});
  final Solution? solution;

  /// Furthest x any branch reached before dying — where the course breaks.
  final double furthestX;
  final int explored;
  bool get solvable => solution != null;
}

class _Node {
  _Node(this.sim, this.flips);
  final Sim sim;
  final List<int> flips;
}

SolveResult solve(Course course, {SimConfig cfg = SimConfig.standard, int maxNodes = 200000}) {
  final start = Sim(course, cfg);
  var frontier = <_Node>[_Node(start, const [])];
  final visited = <int>{};
  var furthest = 0.0;
  var explored = 0;
  final limit = start.totalFrames;

  // Advance a node with no taps until it is grounded (a decision point),
  // dead, or won.
  void coast(_Node n) {
    while (n.sim.s.state == RunState.running && !n.sim.s.grounded && n.sim.s.frame < limit) {
      n.sim.step();
    }
  }

  coast(frontier.first);
  while (frontier.isNotEmpty && explored < maxNodes) {
    final next = <_Node>[];
    for (final n in frontier) {
      explored++;
      final st = n.sim.s;
      if (st.x > furthest) furthest = st.x;
      if (st.state == RunState.won) {
        return SolveResult(solution: Solution(flips: n.flips, frames: st.frame), furthestX: st.x, explored: explored);
      }
      if (st.state != RunState.running || st.frame >= limit) continue;
      final key = st.groundedKey();
      if (!visited.add(key)) continue;

      // Branch A: flip now.
      final a = Sim(course, cfg)..s = st.copy();
      a.step(tap: true);
      final aFlips = [...n.flips, st.frame];
      final an = _Node(a, aFlips);
      coast(an);
      next.add(an);

      // Branch B: keep running one frame.
      final b = Sim(course, cfg)..s = st.copy();
      b.step();
      final bn = _Node(b, n.flips);
      coast(bn);
      next.add(bn);
    }
    // Process in frame order so the first win found is the earliest.
    next.sort((p, q) => p.sim.s.frame.compareTo(q.sim.s.frame));
    frontier = next;
  }
  return SolveResult(solution: null, furthestX: furthest, explored: explored);
}

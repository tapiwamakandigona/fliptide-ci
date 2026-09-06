/// Checkpoints for the rewarded "second chance" (directive 02k rule 2).
///
/// Markers sit at 25 / 50 / 75 % of the course. The first grounded sim frame at
/// or past a marker is snapshotted; a second chance resumes from the deepest
/// snapshot of the attempt that just died. Pure Dart, deterministic.
library;

import 'physics.dart';

const List<double> kCheckpointFracs = [0.25, 0.5, 0.75];

class CheckpointTracker {
  SimState? state;
  double frac = 0;
  int _next = 0;

  bool get hasCheckpoint => state != null;

  void reset() {
    state = null;
    frac = 0;
    _next = 0;
  }

  /// Call after every sim step while running.
  void observe(Sim sim) {
    if (_next >= kCheckpointFracs.length) return;
    if (sim.s.state != RunState.running || !sim.s.grounded) return;
    if (sim.progress < kCheckpointFracs[_next]) return;
    state = sim.s.copy();
    frac = kCheckpointFracs[_next];
    _next++;
  }

  /// After a resume the tracker continues from the marker just used.
  void continueFrom(double usedFrac) {
    _next = kCheckpointFracs.indexOf(usedFrac) + 1;
  }
}

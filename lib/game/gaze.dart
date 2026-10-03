/// Where the spark is looking (render-only).
///
/// A pure read of the course: the nearest hazard ahead on the surface the
/// spark is running on, and how alarmed it should look about it. The sim never
/// sees this; it only drives the eyes and mouth in the renderer, so courses,
/// codes, ghosts and replays are untouched.
library;

import '../sim/course.dart';
import '../sim/physics.dart';

/// What the spark is looking at.
enum GazeHazard { none, spike, pit, wall }

class Gaze {
  const Gaze(this.alarm, this.kind, [this.col = -1]);

  /// 0 = calm, 1 = the hazard is at the spark's front edge.
  final double alarm;
  final GazeHazard kind;

  /// Course column of the hazard, or -1 when calm.
  final int col;

  static const calm = Gaze(0, GazeHazard.none);
}

/// Player body width in tiles (matches the sim's collision box).
const double kSparkWidth = 0.8;

/// How many columns ahead the spark notices danger.
const int kGazeLookAhead = 4;

/// The nearest hazard on [side] whose column starts within [kGazeLookAhead]
/// columns of the spark's front edge (`x + kSparkWidth`, tiles).
Gaze sparkGaze(Course course, double x, Side side) {
  final front = x + kSparkWidth;
  final c0 = front.floor();
  final here = course.at(x.floor());
  for (var c = c0; c < c0 + kGazeLookAhead + 1; c++) {
    if (c < 0 || c >= course.length) continue;
    final kind = _hazard(course.at(c), here, side);
    if (kind == GazeHazard.none) continue;
    final d = (c - front).clamp(0.0, kGazeLookAhead.toDouble());
    final alarm = 1 - d / kGazeLookAhead;
    if (alarm <= 0) return Gaze.calm;
    return Gaze(alarm, kind, c);
  }
  return Gaze.calm;
}

GazeHazard _hazard(Column col, Column here, Side side) {
  if (side == Side.floor) {
    if (col.floorSpike) return GazeHazard.spike;
    if (col.isPit) return GazeHazard.pit;
    if (!here.isPit && col.floorH > here.floorH) return GazeHazard.wall;
  } else {
    if (col.ceilSpike) return GazeHazard.spike;
    if (col.ceilH > here.ceilH) return GazeHazard.wall;
  }
  return GazeHazard.none;
}

/// Near misses: the spark was alarmed about a hazard (it was about to hit it)
/// and got past it alive. Fed once per frame while running; reports `true`
/// on the frame the spark's back edge clears the armed hazard column. A row
/// of hazards counts once, from its first column. Render-only.
class NearMissTracker {
  /// Alarm at which a hazard counts as "about to hit": about 1.4 columns, or
  /// ~0.15 s at Tide 1 speed — later than this the flip often cannot clear a
  /// spike at all.
  static const double threshold = 0.65;

  int _col = -1;

  /// The hazard column being watched, or -1.
  int get armedCol => _col;

  void reset() => _col = -1;

  bool step(Gaze gaze, double x) {
    if (_col < 0 && gaze.alarm >= threshold && gaze.col >= 0) _col = gaze.col;
    if (_col >= 0 && x >= _col + 1) {
      _col = -1;
      return true;
    }
    return false;
  }
}

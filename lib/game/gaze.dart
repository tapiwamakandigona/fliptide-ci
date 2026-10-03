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
  const Gaze(this.alarm, this.kind, [this.col = -1, int? endCol])
    : endCol = endCol ?? col;

  /// 0 = calm, 1 = the hazard is at the spark's front edge.
  final double alarm;
  final GazeHazard kind;

  /// Course column of the hazard, or -1 when calm.
  final int col;

  /// Last column of the row of hazards that starts at [col] (the contiguous
  /// run of hazard columns on the same surface); [col] for a single hazard.
  final int endCol;

  static const calm = Gaze(0, GazeHazard.none);
}

/// Player body width in tiles (matches the sim's collision box).
const double kSparkWidth = 0.8;

/// Player body height in tiles (matches the sim's collision box).
const double kSparkHeight = 0.8;

/// How many columns ahead the spark notices danger.
const int kGazeLookAhead = 4;

/// The nearest hazard on [side] whose column starts within [kGazeLookAhead]
/// columns of the spark's front edge (`x + kSparkWidth`, tiles).
///
/// [y] is the spark's bottom edge (tiles, as in the sim). When given, a
/// raised block counts as a wall only while the spark's body is below its
/// top (floor) or above its underside (ceiling): a block the spark stands on,
/// or is dropping onto, is not a wall in its way.
Gaze sparkGaze(Course course, double x, Side side, {double? y}) {
  final front = x + kSparkWidth;
  final c0 = front.floor();
  final here = course.at(x.floor());
  for (var c = c0; c < c0 + kGazeLookAhead + 1; c++) {
    if (c < 0 || c >= course.length) continue;
    final kind = _hazard(course, course.at(c), here, side, y);
    if (kind == GazeHazard.none) continue;
    final d = (c - front).clamp(0.0, kGazeLookAhead.toDouble());
    final alarm = 1 - d / kGazeLookAhead;
    if (alarm <= 0) return Gaze.calm;
    // The row: every hazard column on this surface right after this one.
    var end = c;
    while (end + 1 < course.length &&
        _hazard(course, course.at(end + 1), here, side, y) != GazeHazard.none) {
      end++;
    }
    return Gaze(alarm, kind, c, end);
  }
  return Gaze.calm;
}

GazeHazard _hazard(
  Course course,
  Column col,
  Column here,
  Side side,
  double? y,
) {
  if (side == Side.floor) {
    if (col.floorSpike) return GazeHazard.spike;
    if (col.isPit) return GazeHazard.pit;
    if (!here.isPit &&
        col.floorH > here.floorH &&
        (y == null || col.floorTop > y + 1e-6)) {
      return GazeHazard.wall;
    }
  } else {
    if (col.ceilSpike) return GazeHazard.spike;
    if (col.ceilH > here.ceilH &&
        (y == null ||
            col.ceilBottom(course.height.toDouble()) <
                y + kSparkHeight - 1e-6)) {
      return GazeHazard.wall;
    }
  }
  return GazeHazard.none;
}

/// Near misses: the spark was alarmed about a hazard (it was about to hit it)
/// and got past it alive. Fed once per frame while running; reports `true`
/// on the frame the spark's back edge clears the armed hazard's whole row
/// (up to its last column, [Gaze.endCol]), so a row counts once and only
/// once it is fully behind the spark. Render-only.
class NearMissTracker {
  /// Alarm at which a hazard counts as "about to hit": about 1.4 columns, or
  /// ~0.15 s at Tide 1 speed — later than this the flip often cannot clear a
  /// spike at all.
  static const double threshold = 0.65;

  int _col = -1;
  int _end = -1;
  GazeHazard _kind = GazeHazard.none;
  Side? _side;

  /// The hazard column being watched, or -1.
  int get armedCol => _col;

  void reset() {
    _col = _end = -1;
    _kind = GazeHazard.none;
    _side = null;
  }

  /// [side] and [grounded] describe the spark this frame. A spark standing
  /// on the surface it was alarmed about while overlapping the armed wall's
  /// columns can only be on top of that wall (a side hit is a death), so it
  /// climbed onto the block rather than escaping it: no near miss.
  bool step(Gaze gaze, double x, {Side? side, bool grounded = false}) {
    if (_col < 0 && gaze.alarm >= threshold && gaze.col >= 0) {
      _col = gaze.col;
      _end = gaze.endCol;
      _kind = gaze.kind;
      _side = side;
    }
    if (_col < 0) return false;
    if (_kind == GazeHazard.wall && grounded && side != null && side == _side) {
      const cfg = SimConfig.standard;
      final x0 = (x + cfg.hitInset).floor();
      final x1 = (x + cfg.playerW - cfg.hitInset).floor();
      if (x1 >= _col && x0 <= _end) {
        reset();
        return false;
      }
    }
    if (x >= _end + 1) {
      reset();
      return true;
    }
    return false;
  }
}

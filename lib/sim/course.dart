/// Course geometry: a corridor of integer-width columns between a floor
/// (y = 0) and a ceiling (y = [Course.height]). Pure Dart, no Flutter.
library;

/// Sentinel: this column has no floor (a pit). Falling below y = -1 kills.
const int kPit = -1;

class Column {
  const Column({
    this.floorH = 0,
    this.ceilH = 0,
    this.floorSpike = false,
    this.ceilSpike = false,
  });

  /// Blocks stacked on the floor (0..2) or [kPit].
  final int floorH;

  /// Blocks hanging from the ceiling (0..2).
  final int ceilH;
  final bool floorSpike;
  final bool ceilSpike;

  bool get isPit => floorH == kPit;

  /// Y of the walkable floor surface (only valid when not a pit).
  double get floorTop => floorH.toDouble();

  /// Y of the ceiling surface the player hangs from.
  double ceilBottom(double height) => height - ceilH;

  static const flat = Column();
}

/// A named, hand-authored piece of corridor.
class Chunk {
  const Chunk(this.name, this.tier, this.columns);
  final String name;

  /// 0 = spacer, 1 = easy, 2 = medium, 3 = hard, 4 = brutal.
  final int tier;
  final List<Column> columns;
  int get width => columns.length;

  /// Parse a grid of [height] rows (top row is the ceiling side) into columns.
  ///
  /// Glyphs: `#` block, `^` spike standing on the floor surface (or on floor
  /// blocks), `v` spike hanging from the ceiling surface, `_` pit (only
  /// meaningful in the bottom row), `.` empty.
  factory Chunk.parse(String name, int tier, List<String> rows) {
    final h = rows.length;
    final w = rows.first.length;
    for (final r in rows) {
      if (r.length != w) {
        throw ArgumentError('chunk $name: ragged rows');
      }
    }
    final cols = <Column>[];
    for (var x = 0; x < w; x++) {
      var floorH = 0;
      var ceilH = 0;
      var floorSpike = false;
      var ceilSpike = false;
      // rows[h-1] is y in [0,1) — the bottom row.
      if (rows[h - 1][x] == '_') {
        floorH = kPit;
      } else {
        // Floor blocks stack from the bottom.
        var y = 0;
        while (y < h && rows[h - 1 - y][x] == '#') {
          floorH++;
          y++;
        }
        if (y < h && rows[h - 1 - y][x] == '^') floorSpike = true;
      }
      // Ceiling blocks stack from the top.
      var y = 0;
      while (y < h && rows[y][x] == '#') {
        ceilH++;
        y++;
      }
      if (y < h && rows[y][x] == 'v') ceilSpike = true;
      if (floorH > 2 || ceilH > 2) {
        throw ArgumentError('chunk $name col $x: max 2 blocks per side');
      }
      cols.add(Column(
        floorH: floorH,
        ceilH: ceilH,
        floorSpike: floorSpike,
        ceilSpike: ceilSpike,
      ));
    }
    return Chunk(name, tier, cols);
  }
}

/// A full course: the concatenation of chunks, with a finish line.
class Course {
  Course({
    required this.seed,
    required this.chunks,
    required this.speed,
    this.height = 6,
  }) : columns = List.unmodifiable(chunks.expand((c) => c.columns));

  final int seed;
  final List<Chunk> chunks;
  final List<Column> columns;

  /// Corridor interior height in tiles.
  final int height;

  /// Horizontal run speed in tiles / second.
  final double speed;

  int get length => columns.length;

  Column at(int x) {
    if (x < 0) return Column.flat;
    if (x >= columns.length) return Column.flat;
    return columns[x];
  }

  /// World x where each chunk starts (for the share-card map and debugging).
  List<int> get chunkStarts {
    final out = <int>[];
    var x = 0;
    for (final c in chunks) {
      out.add(x);
      x += c.width;
    }
    return out;
  }
}

/// The Deep — Fliptide's endless mode.
///
/// One long corridor whose hazards get harder the further you get. Unlike a
/// Daily or a Tide, there is no finish to reach in practice: the score is the
/// depth (columns survived, shown as metres). The run is built from the same
/// frozen chunk pool as everything else, in [kDeepSegmentColumns]-wide
/// segments whose tier weights ramp from Shallows-easy to Maelstrom-hard, so
/// the first 40 m teach and the last 400 m punish.
///
/// Every dive has its own seed; the same seed always yields the same corridor
/// (deterministic, so a depth can be replayed or shared as a course code in a
/// later version). Pure Dart, no Flutter imports.
library;

import 'dart:math';

import 'chunks.dart';
import 'course.dart';
import 'course_code.dart';
import 'generator.dart';
import 'solver.dart';

/// Columns per difficulty segment.
const int kDeepSegmentColumns = 48;

/// Total corridor length. At speed 9 this is ~2.5 minutes of perfect play —
/// far beyond the depth a human reaches; reaching the gate is the secret
/// ending ("You touched the bottom").
const int kDeepColumns = 1320;

/// Deep runs are a touch slower than the Riptide/Maelstrom tides so the
/// ramp, not raw speed, is what kills you.
const double kDeepSpeed = 9.0;

/// Tier weights by segment index. Later segments reuse the last entry.
const List<Map<int, int>> kDeepRamp = [
  {1: 1},
  {1: 3, 2: 1},
  {1: 2, 2: 2},
  {1: 1, 2: 3, 3: 1},
  {1: 1, 2: 2, 3: 2},
  {2: 2, 3: 3, 4: 1},
  {2: 1, 3: 3, 4: 2},
  {3: 3, 4: 3},
];

/// Store key space for The Deep's in-memory attempt record (never persisted
/// per corridor). Far from Daily numbers (positive), code keys (−packed) and
/// campaign keys (near −2^31).
const int kDeepRecordKey = -(1 << 30) - 7;

/// One corridor column ≈ one metre. Depth is the furthest column the
/// creature's leading edge passed, clamped to the corridor.
int deepMetres(double x, Course course) =>
    x.clamp(0, course.length.toDouble()).floor();

/// Build a solvable Deep corridor for [seed].
GeneratedCourse generateDeep(int seed) {
  final rng = Random(seed);
  final pool = [
    for (final n in kVersionPools[kGeneratorVersion]!) chunkByName(n)!,
  ];

  List<Chunk> weightedFor(int segment) {
    final weights = kDeepRamp[segment.clamp(0, kDeepRamp.length - 1)];
    final out = <Chunk>[];
    for (final c in pool) {
      for (var i = 0; i < (weights[c.tier] ?? 0); i++) {
        out.add(c);
      }
    }
    return out;
  }

  Chunk spacer() => kSpacers[rng.nextInt(kSpacers.length)];

  final body = <Chunk>[];
  final bodySegment = <int>[]; // segment index per body chunk, for rerolls
  var width = 0;
  while (width < kDeepColumns) {
    final segment = width ~/ kDeepSegmentColumns;
    final weighted = weightedFor(segment);
    final c = weighted[rng.nextInt(weighted.length)];
    body.add(c);
    bodySegment.add(segment);
    width += c.width;
    final sp = spacer();
    body.add(sp);
    bodySegment.add(segment);
    width += sp.width;
  }

  final code = packCode(kGeneratorVersion, seed & kSeedMask);
  var rerolls = 0;
  for (var attempt = 0; attempt < 120; attempt++) {
    final course = Course(
      seed: code,
      chunks: [kStart, ...body, kFinish],
      speed: kDeepSpeed,
    );
    // A long corridor needs a bigger search budget than a 220-column Daily.
    final res = solve(course, maxNodes: 1200000);
    if (res.solvable) return GeneratedCourse(course, res.solution!, rerolls);
    // Replace the chunk that walled the solver, keeping its segment's tier mix.
    final starts = course.chunkStarts;
    var idx = 0;
    for (var i = 0; i < starts.length; i++) {
      if (starts[i] <= res.furthestX) idx = i;
    }
    final bodyIdx = (idx - 1).clamp(0, body.length - 1);
    if (body[bodyIdx].tier == 0) {
      body[bodyIdx] = spacer();
    } else {
      final weighted = weightedFor(bodySegment[bodyIdx]);
      body[bodyIdx] = weighted[rng.nextInt(weighted.length)];
    }
    rerolls++;
  }
  // Fallback that can never fail: the easiest ramp only.
  final easy = <Chunk>[];
  var w = 0;
  final weighted = weightedFor(0);
  while (w < kDeepColumns) {
    final c = weighted[rng.nextInt(weighted.length)];
    easy.add(c);
    w += c.width;
    final sp = spacer();
    easy.add(sp);
    w += sp.width;
  }
  final course = Course(
    seed: code,
    chunks: [kStart, ...easy, kFinish],
    speed: kDeepSpeed,
  );
  final res = solve(course, maxNodes: 1200000);
  if (res.solvable) return GeneratedCourse(course, res.solution!, rerolls);
  final flat = Course(
    seed: code,
    chunks: [kStart, kSpacers.first, kFinish],
    speed: kDeepSpeed,
  );
  return GeneratedCourse(flat, solve(flat).solution!, rerolls);
}

/// A fresh dive seed. Not cryptographic; just different every time.
int newDeepSeed([Random? rng]) => (rng ?? Random()).nextInt(1 << 27);

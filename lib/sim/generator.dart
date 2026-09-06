/// Seeded course generation. Same seed → same course on every device.
library;

import 'dart:math';

import 'chunks.dart';
import 'course.dart';
import 'course_code.dart';
import 'solver.dart';

/// Current generator version. Bump when the chunk pool or the rules change;
/// never edit an existing version's pool (issued codes depend on it).
const int kGeneratorVersion = 1;

/// Frozen chunk pools by generator version (names into kChunks).
const Map<int, List<String>> kVersionPools = {
  1: [
    'spike1', 'spike_pair', 'ceil_spike1', 'step_up', 'hang_block', 'pit_short',
    'spike_both', 'step_then_hang', 'pit_spike_ceiling', 'spike_wall', 'ceiling_teeth', 'tall_step',
    'spike_field', 'ceiling_field', 'field_swap',
    'zigzag', 'spike_gauntlet', 'narrow_hall', 'pit_then_teeth', 'stair_spikes',
    'teeth_both', 'hall_spiked', 'pit_hall',
  ],
};

class GenSpec {
  const GenSpec({
    required this.seed,
    this.version = kGeneratorVersion,
    this.targetColumns = 220,
    this.speed = 9,
    this.maxTier = 4,
    this.tierWeights = const {1: 3, 2: 4, 3: 3, 4: 1},
  });

  /// Build from a 6-char course code's packed value.
  factory GenSpec.fromCode(int packed) => GenSpec(seed: codeSeed(packed), version: codeVersion(packed));

  final int seed;
  final int version;

  int get packedCode => packCode(version, seed);
  final int targetColumns;
  final double speed;
  final int maxTier;
  final Map<int, int> tierWeights;
}

class GeneratedCourse {
  const GeneratedCourse(this.course, this.solution, this.rerolls);
  final Course course;
  final Solution solution;

  /// How many chunk replacements the solver forced. Logged for tuning.
  final int rerolls;
}

/// Build a solvable course. Deterministic for a given [spec].
GeneratedCourse generate(GenSpec spec) {
  final rng = Random(spec.seed);
  final names = kVersionPools[spec.version];
  if (names == null) throw ArgumentError('unknown generator version ${spec.version}');
  final pool = [for (final n in names) chunkByName(n)!].where((c) => c.tier <= spec.maxTier).toList();
  final weighted = <Chunk>[];
  for (final c in pool) {
    for (var i = 0; i < (spec.tierWeights[c.tier] ?? 0); i++) {
      weighted.add(c);
    }
  }
  if (weighted.isEmpty) throw StateError('empty chunk pool');

  Chunk pick() => weighted[rng.nextInt(weighted.length)];
  Chunk spacer() => kSpacers[rng.nextInt(kSpacers.length)];

  final body = <Chunk>[];
  var width = 0;
  while (width < spec.targetColumns) {
    final c = pick();
    body.add(c);
    width += c.width;
    final sp = spacer();
    body.add(sp);
    width += sp.width;
  }

  var rerolls = 0;
  for (var attempt = 0; attempt < 60; attempt++) {
    final course = Course(seed: spec.packedCode, chunks: [kStart, ...body, kFinish], speed: spec.speed);
    final res = solve(course);
    if (res.solvable) {
      return GeneratedCourse(course, res.solution!, rerolls);
    }
    // Replace the chunk containing the furthest reach (that's the wall).
    final starts = course.chunkStarts;
    var idx = 0;
    for (var i = 0; i < starts.length; i++) {
      if (starts[i] <= res.furthestX) idx = i;
    }
    final bodyIdx = (idx - 1).clamp(0, body.length - 1);
    body[bodyIdx] = body[bodyIdx].tier == 0 ? spacer() : pick();
    rerolls++;
  }
  // Absolute fallback: a flat course is always solvable.
  final flat = Course(seed: spec.packedCode, chunks: [kStart, kSpacers.first, kFinish], speed: spec.speed);
  return GeneratedCourse(flat, solve(flat).solution!, rerolls);
}

/// Daily seed (27-bit): derived from the UTC date so everyone shares it.
int dailySeed(DateTime when) {
  final utc = when.toUtc(); // defensive: a local DateTime must not shift the day
  final d = DateTime.utc(utc.year, utc.month, utc.day);
  final days = d.difference(DateTime.utc(2026, 1, 1)).inDays;
  // Mix so consecutive days are unrelated.
  var x = days * 0x9E3779B1;
  x ^= x >> 15;
  x *= 0x85EBCA77;
  x ^= x >> 13;
  return x & kSeedMask;
}

/// Human label for a daily, e.g. "Daily #245".
int dailyNumber(DateTime when) {
  final utc = when.toUtc();
  final d = DateTime.utc(utc.year, utc.month, utc.day);
  return d.difference(DateTime.utc(2026, 1, 1)).inDays + 1;
}

/// Seconds the optimal run takes — the course's nominal length for the UI.
double nominalSeconds(Course c) => c.length / c.speed;


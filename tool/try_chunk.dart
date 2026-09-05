// Quick designer aid: solve a chunk grid given as 6 rows on argv, print result.
import 'package:fliptide/sim/chunks.dart';
import 'package:fliptide/sim/course.dart';
import 'package:fliptide/sim/solver.dart';

// ignore_for_file: avoid_print
void main(List<String> args) {
  final rows = args.length == 6 ? args : args.first.split('|');
  final c = Chunk.parse('try', 9, rows);
  final course = Course(seed: 0, chunks: [kStart, kSpacers.first, c, kSpacers.first, kFinish], speed: 9);
  final r = solve(course);
  print('${r.solvable ? "SOLVABLE" : "UNSOLVABLE"} furthest=${r.furthestX.toStringAsFixed(1)}/${course.length} flips=${r.solution?.flips.length} explored=${r.explored}');
}

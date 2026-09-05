// Directive 02k rule 2: second chance resumes from the last checkpoint.
import 'package:flame/game.dart';
import 'package:fliptide/game/flip_game.dart';
import 'package:fliptide/sim/checkpoint.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:fliptide/sim/generator.dart';
import 'package:fliptide/sim/physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Listener implements FlipListener {
  int attempts = -1;
  int deaths = 0;
  int wins = 0;
  @override
  void onAttempt(int a) => attempts = a;
  @override
  void onDeath(double progress, int a, DeathCause cause) => deaths++;
  @override
  void onProgress(double progress) {}
  @override
  void onWin(int a, int frames) => wins++;
}

/// Solution flips truncated at the first frame where progress >= [cut]
/// (so the player runs straight afterwards and dies).
List<int> _truncatedSolution(GeneratedCourse gen, double cut) {
  final sim = Sim(gen.course);
  final flips = gen.solution.flips.toSet();
  while (sim.s.state == RunState.running && sim.progress < cut) {
    sim.step(tap: flips.contains(sim.s.frame));
  }
  final cutFrame = sim.s.frame;
  return gen.solution.flips.where((f) => f < cutFrame).toList();
}

void main() {
  final gen = generate(GenSpec.fromCode(codeToSeed('400C1S')!));

  test('tracker snapshots the first grounded frame at/after 25/50/75 %; resume then finish wins', () {
    final sim = Sim(gen.course);
    final tracker = CheckpointTracker();
    final flips = gen.solution.flips.toSet();
    SimState? at50;
    while (sim.s.state == RunState.running) {
      sim.step(tap: flips.contains(sim.s.frame));
      tracker.observe(sim);
      if (tracker.frac == 0.5 && at50 == null) at50 = tracker.state!.copy();
    }
    expect(sim.s.state, RunState.won, reason: 'solution replays to a win');
    expect(tracker.frac, 0.75);
    expect(at50, isNotNull);
    expect(at50!.grounded, isTrue);
    expect(at50.x / gen.course.length, greaterThanOrEqualTo(0.5));
    // Rewind to the 50 % snapshot and replay the rest of the solution: still wins.
    sim.resumeFrom(at50);
    expect(sim.flips.every((f) => f <= at50!.frame), isTrue);
    while (sim.s.state == RunState.running) {
      sim.step(tap: flips.contains(sim.s.frame));
    }
    expect(sim.s.state, RunState.won);
  });

  testWidgets('FlipGame: die after 60 % → checkpoint 50 %, resume keeps the attempt number and runs from ~50 %', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final l = _Listener();
    final game = FlipGame(course: gen.course, listener: l, autoFlips: _truncatedSolution(gen, 0.6));
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    game.press(); // start
    for (var i = 0; i < 6000 && game.sim.s.state == RunState.running; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.sim.s.state, RunState.dead, reason: 'running straight after 60 % must kill the player');
    expect(game.sim.progress, greaterThan(0.6));
    expect(game.checkpoints.hasCheckpoint, isTrue);
    expect(game.checkpoints.frac, 0.5);
    final attemptsBefore = game.attempts;
    expect(game.secondsSinceDeath, 0);
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.secondsSinceDeath, greaterThanOrEqualTo(0.3));

    expect(game.resumeFromCheckpoint(), isTrue);
    expect(game.sim.s.state, RunState.running);
    expect(game.attempts, attemptsBefore, reason: 'a resume is not a new attempt');
    expect(l.attempts, attemptsBefore);
    expect(game.sim.progress, closeTo(0.5, 0.03));
    // It keeps simulating from there (and, with no more flips, dies again later).
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.sim.progress, greaterThan(0.5));
    expect(game.resumeFromCheckpoint(), isFalse, reason: 'only from the dead state');
  });

  test('a fresh attempt has no checkpoint', () {
    final t = CheckpointTracker();
    expect(t.hasCheckpoint, isFalse);
    final sim = Sim(gen.course);
    sim.step();
    t.observe(sim);
    expect(t.hasCheckpoint, isFalse);
  });
}

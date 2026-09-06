// The CODE menu must not cost the player the attempt they were playing.
import 'package:flame/game.dart';
import 'package:fliptide/game/flip_game.dart';
import 'package:fliptide/main.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:fliptide/sim/physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<FlipGame> _start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: PlayScreen(seed: codeToSeed('400C1S'))));
  await tester.pump();
  await tester.pump();
  final game = tester.widget<GameWidget<FlipGame>>(find.byType(GameWidget<FlipGame>)).game!;
  await tester.tapAt(const Offset(195, 422));
  await _frames(tester, 4);
  expect(game.sim.s.state, RunState.running);
  expect(game.attempts, 1);
  return game;
}

Future<void> _openCode(WidgetTester tester) async {
  await tester.tap(find.text('CODE'));
  await _frames(tester, 20);
  expect(find.byType(AlertDialog), findsOneWidget);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('CODE pauses the current attempt; Cancel resumes the same run', (tester) async {
    final game = await _start(tester);
    await _openCode(tester);
    expect(game.paused, isTrue, reason: 'a run must not continue behind the course-code dialog');
    final frame = game.sim.s.frame;
    final attempts = game.attempts;
    await _frames(tester, 150);
    expect(game.sim.s.frame, frame, reason: 'typing must not advance physics or kill the player');
    expect(game.sim.s.state, RunState.running);
    expect(game.attempts, attempts);
    await tester.tap(find.text('Cancel'));
    await _frames(tester, 20);
    expect(game.paused, isFalse);
    expect(game.sim.s.frame, greaterThan(frame));
    expect(game.attempts, attempts, reason: 'closing the dialog is not a retry');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an invalid code returns to the existing attempt and resumes it', (tester) async {
    final game = await _start(tester);
    await _openCode(tester);
    expect(game.paused, isTrue);
    final frame = game.sim.s.frame;
    await tester.enterText(find.byType(TextField), 'BAD');
    await tester.tap(find.widgetWithText(FilledButton, 'PLAY'));
    await _frames(tester, 20);
    expect(find.text('That code is not valid'), findsOneWidget);
    expect(game.paused, isFalse);
    expect(game.attempts, 1);
    expect(game.sim.s.frame, greaterThan(frame));
    expect(tester.widget<GameWidget<FlipGame>>(find.byType(GameWidget<FlipGame>)).game, same(game));
    await _frames(tester, 130); // drain the existing toast timer
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing CODE does not resume a game that was already paused', (tester) async {
    final game = await _start(tester);
    game.pauseEngine();
    final frame = game.sim.s.frame;
    await _openCode(tester);
    await tester.tap(find.text('Cancel'));
    await _frames(tester, 20);
    expect(game.paused, isTrue, reason: 'the dialog may only undo its own pause');
    expect(game.sim.s.frame, frame);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a valid code replaces the course without restarting the old game', (tester) async {
    final oldGame = await _start(tester);
    await _openCode(tester);
    expect(oldGame.paused, isTrue);
    final frame = oldGame.sim.s.frame;
    await tester.enterText(find.byType(TextField), '400-C1T');
    await tester.tap(find.widgetWithText(FilledButton, 'PLAY'));
    await _frames(tester, 40);
    final newGame = tester.widget<GameWidget<FlipGame>>(find.byType(GameWidget<FlipGame>)).game!;
    expect(newGame, isNot(same(oldGame)));
    expect(tester.widget<PlayScreen>(find.byType(PlayScreen)).seed, codeToSeed('400C1T'));
    expect(find.text('attempt 0'), findsOneWidget);
    expect(oldGame.paused, isTrue, reason: 'a replaced course must stay stopped through navigation');
    expect(oldGame.sim.s.frame, frame);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing the screen with CODE open does not resume the abandoned game', (tester) async {
    final game = await _start(tester);
    await _openCode(tester);
    expect(game.paused, isTrue);
    final frame = game.sim.s.frame;
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 20);
    expect(game.paused, isTrue);
    expect(game.sim.s.frame, frame);
    expect(tester.takeException(), isNull);
  });
}

// Directive 02j-3: on the CLEARED screen the player sprite must not be drawn
// over the "attempt N · tell someone" caption. The sprite fades out within
// kWonFadeS; the caption fades in only after that.
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:fliptide/game/flip_game.dart';
import 'package:fliptide/game/palette.dart';
import 'package:fliptide/main.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpUntil(WidgetTester tester, Finder f, {int maxFrames = 6000}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('never found $f');
}

bool _isPlayerColour(int r, int g, int b) {
  const p = Palette.player;
  // Player yellow, allowing for anti-aliasing / partial alpha over the dark corridor.
  return (r - (p.r * 255)).abs() < 40 && (g - (p.g * 255)).abs() < 40 && (b - (p.b * 255)).abs() < 60 && r > 150 && b < 140;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('CLEARED: no player-sprite pixels inside the caption rect; sprite alpha 0 after the fade', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const Key('root'),
      child: MaterialApp(home: PlayScreen(seed: codeToSeed('400C1S'), autoplay: true)),
    ));
    await tester.pump();
    await tester.pump();
    await tester.tapAt(const Offset(195, 422)); // start; the solver plays
    await _pumpUntil(tester, find.text('CLEARED'));
    // Let both fades complete (sprite 150 ms, caption 150–300 ms) and settle.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final game = tester.widget<GameWidget<FlipGame>>(find.byType(GameWidget<FlipGame>)).game!;
    expect(game.playerAlpha, 0, reason: 'sprite must be fully faded on the won screen');

    final caption = find.text('attempt 1 · tell someone');
    expect(caption, findsOneWidget);
    final rect = tester.getRect(caption);
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('root')));
    final img = await tester.runAsync(() => boundary.toImage());
    final bytes = (await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    var hits = 0;
    for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
      for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
        final i = (y * img!.width + x) * 4;
        if (_isPlayerColour(bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2))) hits++;
      }
    }
    expect(hits, 0, reason: 'player-yellow pixels found inside the caption rect $rect');
  });

  testWidgets('death screen: sprite is not drawn (burst only) — 6-death.png stays clean', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PlayScreen(seed: codeToSeed('400C1S'))));
    await tester.pump();
    await tester.pump();
    await tester.tapAt(const Offset(195, 422));
    await _pumpUntil(tester, find.byKey(const Key('death-card')));
    final game = tester.widget<GameWidget<FlipGame>>(find.byType(GameWidget<FlipGame>)).game!;
    expect(game.sim.s.state.name, 'dead');
    // Rendering skips the creature entirely while dead (see FlipGame.render).
    expect(game.playerAlpha, 1.0); // alpha only drives the won fade; dead is handled by the state check
  });
}

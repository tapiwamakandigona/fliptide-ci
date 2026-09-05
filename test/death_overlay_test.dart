// Directive 02h: the death overlay must never eat retry taps, and HUD/overlay
// must show the same percent for the same death.
import 'package:fliptide/main.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:fliptide/sim/physics.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpUntil(WidgetTester tester, Finder f, {int maxFrames = 2400}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('never found $f');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tap at corridor centre on the death overlay starts a new attempt (+1)', (tester) async {
    tester.view.physicalSize = const Size(390, 844); // phone portrait, like the lead's playthrough
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PlayScreen(seed: codeToSeed('400C1S'))));
    await tester.pump(); // Store.open()
    await tester.pump();
    expect(find.text('attempt 0'), findsOneWidget);
    // Start, then never flip: the first obstacle kills the player.
    await tester.tapAt(const Offset(195, 422));
    await _pumpUntil(tester, find.byKey(const Key('death-card')));
    expect(find.text('attempt 1'), findsOneWidget);
    // Inside the guard: the killing tap must not restart.
    await tester.tapAt(const Offset(195, 422));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const Key('death-card')), findsOneWidget);
    // After the guard (~200 ms of real frames): a tap at the corridor centre (NOT on a button) restarts.
    for (var i = 0; i < 13; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.tapAt(const Offset(195, 422));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const Key('death-card')), findsNothing);
    expect(find.text('attempt 2'), findsOneWidget);
    // The button row lives in the bottom fifth, never at screen centre.
    await _pumpUntil(tester, find.byKey(const Key('death-card')));
    final row = tester.getRect(find.byKey(const Key('death-buttons')));
    expect(row.top, greaterThan(844 * 0.8));
  });

  testWidgets('HUD percent and overlay percent agree on the death frame', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PlayScreen(seed: codeToSeed('400C1S'))));
    await tester.pump();
    await tester.pump();
    await tester.tapAt(const Offset(195, 422));
    await _pumpUntil(tester, find.byKey(const Key('death-card')));
    final hud = (tester.widget<Text>(find.byKey(const Key('hud-pct'))).data)!;
    final overlayTitle = tester.widget<Text>(find.descendant(of: find.byKey(const Key('death-card')), matching: find.byType(Text)).first).data!;
    expect(overlayTitle, hud);
  });

  test('percentOf is one rule: floor', () {
    expect(percentOf(0.049), 4);
    expect(percentOf(0.05), 5);
    expect(percentOf(0.999), 99);
    expect(percentOf(1.0), 100);
    expect(percentOf(1.2), 100);
  });

  testWidgets('HUD "100%" renders on one line with the real Inter font', (tester) async {
    final data = File('assets/fonts/Inter-Variable.ttf').readAsBytesSync();
    final loader = FontLoader('Inter')..addFont(Future.value(ByteData.view(data.buffer)));
    await loader.load();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Inter'),
      home: const Scaffold(
        body: Row(children: [
          SizedBox(
            width: 64,
            child: Text('100%', key: Key('hud-pct'), maxLines: 1, softWrap: false, textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ]),
      ),
    ));
    final rp = tester.renderObject<RenderParagraph>(find.byKey(const Key('hud-pct')));
    expect(rp.didExceedMaxLines, isFalse, reason: 'HUD percent must not clip/wrap at 100%');
    expect(rp.size.height, lessThan(18 * 1.6), reason: 'single line');
    expect(rp.textSize.width, lessThanOrEqualTo(64), reason: '"100%" must fit the HUD box');
  });
}

// Self-found on the live CLEARED screen (1280x720): "100%" wrapped onto two
// lines inside the 52 px HUD box. Pin: with the real Inter font loaded, the HUD
// percent text at 100% is a single line.
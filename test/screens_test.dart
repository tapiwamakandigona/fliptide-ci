// Renders real screenshots of the menu flow (title, Tides map, campaign
// start/run/clear) with the bundled Inter font. Evidence generator, not a
// regression test: only runs with
//   flutter test test/screens_test.dart --dart-define=SCREENS=true --update-goldens
import 'dart:io';

import 'package:fliptide/main.dart';
import 'package:fliptide/sim/campaign.dart';
import 'package:fliptide/ui/tides_screen.dart';
import 'package:fliptide/ui/title_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _on = bool.fromEnvironment('SCREENS');

Future<void> _loadInter() async {
  final data = File('assets/fonts/Inter-Variable.ttf').readAsBytesSync();
  final loader = FontLoader('Inter')..addFont(Future.value(ByteData.view(data.buffer)));
  await loader.load();
}

Future<void> _pumpUntil(WidgetTester tester, Finder f, {int maxFrames = 3000}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('never found $f');
}

Widget _app(Widget home) => MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Inter'), home: home);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(_loadInter);
  setUp(() => SharedPreferences.setMockInitialValues({'lvl.t1l1.stars': 3, 'lvl.t1l2.stars': 2, 'lvl.t1l3.stars': 1, 'streak': 4, 'lastDay': 1}));

  testWidgets('title', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const TitleScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(TitleScreen), matchesGoldenFile('../docs/screens/menu-title.png'));
  }, skip: !_on);

  testWidgets('tides', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const TidesScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(TidesScreen), matchesGoldenFile('../docs/screens/menu-tides.png'));
  }, skip: !_on);

  testWidgets('campaign start, run and clear', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(PlayScreen(level: kCampaign[3], autoplay: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(find.byType(PlayScreen), matchesGoldenFile('../docs/screens/campaign-start.png'));
    await tester.tapAt(const Offset(180, 390));
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await expectLater(find.byType(PlayScreen), matchesGoldenFile('../docs/screens/campaign-run.png'));
    await _pumpUntil(tester, find.text('CLEARED'));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(PlayScreen), matchesGoldenFile('../docs/screens/campaign-cleared.png'));
  }, skip: !_on);
}

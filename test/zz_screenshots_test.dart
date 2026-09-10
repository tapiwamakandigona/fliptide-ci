// Visual QA helper, not a check: renders the main screens to PNG so a human
// (or a reviewing agent) can look at them without a device.
//
//   SHOTS_DIR=/tmp/shots flutter test test/zz_screenshots_test.dart
//
// Skipped unless SHOTS_DIR is set, so the normal suite never writes files.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fliptide/main.dart';
import 'package:fliptide/sim/campaign.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:fliptide/store/store.dart';
import 'package:fliptide/ui/settings_sheet.dart';
import 'package:fliptide/ui/title_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _dir = Platform.environment['SHOTS_DIR'];

Future<void> _font() async {
  final bytes = File('assets/fonts/Inter-Variable.ttf').readAsBytesSync();
  await (FontLoader('Inter')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot-root')));
  final img = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final bytes = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
  File('$_dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Widget _root(Widget home) => RepaintBoundary(
  key: const Key('shot-root'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Inter', scaffoldBackgroundColor: const Color(0xFF0B0F1A)),
    home: home,
  ),
);

Future<void> _frames(WidgetTester tester, int n, [int ms = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

void main() {
  if (_dir == null) return;
  Directory(_dir!).createSync(recursive: true);

  setUp(() => SharedPreferences.setMockInitialValues({'deep.best': 143, 'deep.runs': 7, 'lvl.t1l1.stars': 3, 'lvl.t1l2.stars': 2}));

  testWidgets('title', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _font();
    await tester.pumpWidget(_root(const TitleScreen()));
    await _frames(tester, 30);
    await _shot(tester, '01-title');
  });

  testWidgets('settings sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _font();
    final store = await Store.open();
    await tester.pumpWidget(_root(Builder(builder: (ctx) => Scaffold(body: Center(child: TextButton(onPressed: () => showFlipSettings(ctx, store), child: const Text('open')))))));
    await tester.tap(find.text('open'));
    await _frames(tester, 30);
    await _shot(tester, '02-settings');
  });

  testWidgets('deep start + death', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _font();
    await tester.pumpWidget(_root(const PlayScreen(deep: true, deepSeed: 77)));
    await _frames(tester, 4);
    await _shot(tester, '03-deep-start');
    await tester.tapAt(const Offset(195, 422));
    await _frames(tester, 20);
    await _shot(tester, '04-deep-running');
    for (var i = 0; i < 600 && find.byKey(const Key('death-card')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _frames(tester, 14);
    await _shot(tester, '05-deep-death');
  });

  testWidgets('campaign cleared with stars', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _font();
    await tester.pumpWidget(_root(PlayScreen(level: kCampaign.first, autoplay: true)));
    await _frames(tester, 3);
    await tester.tapAt(const Offset(195, 422));
    for (var i = 0; i < 6000 && find.text('CLEARED').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _frames(tester, 24); // mid star-reveal
    await _shot(tester, '06-cleared-mid');
    await _frames(tester, 60);
    await _shot(tester, '07-cleared');
  });

  testWidgets('daily running (landscape)', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _font();
    await tester.pumpWidget(_root(PlayScreen(seed: codeToSeed('400C1S'), autoplay: true)));
    await _frames(tester, 3);
    await tester.tapAt(const Offset(422, 195));
    await _frames(tester, 90);
    await _shot(tester, '08-run-landscape');
  });
}

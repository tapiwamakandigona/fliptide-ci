// Owner directive 2026-09-05b: one quiet "More from Tsoro Studios" row on the
// title screen only — never on the death or CLEARED cards.
import 'package:fliptide/main.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:fliptide/ui/more_games.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _pumpUntil(WidgetTester tester, Finder f, {int maxFrames = 2400}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('never found $f');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('entries: Emberdelve always, Pyregrove only behind the flag', () {
    expect(moreGames(showPyregrove: false).map((g) => g.name), ['Emberdelve']);
    expect(moreGames(showPyregrove: true).map((g) => g.name), ['Emberdelve', 'Pyregrove']);
    expect(kShowPyregrove, isFalse, reason: 'flip only once the Pyregrove listing is public');
    expect(kEmberdelve.playUri.toString(), 'https://play.google.com/store/apps/details?id=com.tsorostudios.emberdelve');
    expect(kEmberdelve.marketUri.toString(), 'market://details?id=com.tsorostudios.emberdelve&referrer=utm_source%3Dfliptide');
  });

  test('Android tries market:// first and falls back to https', () async {
    final tried = <Uri>[];
    Future<bool> failMarket(Uri u, {LaunchMode mode = LaunchMode.platformDefault}) async {
      tried.add(u);
      expect(mode, LaunchMode.externalApplication);
      return u.scheme != 'market';
    }
    expect(await openMoreGame(kEmberdelve, launcher: failMarket, platform: TargetPlatform.android, isWeb: false), isTrue);
    expect(tried.map((u) => u.scheme), ['market', 'https']);
    tried.clear();
    expect(await openMoreGame(kEmberdelve, launcher: failMarket, platform: TargetPlatform.android, isWeb: true), isTrue);
    expect(tried.map((u) => u.scheme), ['https'], reason: 'web builds never try market://');
  });

  testWidgets('row renders on the title screen, hidden once a run starts, tap opens the entry', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PlayScreen(seed: codeToSeed('400C1S'))));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('more-from-tsoro')), findsOneWidget);
    expect(find.textContaining('Emberdelve'), findsOneWidget);
    expect(find.textContaining('Pyregrove'), findsNothing);
    // Start a run: the row must vanish and never sit on the death card.
    await tester.tapAt(const Offset(195, 422));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const Key('more-from-tsoro')), findsNothing);
    await _pumpUntil(tester, find.byKey(const Key('death-card')));
    expect(find.byKey(const Key('more-from-tsoro')), findsNothing);
  });

  testWidgets('tapping an entry calls the opener once with that game', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: MoreFromTsoro(onOpen: (g) async { opened.add(g.name); return true; }))),
    ));
    await tester.tap(find.byKey(const Key('more-com.tsorostudios.emberdelve')));
    await tester.pump();
    expect(opened, ['Emberdelve']);
  });
}

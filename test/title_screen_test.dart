// Front door + campaign flow: the app opens on a title screen, the Tides map
// locks what has not been earned, and a campaign clear awards stars and a
// NEXT button.
import 'package:fliptide/main.dart';
import 'package:fliptide/sim/campaign.dart';
import 'package:fliptide/ui/tides_screen.dart';
import 'package:fliptide/ui/title_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpUntil(WidgetTester tester, Finder f, {int maxFrames = 3000}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('never found $f');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the app boots to the title screen with PLAY / TIDES / DAILY / CODE', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FlipApp());
    await tester.pump();
    await tester.pump();
    expect(find.byType(TitleScreen), findsOneWidget);
    expect(find.byKey(const Key('title-play')), findsOneWidget);
    expect(find.byKey(const Key('title-tides')), findsOneWidget);
    expect(find.byKey(const Key('title-daily')), findsOneWidget);
    expect(find.byKey(const Key('title-code')), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.textContaining('tide 1 · 1'), findsOneWidget, reason: 'PLAY points at the first course on a fresh save');
    expect(find.byKey(const Key('more-from-tsoro')), findsOneWidget);
    expect(find.text('TSORO STUDIOS'), findsOneWidget);
  });

  testWidgets('the Tides map: tide 1 course 1 open, course 2 and tide 2 locked', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: TidesScreen()));
    await tester.pump();
    await tester.pump();
    expect(find.text('Shallows'), findsOneWidget);
    expect(find.text('First Light'), findsOneWidget);
    final t1 = tester.widget<Material>(find.byKey(const Key('tile-t1l1')));
    final t2 = tester.widget<Material>(find.byKey(const Key('tile-t1l2')));
    expect(t1.color, isNot(equals(t2.color)), reason: 'locked tiles are drawn differently');
    // Tapping a locked tile does nothing.
    await tester.tap(find.byKey(const Key('tile-t1l2')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlayScreen), findsNothing);
    // Tapping the open tile starts that course.
    await tester.tap(find.byKey(const Key('tile-t1l1')));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlayScreen), findsOneWidget);
    expect(find.text('TIDE 1 · 1'), findsOneWidget);
    expect(find.byKey(const Key('hud-menu')), findsOneWidget);
  });

  testWidgets('clearing a campaign course on the first try awards 3 stars, unlocks the next, offers NEXT', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PlayScreen(level: kCampaign.first, autoplay: true)));
    await tester.pump();
    await tester.pump();
    expect(find.text('First Light'), findsOneWidget, reason: 'start card names the course');
    await tester.tapAt(const Offset(195, 422)); // start
    await _pumpUntil(tester, find.text('CLEARED'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('cleared-stars')), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byKey(const Key('next-level')), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('lvl.t1l1.stars'), 3);
    // NEXT moves to course 2.
    await tester.tap(find.byKey(const Key('next-level')));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('TIDE 1 · 2'), findsOneWidget);
  });
}

import 'package:fliptide/main.dart';
import 'package:fliptide/sim/generator.dart';
import 'package:fliptide/store/store.dart';
import 'package:fliptide/ui/title_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('valid saved ghost roundtrip retains all recorded progress', () async {
    final store = await Store.open();
    await store.save(DailyRecord(
      number: 42,
      best: 0.82,
      attempts: 7,
      won: true,
      ghost: [0, 24, 156, 2048],
    ));
    await store.setSupporter(true);
    await store.clearLevel('t1l1', 3);

    final back = store.daily(42);
    expect(back.number, 42);
    expect(back.best, 0.82);
    expect(back.attempts, 7);
    expect(back.won, isTrue);
    expect(back.ghost, [0, 24, 156, 2048]);
    expect(store.supporter, isTrue);
    expect(store.levelStars('t1l1'), 3);
  });

  for (final invalid in <Object>[
    '0,24,broken,72',
    '0,24,',
    '-1,24,72',
    '0,24,24',
    '0,72,24',
    123,
  ]) {
    test('invalid ghost $invalid is isolated without deleting progress',
        () async {
      SharedPreferences.setMockInitialValues({
        'd42.best': 0.82,
        'd42.attempts': 7,
        'd42.won': true,
        'd42.ghost': invalid,
        'lvl.t1l1.stars': 3,
        'supporter': true,
      });
      final store = await Store.open();
      final record = store.daily(42);

      expect(record.ghost, isEmpty,
          reason: 'never replay a partial or reordered corrupt ghost');
      expect(record.best, 0.82);
      expect(record.attempts, 7);
      expect(record.won, isTrue);
      expect(store.levelStars('t1l1'), 3);
      expect(store.supporter, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get('d42.ghost'), invalid,
          reason: 'reading a damaged ghost must not reset user storage');
    });
  }

  testWidgets('title remains usable with a damaged saved daily ghost',
      (tester) async {
    final today = dailyNumber(DateTime.now().toUtc());
    SharedPreferences.setMockInitialValues({
      'd$today.ghost': '0,18,damaged',
      'd$today.best': 0.5,
      'd$today.attempts': 2,
      'lvl.t1l1.stars': 3,
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FlipApp());
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(TitleScreen), findsOneWidget);
    expect(find.byKey(const Key('title-play')), findsOneWidget);
    expect(find.byKey(const Key('title-daily')), findsOneWidget);
    expect(find.textContaining('tide 1 · 2'), findsOneWidget);
    expect(find.textContaining('best 50%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

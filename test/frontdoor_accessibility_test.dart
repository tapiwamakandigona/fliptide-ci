import 'dart:io';

import 'package:fliptide/main.dart';
import 'package:fliptide/sim/campaign.dart';
import 'package:fliptide/sim/shallows.dart';
import 'package:fliptide/ui/language.dart';
import 'package:fliptide/ui/tides_screen.dart';
import 'package:fliptide/ui/title_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _font() async {
  final bytes = File('assets/fonts/Inter-Variable.ttf').readAsBytesSync();
  await (FontLoader(
    'Inter',
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.5;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _frames(WidgetTester tester, [int n = 35]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Widget _localized(String code, Widget child) => MaterialApp(
  locale: FlipLanguage.locale(code),
  supportedLocales: flipLocales,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData(fontFamily: 'Inter'),
  home: child,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlipLanguage.choice.value = 'system';
  });
  tearDown(() => FlipLanguage.choice.value = 'system');

  test('catalog coverage, placeholder parity and literal fallback', () {
    final re = RegExp(r'\{[a-zA-Z]+\}');
    for (final entry in flipCatalog.entries) {
      expect(entry.value.length, 3);
      final expected = re.allMatches(entry.key).map((m) => m[0]).toSet();
      for (final translated in entry.value) {
        expect(translated.trim(), isNotEmpty);
        expect(re.allMatches(translated).map((m) => m[0]).toSet(), expected);
      }
    }
    for (final source in [
      ...shallowsHints,
      ...shallowsStory,
      ...kTides.first.levels.map((l) => l.name),
    ]) {
      expect(flipCatalog, contains(source));
    }
    expect(flipText('ABC-123', 'fr'), 'ABC-123');
    expect(flipText('PLAY', 'zz'), 'PLAY');
    expect(
      flipText('TIDE {number}', 'pt', args: {'number': '{number}'}),
      'MARÉ {number}',
    );
  });

  test('language is optional, persisted and safely validated', () async {
    await FlipLanguage.load();
    expect(FlipLanguage.choice.value, 'system');
    expect(await FlipLanguage.save('pt'), isTrue);
    FlipLanguage.choice.value = 'system';
    await FlipLanguage.load();
    expect(FlipLanguage.choice.value, 'pt');
    SharedPreferences.setMockInitialValues({'interfaceLanguage': 7});
    await FlipLanguage.load();
    expect(FlipLanguage.choice.value, 'system');
    expect(FlipLanguage.valid('xx'), 'system');
    expect(FlipLanguage.locale('system'), isNull);
  });

  testWidgets(
    'French Canadian device locale, manual override, unsupported fallback',
    (tester) async {
      _phone(tester);
      await _font();
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'CA')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(const FlipApp());
      await _frames(tester);
      expect(find.text('JOUER'), findsOneWidget);
      await FlipLanguage.save('es');
      await _frames(tester);
      expect(find.text('JUGAR'), findsOneWidget);
      await FlipLanguage.save('system');
      tester.platformDispatcher.localesTestValue = const [Locale('zz')];
      await _frames(tester);
      expect(find.text('PLAY'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final code in ['fr', 'es', 'pt']) {
    testWidgets('$code title and code entry readable at 320px / 1.5x text', (
      tester,
    ) async {
      _phone(tester);
      await _font();
      SharedPreferences.setMockInitialValues({'interfaceLanguage': code});
      await tester.pumpWidget(const FlipApp());
      await _frames(tester);
      expect(find.text(flipText('PLAY', code)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('title-code')));
      await tester.tap(find.byKey(const Key('title-code')));
      await _frames(tester);
      expect(find.text(flipText('Play a course code', code)), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ABC-123');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'ABC-123',
      );
      await tester.tap(find.text(flipText('Cancel', code)));
      await _frames(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('$code map and Shallows start are readable at 320px / 1.5x', (
      tester,
    ) async {
      _phone(tester);
      await _font();
      await tester.pumpWidget(_localized(code, const TidesScreen()));
      await _frames(tester);
      expect(find.text(flipText('First Light', code)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('tile-t1l1')));
      await _frames(tester);
      expect(find.text(flipText(shallowsHints.first, code)), findsOneWidget);
      expect(find.text(flipText(shallowsStory.first, code)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      '$code clear controls retain accessible next/share/card actions',
      (tester) async {
        _phone(tester);
        await _font();
        await tester.pumpWidget(
          _localized(code, PlayScreen(level: kCampaign.first, autoplay: true)),
        );
        await _frames(tester);
        await tester.tapAt(const Offset(160, 320));
        for (
          var i = 0;
          i < 1500 && find.byKey(const Key('death-buttons')).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await _frames(tester);
        expect(find.text(flipText('CLEARED', code)), findsOneWidget);
        expect(find.text(flipText('NEXT', code)), findsOneWidget);
        expect(find.text(flipText('SHARE', code)), findsOneWidget);
        expect(find.text(flipText('CARD', code)), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('language picker changes persisted choice through real controls', (
    tester,
  ) async {
    _phone(tester);
    await _font();
    await tester.pumpWidget(const FlipApp());
    await _frames(tester);
    await tester.ensureVisible(find.byKey(const Key('title-language')));
    await tester.tap(find.byKey(const Key('title-language')));
    await _frames(tester);
    await tester.tap(find.byKey(const Key('interface-language')));
    await _frames(tester);
    await tester.tap(find.text('Español').last);
    await _frames(tester);
    expect(FlipLanguage.choice.value, 'es');
    expect(
      (await SharedPreferences.getInstance()).getString('interfaceLanguage'),
      'es',
    );
    expect(
      find.text(
        flipText(
          'Navigation and Shallows lessons are translated. Some store, sharing and later-course text remains in English.',
          'es',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cerrar'));
    await _frames(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'backdrop reduced motion parks ticker; animation repaints without builds',
    (tester) async {
      Future<void> mount(bool reduce) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: const SizedBox.expand(child: TitleBackdrop()),
          ),
        ),
      );
      await mount(true);
      await _frames(tester, 2);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await mount(false);
      await _frames(tester, 2);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      final painterFinder = find.descendant(
        of: find.byType(TitleBackdrop),
        matching: find.byType(CustomPaint),
      );
      final widgetBefore = tester.widget<CustomPaint>(painterFinder);
      final painterBefore = tester
          .renderObject<RenderCustomPaint>(painterFinder)
          .painter;
      await _frames(tester, 60);
      expect(
        identical(tester.widget<CustomPaint>(painterFinder), widgetBefore),
        isTrue,
      );
      expect(
        identical(
          tester.renderObject<RenderCustomPaint>(painterFinder).painter,
          painterBefore,
        ),
        isTrue,
      );
      await mount(true);
      await _frames(tester, 2);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

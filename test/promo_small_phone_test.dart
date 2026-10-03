// Directive 05b on the ads line: Support row + cross-promo footer must fit the
// bottom band on the smallest supported phone without overflow.
import 'package:fliptide/main.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('360x640 title: footer renders, no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PlayScreen(seed: codeToSeed('400C1S'))));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('more-from-tsoro')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

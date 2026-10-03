// Supporter entry point on the title screen (02O-1 on the new front door):
// SUPPORT + Restore while not owned, one mark once owned, nothing without a store.
import 'package:fliptide/iap/iap_service.dart';
import 'package:fliptide/ui/title_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeIap extends IapService {
  FakeIap({this.buyResult = PurchaseOutcome.owned, this.restoreOwned = false});
  final PurchaseOutcome buyResult;
  final bool restoreOwned;
  int inits = 0, buys = 0, restores = 0;
  @override
  bool get supported => true;
  @override
  Future<void> init() async {
    inits++;
    price.value = 'US\$1.99';
  }

  @override
  Future<PurchaseOutcome> buy() async {
    buys++;
    if (buyResult == PurchaseOutcome.owned) owned.value = true;
    return buyResult;
  }

  @override
  Future<bool> restore() async {
    restores++;
    if (restoreOwned) owned.value = true;
    return restoreOwned;
  }
}

void _phone(WidgetTester tester, [Size size = const Size(360, 640)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpTitle(WidgetTester tester, IapService iap) async {
  await tester.pumpWidget(MaterialApp(home: TitleScreen(iapService: iap)));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('with a store: SUPPORT shows the price, Restore is present, no overflow at 360x640', (tester) async {
    _phone(tester);
    final iap = FakeIap();
    await _pumpTitle(tester, iap);
    expect(iap.inits, 1, reason: 'startup restore runs once');
    expect(find.byKey(const Key('title-support')), findsOneWidget);
    expect(find.byKey(const Key('title-restore')), findsOneWidget);
    expect(find.textContaining('US\$1.99'), findsOneWidget);
    expect(find.byKey(const Key('title-supporter-mark')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('buying flips the flag: mark replaces the button, persisted in the store', (tester) async {
    _phone(tester, const Size(390, 844));
    final iap = FakeIap();
    await _pumpTitle(tester, iap);
    await tester.tap(find.byKey(const Key('title-support')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(iap.buys, 1);
    expect(find.byKey(const Key('title-supporter-mark')), findsOneWidget);
    expect(find.byKey(const Key('title-support')), findsNothing);
    expect((await SharedPreferences.getInstance()).getBool('supporter'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restore with nothing owned leaves the button and says so', (tester) async {
    _phone(tester, const Size(390, 844));
    final iap = FakeIap(restoreOwned: false);
    await _pumpTitle(tester, iap);
    await tester.tap(find.byKey(const Key('title-restore')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(iap.restores, 1);
    expect(find.byKey(const Key('title-support')), findsOneWidget);
    expect(find.textContaining('No Supporter purchase'), findsOneWidget);
  });

  testWidgets('already a supporter: only the mark, no init call', (tester) async {
    SharedPreferences.setMockInitialValues({'supporter': true});
    _phone(tester);
    final iap = FakeIap();
    await _pumpTitle(tester, iap);
    expect(iap.inits, 0);
    expect(find.byKey(const Key('title-supporter-mark')), findsOneWidget);
    expect(find.byKey(const Key('title-support')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no store (web/desktop): no purchase UI at all', (tester) async {
    _phone(tester);
    await _pumpTitle(tester, NoIapService());
    expect(find.byKey(const Key('title-support')), findsNothing);
    expect(find.byKey(const Key('title-restore')), findsNothing);
    expect(find.byKey(const Key('title-supporter-mark')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

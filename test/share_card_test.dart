import 'dart:io';

import 'package:fliptide/sim/generator.dart';
import 'package:fliptide/ui/share_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('share card renders a real PNG (and saves a sample for the look-loop)', (tester) async {
    final g = generate(const GenSpec(seed: 245));
    final died = (await tester.runAsync(() => renderShareCard(ShareCardData(
      dailyNumber: 245,
      progress: 0.87,
      attempts: 12,
      course: g.course,
      won: false,
      streak: 3,
      deathXs: [0.11 * g.course.length, 0.40 * g.course.length, 0.62 * g.course.length],
    ))))!;
    final won = (await tester.runAsync(() => renderShareCard(ShareCardData(dailyNumber: 245, progress: 1, attempts: 31, course: g.course, won: true, streak: 1))))!;
    expect(died.length, greaterThan(5000));
    expect(won.length, greaterThan(5000));
    // PNG signature.
    expect(died.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    Directory('build').createSync(recursive: true);
    File('build/share_card_died.png').writeAsBytesSync(died);
    File('build/share_card_won.png').writeAsBytesSync(won);
  });
}

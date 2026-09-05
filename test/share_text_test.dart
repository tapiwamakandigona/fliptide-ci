import 'package:fliptide/sim/course_code.dart';
import 'package:fliptide/sim/generator.dart';
import 'package:fliptide/ui/share_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// F4: text share first. ≤ 300 chars, contains 'Fliptide', code, death %,
/// attempt count and the link — for died/won × daily/code.
void main() {
  test('share text contract', () {
    final g = generate(GenSpec(seed: dailySeed(DateTime.utc(2026, 9, 2))));
    final code = prettyCode(seedToCode(g.course.seed));
    final cases = {
      'daily died': shareText(course: g.course, dailyNumber: 245, progress: 0.87, attempts: 12, won: false, streak: 5),
      'daily won': shareText(course: g.course, dailyNumber: 245, progress: 1, attempts: 31, won: true, streak: 1),
      'code died': shareText(course: g.course, dailyNumber: null, progress: 0.03, attempts: 1, won: false, streak: 0),
      'code won': shareText(course: g.course, dailyNumber: null, progress: 1, attempts: 999, won: true, streak: 99),
    };
    for (final e in cases.entries) {
      final t = e.value;
      expect(t.length, lessThanOrEqualTo(300), reason: '${e.key}: $t');
      expect(t, contains('Fliptide'), reason: e.key);
      expect(t, contains(kShareUrl), reason: e.key);
      expect(t, contains(code), reason: e.key);
      expect(t, contains(RegExp(r'attempt \d+|in \d+ tr')), reason: e.key);
    }
    expect(cases['daily died'], contains('87%'));
    expect(cases['daily died'], contains('✗'));
    expect(cases['daily won'], contains('CLEARED'));
    expect(cases['daily won'], isNot(contains('✗')));
  });
}

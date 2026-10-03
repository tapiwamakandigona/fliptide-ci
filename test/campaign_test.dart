// The Tides: every authored course must be real (not the flat fallback),
// solvable, uniquely keyed, and harder tide by tide. Stars and unlocks are
// pure functions of the save.
import 'package:fliptide/sim/campaign.dart';
import 'package:fliptide/sim/generator.dart';
import 'package:fliptide/store/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('30 courses, 5 tides of 6, unique stable ids', () {
    expect(kTides.length, 5);
    expect(kCampaign.length, 30);
    for (final t in kTides) {
      expect(t.levels.length, 6);
    }
    expect(kCampaign.map((l) => l.id).toSet().length, 30);
    expect(kCampaign.first.id, 't1l1');
    expect(kCampaign.last.id, 't5l6');
    expect(kCampaign[7].label, 'TIDE 2 · 2');
  });

  test('every course generates solvable, non-fallback geometry with few rerolls', () {
    for (final l in kCampaign) {
      final g = generate(l.spec);
      expect(g.course.chunks.length, greaterThan(8), reason: '${l.id} looks like the flat fallback');
      expect(g.solution.flips, isNotEmpty, reason: '${l.id} has no flips — trivial');
      expect(g.rerolls, lessThanOrEqualTo(3), reason: '${l.id} needed ${g.rerolls} rerolls');
    }
  });

  test('the curve rises: each tide is longer and faster than the last', () {
    double avgSecs(Tide t) => t.levels.map((l) => nominalSeconds(generate(l.spec).course)).reduce((a, b) => a + b) / t.levels.length;
    double avgSpeed(Tide t) => t.levels.map((l) => l.spec.speed).reduce((a, b) => a + b) / t.levels.length;
    int maxTier(Tide t) => t.levels.map((l) => l.spec.maxTier).reduce((a, b) => a > b ? a : b);
    for (var i = 1; i < kTides.length; i++) {
      expect(avgSecs(kTides[i]), greaterThan(avgSecs(kTides[i - 1])), reason: 'tide ${i + 1} not longer');
      expect(avgSpeed(kTides[i]), greaterThanOrEqualTo(avgSpeed(kTides[i - 1])), reason: 'tide ${i + 1} not faster');
      expect(maxTier(kTides[i]), greaterThanOrEqualTo(maxTier(kTides[i - 1])));
    }
    // Tide 1 teaches: only tier-1 hazards until its final course.
    for (final l in kTides.first.levels.take(5)) {
      expect(l.spec.maxTier, 1);
    }
    expect(nominalSeconds(generate(kCampaign.first.spec).course), lessThan(15));
    expect(nominalSeconds(generate(kCampaign.last.spec).course), greaterThan(25));
  });

  test('stars: first try 3, within three 2, otherwise 1', () {
    expect(starsFor(1), 3);
    expect(starsFor(2), 2);
    expect(starsFor(3), 2);
    expect(starsFor(4), 1);
    expect(starsFor(40), 1);
  });

  test('nextLevel walks the campaign and ends with null', () {
    expect(nextLevel(kCampaign[0]), kCampaign[1]);
    expect(nextLevel(kCampaign[5]), kCampaign[6], reason: 'crosses the tide boundary');
    expect(nextLevel(kCampaign.last), isNull);
    expect(levelById('t3l4')?.name, 'Cavern');
    expect(levelById('nope'), isNull);
  });

  group('store', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('only the first course is unlocked on a fresh save', () async {
      final s = await Store.open();
      expect(s.levelUnlocked(kCampaign[0]), isTrue);
      expect(s.levelUnlocked(kCampaign[1]), isFalse);
      expect(s.nextCampaignLevel, kCampaign[0]);
      expect(s.totalStars, 0);
      expect(s.levelsCleared, 0);
    });

    test('clearing unlocks the next course; stars only ever go up', () async {
      final s = await Store.open();
      await s.clearLevel('t1l1', 2);
      expect(s.levelStars('t1l1'), 2);
      expect(s.levelUnlocked(kCampaign[1]), isTrue);
      expect(s.levelUnlocked(kCampaign[2]), isFalse);
      expect(s.nextCampaignLevel, kCampaign[1]);
      await s.clearLevel('t1l1', 1);
      expect(s.levelStars('t1l1'), 2, reason: 'a worse replay must not lower the record');
      await s.clearLevel('t1l1', 3);
      expect(s.levelStars('t1l1'), 3);
      expect(s.totalStars, 3);
      expect(s.levelsCleared, 1);
    });

    test('a fully cleared campaign points PLAY at the last course', () async {
      final s = await Store.open();
      for (final l in kCampaign) {
        await s.clearLevel(l.id, 1);
      }
      expect(s.levelsCleared, 30);
      expect(s.nextCampaignLevel, kCampaign.last);
    });
  });
}

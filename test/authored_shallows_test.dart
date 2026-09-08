import 'dart:io';

import 'package:fliptide/sim/campaign.dart';
import 'package:fliptide/sim/generator.dart';
import 'package:fliptide/sim/physics.dart';
import 'package:fliptide/ui/share_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final level in kTides.first.levels) {
    test(
      '${level.id}: authored geometry, solver replay, exact menu duration',
      () {
        final generated = level.buildCourse();
        expect(generated.rerolls, 0, reason: 'authored means no random repair');
        expect(generated.course.chunks.length, greaterThanOrEqualTo(9));
        expect(
          Sim.replay(generated.course, generated.solution.flips).state,
          RunState.won,
        );
        expect(level.estimatedSeconds, nominalSeconds(generated.course));
        expect(level.hint, isNotEmpty);
        expect(level.story, isNotEmpty);
      },
    );

    for (final lookahead in [2.5, 3.0, 3.5, 4.0]) {
      test(
        '${level.id}: readable $lookahead tile reaction window, no mashed taps',
        () {
          final course = level.buildCourse().course;
          final sim = Sim(course);
          while (sim.s.state == RunState.running &&
              sim.s.frame < sim.totalFrames) {
            var threat = false;
            if (sim.s.grounded) {
              for (
                var x = sim.s.x.floor();
                x <= (sim.s.x + lookahead).ceil();
                x++
              ) {
                final col = course.at(x);
                threat = sim.s.side == Side.floor
                    ? col.floorSpike || col.isPit || col.floorTop > sim.s.y
                    : col.ceilSpike || col.ceilBottom(6) < sim.s.y + 0.8;
                if (threat) break;
              }
            }
            sim.step(tap: threat);
          }
          expect(
            sim.s.state,
            RunState.won,
            reason:
                '${level.id} lookahead=$lookahead died at ${sim.s.x}: ${sim.s.cause}',
          );
          expect(
            sim.flips.length,
            lessThanOrEqualTo(7),
            reason: 'not a constant-bounce tutorial',
          );
        },
      );
    }
  }

  test('all later tides still use byte-equivalent generator v1 chunks', () {
    for (final level in kCampaign.where((level) => level.tide > 1)) {
      final old = generate(level.spec);
      final current = level.buildCourse();
      expect(
        current.course.chunks.map((c) => c.name),
        old.course.chunks.map((c) => c.name),
      );
      expect(current.solution.flips, old.solution.flips);
      expect(level.recordRevision, 0);
      expect(level.recordKey, -(1 << 31) - kCampaign.indexOf(level));
    }
    expect(kGeneratorVersion, 1);
  });

  test(
    'new ghosts isolated without changing shipped star/save identifiers',
    () {
      expect(kCampaign.first.id, 't1l1');
      expect(kCampaign.first.recordRevision, 1);
      expect(kCampaign.first.recordKey, isNot(-(1 << 31)));
      expect(
        kCampaign.map((l) => l.recordKey).toSet().length,
        kCampaign.length,
      );
    },
  );

  test(
    'campaign sharing points to the actual level, never misleading Daily #0/code',
    () {
      final text = campaignShareText(
        level: kCampaign.first,
        attempts: 2,
        won: true,
        progress: 1,
      );
      expect(text, contains('First Light'));
      expect(text, contains('?level=t1l1'));
      expect(text, contains('2 tries'));
      expect(text, isNot(contains('Daily')));
      expect(text.length, lessThan(300));
    },
  );

  test('level-select display never invokes the generator or solver', () {
    final source = File('lib/ui/tides_screen.dart').readAsStringSync();
    expect(source, isNot(contains('generate(')));
    expect(source, isNot(contains('solve(')));
    expect(source, contains('level.estimatedSeconds'));
  });
}

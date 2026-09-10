import 'package:fliptide/sim/chunks.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:fliptide/sim/generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('course codes', () {
    test('round-trip for 2000 seeds', () {
      for (var i = 0; i < 2000; i++) {
        final packed = (i * 2654435761) & kCodeMask;
        final code = seedToCode(packed);
        expect(code.length, 6);
        expect(codeToSeed(code), packed, reason: code);
      }
    });
    test('tolerates lowercase, dashes and O/I/L/U confusions', () {
      final code = seedToCode(dailySeed(DateTime.utc(2026, 9, 2)));
      expect(codeToSeed(code.toLowerCase()), codeToSeed(code));
      expect(codeToSeed(prettyCode(code)), codeToSeed(code));
      expect(codeToSeed('O1ILUV'), codeToSeed('0111VV'));
      expect(codeToSeed('ABC'), isNull);
      expect(codeToSeed('ABCDE!'), isNull);
    });
    test('daily seeds fit in 27 bits; code carries version; same code → same course', () {
      final seed = dailySeed(DateTime.utc(2026, 9, 2));
      expect(seed & ~kSeedMask, 0);
      final g = generate(GenSpec(seed: seed));
      final code = seedToCode(g.course.seed);
      expect(codeVersion(codeToSeed(code)!), kGeneratorVersion);
      expect(codeSeed(codeToSeed(code)!), seed);
      final a = generate(GenSpec.fromCode(codeToSeed(code)!)).course;
      final b = generate(GenSpec.fromCode(codeToSeed(code)!)).course;
      expect(a.chunks.map((c) => c.name).toList(), b.chunks.map((c) => c.name).toList());
      expect(a.seed, g.course.seed);
    });
    test('generator v1 pool is frozen (adding chunks must go in a new version)', () {
      // Golden: if this fails you changed v1 — bump kGeneratorVersion and add a v2 pool instead.
      expect(kVersionPools[1]!.length, 23);
      for (final n in kVersionPools[1]!) {
        expect(chunkByName(n), isNotNull, reason: 'v1 pool references missing chunk $n');
      }
      // Golden sequence for one issued code (v1, seed 12345).
      final g = generate(const GenSpec(seed: 12345, version: 1));
      expect(seedToCode(g.course.seed), '400C1S');
      expect(g.course.chunks.map((c) => c.name).join(','),
          'start,step_then_hang,flat4,spike1,flat4,pit_short,flat4,ceil_spike1,flat6,ceiling_teeth,flat6,spike_both,flat4,spike_wall,flat4,ceil_spike1,flat4,spike1,flat4,teeth_both,flat6,tall_step,flat4,spike_both,flat6,ceiling_teeth,flat4,pit_spike_ceiling,flat6,finish');
    });
    test('unknown version is rejected', () {
      expect(() => generate(const GenSpec(seed: 1, version: 7)), throwsArgumentError);
    });
  });
}

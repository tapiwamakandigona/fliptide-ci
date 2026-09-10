// ignore_for_file: avoid_print
import 'package:fliptide/sim/campaign.dart';
import 'package:fliptide/sim/generator.dart';

void main() {
  for (final level in kTides.first.levels) {
    final g = level.buildCourse();
    print(
      '${level.id} ${level.name}: ${g.course.length} columns, '
      '${nominalSeconds(g.course).toStringAsFixed(1)}s, '
      'rerolls=${g.rerolls}, record=${level.recordKey}',
    );
  }
  // CPU-only probe of the removed menu work. Warm the VM first.
  for (var n = 0; n < 3; n++) {
    for (final level in kCampaign) {
      generate(level.spec);
    }
  }
  final before = <int>[], after = <int>[];
  for (var n = 0; n < 9; n++) {
    final watch = Stopwatch()..start();
    for (final level in kCampaign) {
      nominalSeconds(generate(level.spec).course);
    }
    before.add(watch.elapsedMicroseconds);
    watch.reset();
    for (final level in kCampaign) {
      level.estimatedSeconds.round();
    }
    after.add(watch.elapsedMicroseconds);
  }
  before.sort();
  after.sort();
  print(
    '30 duration labels, warmed host CPU, 9 repeats: '
    'before median=${before[4]}us; metadata median=${after[4]}us. '
    'Not phone FPS, GPU or cold-start evidence.',
  );
}

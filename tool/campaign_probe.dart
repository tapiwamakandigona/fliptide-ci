// ignore_for_file: avoid_print
// Prints, for each campaign level: chunk count, columns, rerolls, nominal seconds, flips in the optimal solution.
import 'package:fliptide/sim/campaign.dart';
import 'package:fliptide/sim/generator.dart';

void main() {
  for (final l in kCampaign) {
    final g = generate(l.spec);
    final tiers = <int, int>{};
    for (final c in g.course.chunks) {
      if (c.tier > 0) tiers[c.tier] = (tiers[c.tier] ?? 0) + 1;
    }
    print('${l.id.padRight(5)} ${l.name.padRight(12)} chunks=${g.course.chunks.length.toString().padLeft(3)} cols=${g.course.length.toString().padLeft(3)} '
        'rerolls=${g.rerolls.toString().padLeft(2)} secs=${nominalSeconds(g.course).toStringAsFixed(1).padLeft(5)} flips=${g.solution.flips.length.toString().padLeft(3)} tiers=$tiers');
  }
}

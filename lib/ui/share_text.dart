/// Wordle-style text share. Same string on web (clipboard) and Android (share
/// sheet). Must stay ≤ 300 chars and contain the game name (tested).
library;

import '../sim/physics.dart';
import '../sim/course.dart';
import '../sim/course_code.dart';

const String kGameName = 'Fliptide';
const String kShareUrl = 'tapiwamakandigona.github.io/fliptide-ci';

String shareText({
  required Course course,
  required int? dailyNumber,
  required double progress,
  required int attempts,
  required bool won,
  required int streak,
  int cells = 16,
}) {
  final code = seedToCode(course.seed);
  final pct = percentOf(progress);
  final reached = won ? cells : (progress * cells).floor().clamp(0, cells - 1);
  final sb = StringBuffer();
  for (var i = 0; i < cells; i++) {
    if (won) {
      sb.write('🟩');
    } else if (i < reached) {
      sb.write('🟨');
    } else if (i == reached) {
      sb.write('✗');
    } else {
      sb.write('⬛');
    }
  }
  final head = dailyNumber != null ? '$kGameName Daily #$dailyNumber' : '$kGameName course ${prettyCode(code)}';
  final result = won ? 'CLEARED in $attempts ${attempts == 1 ? "try" : "tries"}' : 'died at $pct% · attempt $attempts';
  final streakLine = streak > 1 ? '\n🔥 $streak-day streak' : '';
  final codeLine = dailyNumber != null ? '\ncode ${prettyCode(code)}' : '';
  return '$head\n$sb\n$result$streakLine$codeLine\n$kShareUrl';
}

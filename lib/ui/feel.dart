/// Haptics ("feel"). One light tick per flip, a firmer bump on death, a
/// heavy thump on a clear. No timers: every cue is a single platform call. Off by preference or wherever the platform has no
/// vibrator (web, desktop): HapticFeedback is a no-op there, so the gate is
/// purely the player's choice.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Feel {
  /// Mirrors Store.hapticsOn so the hot path never awaits a preference read.
  static bool enabled = true;

  /// Test seam: records instead of vibrating when set.
  static void Function(String kind)? sink;

  static Future<void> load() async {
    try {
      enabled =
          (await SharedPreferences.getInstance()).getBool('pref.haptics') ??
          true;
    } catch (_) {
      enabled = true;
    }
  }

  static void _fire(String kind, Future<void> Function() call) {
    if (!enabled) return;
    if (sink != null) {
      sink!(kind);
      return;
    }
    unawaited(call().catchError((_) {}));
  }

  static void tap() => _fire('tap', HapticFeedback.lightImpact);
  static void death() => _fire('death', HapticFeedback.mediumImpact);
  static void win() => _fire('win', HapticFeedback.heavyImpact);
  static void select() => _fire('select', HapticFeedback.selectionClick);
}

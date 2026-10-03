/// Sound for Fliptide: a tiny original chiptune soundtrack plus seven SFX,
/// all synthesised by `tool/audio/gen_audio.py` (no third-party samples).
///
/// The game code never talks to a plugin directly. It asks [FlipAudio] for a
/// cue; the real implementation ([PlayersAudio], `flip_audio_players.dart`)
/// plays it through `audioplayers`, and [RecordingAudio] stands in for tests
/// and for platforms where audio is unavailable. Every cue is fire-and-forget:
/// a failing player must never affect the sim or the UI.
library;

import 'package:flutter/foundation.dart';

/// Short one-shot effects. Names double as asset file names (`<name>.wav`).
enum Sfx { flip, land, death, win, star, tap, checkpoint }

/// Looping music. Names double as asset file names (`music_<name>.ogg`).
enum Track { title, run }

abstract class FlipAudio {
  /// The app-wide instance. `main()` installs the platform player; tests may
  /// swap in a [RecordingAudio]. Widgets prefer an injected instance when given.
  static FlipAudio instance = RecordingAudio();

  /// Player preferences. Persisted by the Store; mirrored here so a cue can be
  /// gated without an async read on the hot path.
  bool get musicEnabled;
  set musicEnabled(bool v);
  bool get sfxEnabled;
  set sfxEnabled(bool v);

  /// Play a one-shot. Cheap, may overlap, never awaited by callers.
  void sfx(Sfx s);

  /// Switch the music loop. `null` stops music. Calling with the current
  /// track is a no-op so screens can re-assert their track freely.
  void music(Track? t);

  /// App went to the background / came back.
  void pauseAll();
  void resumeAll();

  /// Web autoplay policy: browsers refuse to start audio before a user
  /// gesture. Screens call this from their first pointer-down so a music loop
  /// that was refused at build time gets a second chance.
  void userGesture();

  void dispose();
}

/// Records every cue instead of playing it. Used by tests and as the safe
/// default until the platform player is installed.
class RecordingAudio implements FlipAudio {
  final List<Sfx> sfxLog = [];
  final List<Track?> musicLog = [];
  int pauses = 0;
  int resumes = 0;
  int gestures = 0;
  Track? current;

  @override
  bool musicEnabled = true;
  @override
  bool sfxEnabled = true;

  @override
  void sfx(Sfx s) {
    if (sfxEnabled) sfxLog.add(s);
  }

  @override
  void music(Track? t) {
    if (t == current) return;
    current = t;
    musicLog.add(t);
  }

  @override
  void pauseAll() => pauses++;

  @override
  void resumeAll() => resumes++;

  @override
  void userGesture() => gestures++;

  @override
  void dispose() {}

  @visibleForTesting
  void clear() {
    sfxLog.clear();
    musicLog.clear();
    pauses = resumes = gestures = 0;
  }
}

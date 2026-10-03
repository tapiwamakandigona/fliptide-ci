/// `audioplayers`-backed [FlipAudio]. One looping player for music, a small
/// round-robin pool for SFX so quick flips can overlap without cutting each
/// other off. All plugin calls are wrapped: audio must never crash the game.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'flip_audio.dart';

/// Music sits under the effects; SFX are mastered louder in the assets.
const double kMusicVolume = 0.55;
const double kSfxVolume = 0.9;

class PlayersAudio implements FlipAudio {
  PlayersAudio({int poolSize = 4})
    : _pool = List.generate(poolSize, (_) => AudioPlayer());

  final AudioPlayer _music = AudioPlayer();
  final List<AudioPlayer> _pool;
  int _next = 0;
  Track? _current;
  bool _musicPlaying = false;
  bool _pausedByLifecycle = false;
  bool _configured = false;

  bool _musicEnabled = true;
  bool _sfxEnabled = true;

  @override
  bool get musicEnabled => _musicEnabled;

  /// Preference changes take effect immediately: switching music off stops
  /// the loop, switching it on restarts the current screen's track.
  @override
  set musicEnabled(bool v) {
    if (v == _musicEnabled) return;
    _musicEnabled = v;
    unawaited(_applyMusic());
  }

  @override
  bool get sfxEnabled => _sfxEnabled;

  @override
  set sfxEnabled(bool v) => _sfxEnabled = v;

  /// Configure the players once, lazily, off the first cue. `lowLatency`
  /// (SoundPool on Android) is what makes a flip blip land on the tap.
  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(kMusicVolume);
      if (!kIsWeb) {
        for (final p in _pool) {
          await p.setPlayerMode(PlayerMode.lowLatency);
        }
      }
      for (final p in _pool) {
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(kSfxVolume);
      }
    } catch (e) {
      debugPrint('audio configure failed: $e');
    }
  }

  @override
  void sfx(Sfx s) {
    if (!sfxEnabled) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    unawaited(() async {
      await _configure();
      try {
        // stop() first so a busy pool slot restarts cleanly instead of
        // ignoring the new cue.
        await p.stop();
        await p.play(AssetSource('audio/${s.name}.wav'), volume: kSfxVolume);
      } catch (e) {
        debugPrint('sfx ${s.name} failed: $e');
      }
    }());
  }

  @override
  void music(Track? t) {
    if (t == _current && (t == null || _musicPlaying || !musicEnabled)) return;
    _current = t;
    unawaited(_applyMusic());
  }

  Future<void> _applyMusic() async {
    await _configure();
    final t = _current;
    try {
      if (t == null || !musicEnabled) {
        _musicPlaying = false;
        await _music.stop();
        return;
      }
      await _music.stop();
      await _music.play(
        AssetSource('audio/music_${t.name}.ogg'),
        volume: kMusicVolume,
      );
      _musicPlaying = true;
    } catch (e) {
      // Typical on web before the first user gesture (autoplay policy).
      _musicPlaying = false;
      debugPrint('music ${t?.name} failed: $e');
    }
  }

  @override
  void userGesture() {
    if (_current != null && musicEnabled && !_musicPlaying) {
      unawaited(_applyMusic());
    }
  }

  @override
  void pauseAll() {
    if (!_musicPlaying) return;
    _pausedByLifecycle = true;
    unawaited(_music.pause().catchError((_) {}));
  }

  @override
  void resumeAll() {
    if (!_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    if (musicEnabled && _current != null) {
      unawaited(_music.resume().catchError((_) {}));
    }
  }

  @override
  void dispose() {
    unawaited(_music.dispose());
    for (final p in _pool) {
      unawaited(p.dispose());
    }
  }
}

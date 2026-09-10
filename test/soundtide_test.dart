// 0.4.0 "Soundtide": audio cues, haptics gate, settings persistence, star
// reveal, and The Deep (endless mode). Audio is recorded, never played.
import 'package:flame/game.dart';
import 'package:fliptide/audio/flip_audio.dart';
import 'package:fliptide/game/flip_game.dart';
import 'package:fliptide/main.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:fliptide/sim/deep.dart';
import 'package:fliptide/sim/physics.dart';
import 'package:fliptide/store/store.dart';
import 'package:fliptide/ui/feel.dart';
import 'package:fliptide/ui/settings_sheet.dart';
import 'package:fliptide/ui/share_text.dart';
import 'package:fliptide/ui/title_screen.dart';
import 'package:fliptide/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpUntil(WidgetTester tester, bool Function() done, {int maxFrames = 6000}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (done()) return;
  }
  fail('condition never met');
}

FlipGame _game(WidgetTester tester) => tester.widget<GameWidget<FlipGame>>(find.byType(GameWidget<FlipGame>)).game!;

void main() {
  late RecordingAudio audio;
  late List<String> haptics;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    audio = RecordingAudio();
    haptics = [];
    Feel.enabled = true;
    Feel.sink = haptics.add;
  });
  tearDown(() => Feel.sink = null);

  group('The Deep generator', () {
    test('is solvable, long, deterministic, and ramps in difficulty', () {
      final a = generateDeep(4242);
      final b = generateDeep(4242);
      expect(a.course.length, greaterThan(kDeepColumns));
      expect(a.course.length, b.course.length);
      expect(a.solution.flips, b.solution.flips, reason: 'same seed → same corridor');
      // The solver's run really clears it.
      final sim = Sim(a.course);
      final flips = a.solution.flips.toSet();
      while (sim.s.state == RunState.running) {
        sim.step(tap: flips.contains(sim.s.frame));
      }
      expect(sim.s.state, RunState.won);
      // Early corridor is tier-1 only; the last segment carries tier 3/4 chunks.
      final starts = a.course.chunkStarts;
      var earlyMax = 0, lateMax = 0;
      for (var i = 0; i < a.course.chunks.length; i++) {
        final tier = a.course.chunks[i].tier;
        if (starts[i] < kDeepSegmentColumns) earlyMax = tier > earlyMax ? tier : earlyMax;
        if (starts[i] > kDeepColumns - kDeepSegmentColumns) lateMax = tier > lateMax ? tier : lateMax;
      }
      expect(earlyMax, 1);
      expect(lateMax, greaterThanOrEqualTo(3));
      expect(generateDeep(1).solution.flips, isNot(generateDeep(2).solution.flips));
    });

    test('depth is whole metres clamped to the corridor', () {
      final g = generateDeep(9);
      expect(deepMetres(12.9, g.course), 12);
      expect(deepMetres(-3, g.course), 0);
      expect(deepMetres(1e9, g.course), g.course.length);
    });

    test('store records dives and keeps the best', () async {
      final s = await Store.open();
      expect(s.deepBest, 0);
      expect(await s.recordDive(40), isTrue);
      expect(await s.recordDive(30), isFalse);
      expect(await s.recordDive(41), isTrue);
      expect(s.deepBest, 41);
      expect(s.deepRuns, 3);
    });

    test('share text carries depth, best and the deep link', () {
      expect(deepShareText(metres: 88, best: 120, attempts: 3), contains('88 m · best 120 m · dive 3'));
      expect(deepShareText(metres: 120, best: 120, attempts: 3), contains('new best'));
      expect(deepShareText(metres: 5, best: 5, attempts: 1), endsWith('?deep=1'));
    });
  });

  group('preferences', () {
    test('sound, music and haptics default on and persist', () async {
      final s = await Store.open();
      expect(s.musicOn && s.sfxOn && s.hapticsOn, isTrue);
      await s.setMusicOn(false);
      await s.setHapticsOn(false);
      final again = await Store.open();
      expect(again.musicOn, isFalse);
      expect(again.sfxOn, isTrue);
      expect(again.hapticsOn, isFalse);
      expect(s.totalFlips, 0);
      await s.addFlips(7);
      await s.addFlips(0);
      expect(s.totalFlips, 7);
    });

    test('RecordingAudio honours the sfx gate and dedupes the track', () {
      audio.sfx(Sfx.flip);
      audio.sfxEnabled = false;
      audio.sfx(Sfx.death);
      audio.music(Track.run);
      audio.music(Track.run);
      audio.music(Track.title);
      expect(audio.sfxLog, [Sfx.flip]);
      expect(audio.musicLog, [Track.run, Track.title]);
    });

    test('Feel is silent when disabled', () {
      Feel.tap();
      Feel.enabled = false;
      Feel.death();
      expect(haptics, ['tap']);
    });
  });

  testWidgets('a run: run music, a flip blip + light haptic, then the death cue', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PlayScreen(seed: codeToSeed('400C1S'), autoplay: true, audio: audio)));
    await tester.pump();
    await tester.pump();
    expect(audio.musicLog, [Track.run]);
    await tester.tapAt(const Offset(195, 422)); // start; the solver plays
    await _pumpUntil(tester, () => audio.sfxLog.contains(Sfx.flip));
    expect(haptics, contains('tap'));
    // The solver wins this reference course: win cue + double haptic.
    await _pumpUntil(tester, () => find.text('CLEARED').evaluate().isNotEmpty);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16)); // session-break timer (400 ms)
    }
    expect(audio.sfxLog, contains(Sfx.win));
    expect(audio.sfxLog, contains(Sfx.land));
    expect(haptics, contains('win'));
    final store = await Store.open();
    expect(store.totalFlips, greaterThan(0));
  });

  testWidgets('death plays the death cue with a medium haptic', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PlayScreen(seed: codeToSeed('400C1S'), audio: audio)));
    await tester.pump();
    await tester.pump();
    await tester.tapAt(const Offset(195, 422));
    await _pumpUntil(tester, () => find.byKey(const Key('death-card')).evaluate().isNotEmpty);
    expect(audio.sfxLog.last, Sfx.death);
    expect(haptics, contains('death'));
  });

  testWidgets('The Deep: depth HUD, dive counter, new corridor on DIVE AGAIN, best persisted', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PlayScreen(deep: true, deepSeed: 77, audio: audio)));
    await tester.pump();
    await tester.pump();
    expect(find.text('THE DEEP'), findsWidgets);
    expect(find.byKey(const Key('hud-depth')), findsOneWidget);
    expect(find.byKey(const Key('hud-pct')), findsNothing);
    final game = _game(tester);
    final firstSeed = game.course.seed;
    await tester.tapAt(const Offset(195, 422)); // start, no flips → dies soon
    await _pumpUntil(tester, () => find.byKey(const Key('death-card')).evaluate().isNotEmpty);
    // Let the async best-depth write land.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final depthText = tester.widget<Text>(find.byKey(const Key('hud-depth'))).data!;
    final metres = int.parse(depthText.split(' ').first);
    expect(metres, greaterThan(0));
    expect(find.text('new best depth · tap anywhere to dive again'), findsOneWidget);
    final store = await Store.open();
    expect(store.deepBest, metres);
    expect(store.deepRuns, 1);
    // DIVE AGAIN replaces the corridor (new seed) without leaving the screen.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16)); // past the death-tap guard
    }
    await tester.tap(find.byKey(const Key('retry-btn')));
    await tester.pump();
    await tester.pump();
    expect(identical(game, _game(tester)), isTrue, reason: 'same game widget, new corridor');
    expect(game.course.seed, isNot(firstSeed));
    expect(game.attempts, 2, reason: 'the dive counter carries over');
    expect(game.sim.s.state, RunState.running);
    expect(find.byKey(const Key('death-card')), findsNothing);
    final depthAfter = int.parse(tester.widget<Text>(find.byKey(const Key('hud-depth'))).data!.split(' ').first);
    expect(depthAfter, lessThan(3), reason: 'depth restarts with the new corridor');
  });

  testWidgets('title: THE DEEP button, settings sheet toggles persist and gate audio', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: TitleScreen(audio: audio)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50)); // the wordmark bobs forever: no pumpAndSettle
    }
    expect(audio.musicLog, [Track.title]);
    expect(find.byKey(const Key('title-deep')), findsOneWidget);
    expect(find.text('endless · no finish line'), findsOneWidget);
    await tester.tap(find.byKey(const Key('title-settings')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(SettingsSheet), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-music')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings-haptics')));
    await tester.pump();
    expect(audio.musicEnabled, isFalse);
    expect(Feel.enabled, isFalse);
    final store = await Store.open();
    expect(store.musicOn, isFalse);
    expect(store.hapticsOn, isFalse);
    expect(store.sfxOn, isTrue);
  });

  testWidgets('CLEARED stars pop in one at a time; still under reduce-motion', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: StarRow(earned: 3, size: 30, animate: true))));
    // Before the first reveal delay every star is at (near) zero opacity.
    await tester.pump(const Duration(milliseconds: 100));
    final early = tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity).toList();
    expect(early.length, 3);
    expect(early.every((o) => o < 0.05), isTrue, reason: 'stars must not be visible before the reveal delay');
    await tester.pump(const Duration(milliseconds: 1400));
    final late = tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity).toList();
    expect(late.every((o) => o > 0.99), isTrue);
    // Reduce-motion: plain icons, no animation wrappers.
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: Center(child: StarRow(earned: 2, size: 30, animate: true))),
    ));
    expect(find.byType(Opacity), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
  });
}

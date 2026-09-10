/// Title screen — the front door. Play (next Tide level), the Tides map,
/// today's Daily, and a course code. Cross-promo footer per directive 05b.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/flip_audio.dart';
import '../game/palette.dart';
import '../iap/iap_service.dart';
import '../iap/iap_service_platform.dart';
import '../main.dart' show PlayScreen;
import '../sim/campaign.dart';
import '../sim/course_code.dart';
import '../sim/generator.dart';
import '../store/store.dart';
import 'feel.dart';
import 'more_games.dart';
import 'settings_sheet.dart';
import 'supporter_row.dart';
import 'tides_screen.dart';
import 'widgets.dart';
import 'language.dart';
import 'title_backdrop.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key, this.iapService, this.audio});

  /// Injected in tests; null → platform default (Play Billing on Android, no-op elsewhere).
  final IapService? iapService;

  /// Injected in tests; null → the app-wide [FlipAudio.instance].
  final FlipAudio? audio;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  Store? _store;
  late final IapService _iap = widget.iapService ?? createIapService();
  FlipAudio get _audio => widget.audio ?? FlipAudio.instance;

  @override
  void dispose() {
    _iap.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Store.open().then((s) {
      if (!mounted) return;
      // Preferences gate the cues before the first one plays.
      _audio.musicEnabled = s.musicOn;
      _audio.sfxEnabled = s.sfxOn;
      Feel.enabled = s.hapticsOn;
      setState(() => _store = s);
      _audio.music(Track.title);
    });
  }

  Future<void> _go(Widget page) async {
    _audio.sfx(Sfx.tap);
    Feel.select();
    await Navigator.of(context).push(fadeRoute(page));
    if (!mounted) return;
    _audio.music(Track.title); // back from a run: the title loop returns
    setState(() {}); // stars / streak / depth may have changed
  }

  Future<void> _enterCode() async {
    final code = await promptCourseCode(context);
    if (code == null || !mounted) return;
    final seed = codeToSeed(code);
    if (seed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ft(context, 'That code is not valid'))),
      );
      return;
    }
    _go(PlayScreen(seed: seed));
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final today = DateTime.now().toUtc();
    final dailyNo = dailyNumber(today);
    final daily = store?.daily(dailyNo);
    final next = store?.nextCampaignLevel;
    final allDone = store != null && store.levelsCleared == kCampaign.length;
    return Scaffold(
      // Browsers only start audio after a gesture: the first touch anywhere on
      // the title re-asserts the loop that was refused at build time.
      body: Listener(
        onPointerDown: (_) => _audio.userGesture(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
        fit: StackFit.expand,
        children: [
          const TitleBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxHeight < 640;
                return SingleChildScrollView(
                  key: const Key('title-scroll'),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const Spacer(flex: 3),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: FloatingWordmark(),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ft(context, 'one tap flips gravity'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Palette.textDim,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(flex: 2),
                          if (store != null) ...[
                            _StatsRow(
                              stars: store.totalStars,
                              cleared: store.levelsCleared,
                              streak: store.streak,
                            ),
                            SizedBox(height: compact ? 12 : 22),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              children: [
                                BigButton(
                                  key: const Key('title-play'),
                                  label: ft(
                                    context,
                                    allDone ? 'REPLAY THE TIDES' : 'PLAY',
                                  ),
                                  sub: next == null
                                      ? null
                                      : (allDone
                                            ? ft(
                                                context,
                                                'all 30 courses cleared',
                                              )
                                            : '${ft(context, 'TIDE {number}', args: {'number': next.tide}).toLowerCase()} · ${next.index}  ·  ${ft(context, next.name)}'),
                                  primary: true,
                                  onTap: store == null
                                      ? null
                                      : () => _go(
                                          PlayScreen(
                                            level: allDone
                                                ? kCampaign.first
                                                : next,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 10),
                                BigButton(
                                  key: const Key('title-tides'),
                                  label: ft(context, 'THE TIDES'),
                                  sub: store == null
                                      ? null
                                      : '${store.levelsCleared}/${kCampaign.length} courses  ·  ${store.totalStars}★',
                                  onTap: store == null
                                      ? null
                                      : () => _go(const TidesScreen()),
                                ),
                                const SizedBox(height: 10),
                                BigButton(
                                  key: const Key('title-deep'),
                                  label: ft(context, 'THE DEEP'),
                                  sub: store == null
                                      ? null
                                      : store.deepBest == 0
                                      ? ft(context, 'endless · no finish line')
                                      : '${ft(context, 'best')} ${store.deepBest} m  ·  ${store.deepRuns} ${ft(context, store.deepRuns == 1 ? 'dive' : 'dives')}',
                                  onTap: store == null
                                      ? null
                                      : () => _go(const PlayScreen(deep: true)),
                                ),
                                const SizedBox(height: 10),
                                BigButton(
                                  key: const Key('title-daily'),
                                  label: ft(
                                    context,
                                    'DAILY #{number}',
                                    args: {'number': dailyNo},
                                  ),
                                  sub: daily == null
                                      ? null
                                      : daily.won
                                      ? 'cleared in ${daily.attempts} ${daily.attempts == 1 ? "try" : "tries"}  ·  same course for everyone'
                                      : daily.attempts == 0
                                      ? ft(
                                          context,
                                          'same course for everyone today',
                                        )
                                      : 'best ${(daily.best * 100).floor()}%  ·  ${daily.attempts} attempts',
                                  onTap: store == null
                                      ? null
                                      : () => _go(const PlayScreen()),
                                  trailing: daily != null && daily.won
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: Palette.finish,
                                          size: 22,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SmallButton(
                                        key: const Key('title-code'),
                                        label: ft(context, 'COURSE CODE'),
                                        icon: Icons.tag_rounded,
                                        onTap: _enterCode,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      key: const Key('title-language'),
                                      tooltip: ft(context, 'Language'),
                                      icon: const Icon(
                                        Icons.language,
                                        color: Palette.textDim,
                                      ),
                                      onPressed: () =>
                                          showFlipLanguage(context),
                                    ),
                                    IconButton(
                                      key: const Key('title-settings'),
                                      tooltip: ft(context, 'SETTINGS'),
                                      icon: const Icon(
                                        Icons.settings_rounded,
                                        color: Palette.textDim,
                                      ),
                                      onPressed: store == null
                                          ? null
                                          : () async {
                                              _audio.sfx(Sfx.tap);
                                              await showFlipSettings(context, store, audio: _audio);
                                              if (mounted) setState(() {});
                                            },
                                    ),
                                  ],
                                ),
                                // Supporter unlock (02O-1): only where a store exists (Android).
                                if (store != null && _iap.supported) ...[
                                  const SizedBox(height: 10),
                                  SupporterRow(iap: _iap, store: store),
                                ],
                              ],
                            ),
                          ),
                          const Spacer(flex: 3),
                          const MoreFromTsoro(),
                          const SizedBox(height: 6),
                          const Text(
                            'TSORO STUDIOS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: Palette.slabEdge,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// Route transition for title ↔ run: a quick fade, so the corridor does not
/// slide in from the side like a settings page. The framework scales the
/// duration down under reduce-motion.
PageRoute<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 220),
  reverseTransitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, anim, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
    child: child,
  ),
);

/// The wordmark bobbing on a slow swell (±3 px, 4 s). Static under
/// reduce-motion / accessible navigation, like the backdrop.
class FloatingWordmark extends StatefulWidget {
  const FloatingWordmark({super.key});

  @override
  State<FloatingWordmark> createState() => _FloatingWordmarkState();
}

class _FloatingWordmarkState extends State<FloatingWordmark> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    if (still) {
      _c.stop();
      return const FliptideWordmark();
    }
    if (!_c.isAnimating) _c.repeat();
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, math.sin(_c.value * 2 * math.pi) * 3),
        child: child,
      ),
      child: const FliptideWordmark(),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.stars,
    required this.cleared,
    required this.streak,
  });
  final int stars;
  final int cleared;
  final int streak;

  @override
  Widget build(BuildContext context) {
    // Wrap, not Row: three chips fit one line on every real phone, but a wide
    // fallback font (or a 320-wide screen) drops the third onto a second line
    // instead of overflowing.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          StatChip(
            icon: Icons.star_rounded,
            color: Palette.player,
            value: '$stars',
            label: ft(context, 'stars'),
          ),
          StatChip(
            icon: Icons.flag_rounded,
            color: Palette.finish,
            value: '$cleared',
            label: ft(context, 'cleared'),
          ),
          StatChip(
            icon: Icons.local_fire_department_rounded,
            color: Palette.spike,
            value: '$streak',
            label: ft(context, streak == 1 ? 'day' : 'days'),
          ),
        ],
      ),
    );
  }
}

/// The wordmark: "Flip" upright, "tide" mirrored on the ceiling — the whole
/// game in one glyph. Pure text, so it ships with the font already bundled.
class FliptideWordmark extends StatelessWidget {
  const FliptideWordmark({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: -size * 0.04,
      color: Palette.player,
      shadows: [
        Shadow(
          color: Palette.player.withValues(alpha: 0.35),
          blurRadius: size * 0.5,
        ),
      ],
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Flip', style: style),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(1, -1, 1),
            child: Text(
              'tide',
              style: style.copyWith(
                color: Palette.text,
                shadows: [
                  Shadow(
                    color: Palette.text.withValues(alpha: 0.25),
                    blurRadius: size * 0.5,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

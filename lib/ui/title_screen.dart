/// Title screen — the front door. Play (next Tide level), the Tides map,
/// today's Daily, and a course code. Cross-promo footer per directive 05b.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../iap/iap_service.dart';
import '../iap/iap_service_platform.dart';
import '../main.dart' show PlayScreen;
import '../sim/campaign.dart';
import '../sim/course_code.dart';
import '../sim/generator.dart';
import '../store/store.dart';
import 'more_games.dart';
import 'supporter_row.dart';
import 'tides_screen.dart';
import 'widgets.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key, this.iapService});

  /// Injected in tests; null → platform default (Play Billing on Android, no-op elsewhere).
  final IapService? iapService;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  Store? _store;
  late final IapService _iap = widget.iapService ?? createIapService();

  @override
  void dispose() {
    _iap.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Store.open().then((s) {
      if (mounted) setState(() => _store = s);
    });
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {}); // stars / streak may have changed
  }

  Future<void> _enterCode() async {
    final code = await promptCourseCode(context);
    if (code == null || !mounted) return;
    final seed = codeToSeed(code);
    if (seed == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That code is not valid')));
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _TitleBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxHeight < 640;
                return Column(
                  children: [
                    const Spacer(flex: 3),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: FliptideWordmark()),
                    const SizedBox(height: 6),
                    const Text(
                      'one tap flips gravity',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.textDim, letterSpacing: 0.5),
                    ),
                    const Spacer(flex: 2),
                    if (store != null) ...[_StatsRow(stars: store.totalStars, cleared: store.levelsCleared, streak: store.streak), SizedBox(height: compact ? 12 : 22)],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          BigButton(
                            key: const Key('title-play'),
                            label: allDone ? 'REPLAY THE TIDES' : 'PLAY',
                            sub: next == null ? null : (allDone ? 'all 30 courses cleared' : '${next.label.toLowerCase()}  ·  ${next.name}'),
                            primary: true,
                            onTap: store == null ? null : () => _go(PlayScreen(level: allDone ? kCampaign.first : next)),
                          ),
                          const SizedBox(height: 10),
                          BigButton(
                            key: const Key('title-tides'),
                            label: 'THE TIDES',
                            sub: store == null ? null : '${store.levelsCleared}/${kCampaign.length} courses  ·  ${store.totalStars}★',
                            onTap: store == null ? null : () => _go(const TidesScreen()),
                          ),
                          const SizedBox(height: 10),
                          BigButton(
                            key: const Key('title-daily'),
                            label: 'DAILY #$dailyNo',
                            sub: daily == null
                                ? null
                                : daily.won
                                ? 'cleared in ${daily.attempts} ${daily.attempts == 1 ? "try" : "tries"}  ·  same course for everyone'
                                : daily.attempts == 0
                                ? 'same course for everyone today'
                                : 'best ${(daily.best * 100).floor()}%  ·  ${daily.attempts} attempts',
                            onTap: store == null ? null : () => _go(const PlayScreen()),
                            trailing: daily != null && daily.won ? const Icon(Icons.check_circle_rounded, color: Palette.finish, size: 22) : null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: SmallButton(key: const Key('title-code'), label: 'COURSE CODE', icon: Icons.tag_rounded, onTap: _enterCode),
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
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3, color: Palette.slabEdge),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stars, required this.cleared, required this.streak});
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
          StatChip(icon: Icons.star_rounded, color: Palette.player, value: '$stars', label: 'stars'),
          StatChip(icon: Icons.flag_rounded, color: Palette.finish, value: '$cleared', label: 'cleared'),
          StatChip(icon: Icons.local_fire_department_rounded, color: Palette.spike, value: '$streak', label: streak == 1 ? 'day' : 'days'),
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
      shadows: [Shadow(color: Palette.player.withValues(alpha: 0.35), blurRadius: size * 0.5)],
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
                shadows: [Shadow(color: Palette.text.withValues(alpha: 0.25), blurRadius: size * 0.5)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two corridor bands, a slow drift of dust, a faint grid — the game's own
/// look, so the menu and the run are one place.
class _TitleBackdrop extends StatefulWidget {
  const _TitleBackdrop();

  @override
  State<_TitleBackdrop> createState() => _TitleBackdropState();
}

class _TitleBackdropState extends State<_TitleBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(painter: _BackdropPainter(_c.value)),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Palette.bg);
    final band = size.height * 0.16;
    final corridor = Rect.fromLTWH(0, band, size.width, size.height - band * 2);
    canvas.drawRect(corridor, Paint()..color = Palette.corridor);
    // Grid pillars, drifting slowly to the left.
    final tile = size.width / 9;
    final shift = (t * tile * 2) % tile;
    final grid = Paint()
      ..color = Palette.grid
      ..strokeWidth = 1;
    for (var x = -shift; x < size.width; x += tile) {
      canvas.drawLine(Offset(x, corridor.top), Offset(x, corridor.bottom), grid);
    }
    // Floor / ceiling slabs.
    final slab = Paint()..color = Palette.slabEdge;
    canvas.drawRect(Rect.fromLTWH(0, corridor.top - 3, size.width, 3), slab);
    canvas.drawRect(Rect.fromLTWH(0, corridor.bottom, size.width, 3), slab);
    // Dust motes.
    final rnd = math.Random(7);
    final dust = Paint()..color = Palette.dust.withValues(alpha: 0.35);
    for (var i = 0; i < 40; i++) {
      final speed = 0.3 + rnd.nextDouble() * 0.7;
      final x = ((rnd.nextDouble() - t * speed) % 1 + 1) % 1 * size.width;
      final y = corridor.top + rnd.nextDouble() * corridor.height;
      canvas.drawCircle(Offset(x, y), 1 + rnd.nextDouble() * 1.5, dust);
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => old.t != t;
}

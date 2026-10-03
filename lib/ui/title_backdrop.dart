import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/palette.dart';

/// Same corridor identity without rebuilding the title at display refresh rate.
/// OS reduced motion parks the only clock; navigating away mutes its ticker.
class TitleBackdrop extends StatefulWidget {
  const TitleBackdrop({super.key});

  @override
  State<TitleBackdrop> createState() => _TitleBackdropState();
}

class _TitleBackdropState extends State<TitleBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  late final _BackdropPainter _painter = _BackdropPainter(_clock);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _clock.stop();
      _clock.value = 0;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: const Key('title-backdrop-layer'),
    child: CustomPaint(painter: _painter),
  );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;
  final _background = Paint()..color = Palette.bg;
  final _corridor = Paint()..color = Palette.corridor;
  final _grid = Paint()..color = Palette.grid;
  final _slab = Paint()..color = Palette.slabEdge;
  final _dust = Paint()..color = Palette.dust.withValues(alpha: 0.35);
  static final _motes = _makeMotes();

  static List<({double speed, double x, double y, double radius})>
  _makeMotes() {
    final random = math.Random(7);
    return List.generate(
      40,
      (_) => (
        speed: 0.3 + random.nextDouble() * 0.7,
        x: random.nextDouble(),
        y: random.nextDouble(),
        radius: 1 + random.nextDouble() * 1.5,
      ),
      growable: false,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = clock.value;
    canvas.drawRect(Offset.zero & size, _background);
    final band = size.height * 0.16;
    final corridor = Rect.fromLTWH(0, band, size.width, size.height - band * 2);
    canvas.drawRect(corridor, _corridor);
    final tile = size.width / 9;
    final shift = (t * tile * 2) % tile;
    for (var x = -shift; x < size.width; x += tile) {
      canvas.drawLine(
        Offset(x, corridor.top),
        Offset(x, corridor.bottom),
        _grid,
      );
    }
    canvas.drawRect(Rect.fromLTWH(0, corridor.top - 3, size.width, 3), _slab);
    canvas.drawRect(Rect.fromLTWH(0, corridor.bottom, size.width, 3), _slab);
    for (final mote in _motes) {
      final x = ((mote.x - t * mote.speed) % 1 + 1) % 1 * size.width;
      canvas.drawCircle(
        Offset(x, corridor.top + mote.y * corridor.height),
        mote.radius,
        _dust,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.clock != clock;
}

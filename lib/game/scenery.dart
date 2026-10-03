/// Tidelight scenery (0.4.1, render-only): the space outside the corridor
/// used to be two flat navy slabs, which on a phone in portrait is most of
/// the screen. Now the ceiling carries a night coast (stars, a moon, two
/// ridges and the dark lighthouse from the intro line) and the floor sits on
/// a moonlit sea with slow waves.
///
/// Rules this file keeps: nothing here touches the simulation or input;
/// no randomness at runtime (positions come from a fixed hash, motion from
/// the camera and the game clock), so screenshots are repeatable; paths and
/// shaders are rebuilt only on resize; a frame costs roughly 20 draw calls.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

class Scenery {
  // Palette (kept here: scenery colours never feed gameplay reads).
  static const skyTop = Color(0xFF070A14);
  static const skyLow = Color(0xFF18203C);
  static const ridgeFar = Color(0xFF141B33);
  static const ridgeNear = Color(0xFF0F1528);
  static const seaTop = Color(0xFF12203A);
  static const seaDeep = Color(0xFF060911);
  static const starTint = Color(0xFFE8ECFF);
  static const moonTint = Color(0xFFF3EFD8);
  static const waveTint = Color(0xFF7FB8FF);

  static const int starCount = 70;
  static const int _starBuckets = 3;

  double _w = -1, _vh = -1, _top = -1, _bot = -1, _t = -1;

  final Paint _sky = Paint();
  final Paint _sea = Paint();
  final Paint _ridgeFarPaint = Paint()..color = ridgeFar;
  final Paint _ridgeNearPaint = Paint()..color = ridgeNear;
  final Paint _window = Paint()..color = const Color(0xFF2A3354);
  final Paint _moonHalo = Paint();
  final Paint _moonDisc = Paint()..color = moonTint;
  final Paint _glint = Paint()
    ..strokeCap = StrokeCap.round
    ..color = moonTint.withValues(alpha: 0.18);
  final List<Paint> _starPaints = [
    for (var b = 0; b < _starBuckets; b++)
      Paint()
        ..strokeCap = StrokeCap.round
        ..color = starTint.withValues(alpha: 0.28 + 0.36 * b),
  ];
  final List<Float32List> _starBuf = [
    for (var b = 0; b < _starBuckets; b++) Float32List(starCount * 2),
  ];
  final List<int> _starFill = List.filled(_starBuckets, 0);
  final List<Paint> _wavePaints = [
    for (final a in [0.20, 0.13, 0.08])
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = waveTint.withValues(alpha: a),
  ];

  Path _ridgeFarPath = Path(), _ridgeNearPath = Path(), _lighthouse = Path();
  Rect _lighthouseWindow = Rect.zero;
  final List<Path> _wavePaths = [Path(), Path(), Path()];
  final List<double> _waveLen = [1, 1, 1];
  final List<double> _waveY = [0, 0, 0];
  double _ridgePeriod = 1, _lighthousePeriod = 1, _starStrip = 1;
  Offset _moon = Offset.zero;
  double _moonR = 0;
  bool _hasSky = false, _hasSea = false;

  /// Screen-space moon centre (tests and the sea glint use it).
  Offset get moon => _moon;
  bool get hasSky => _hasSky;
  bool get hasSea => _hasSea;

  static int _hash(int n) {
    var x = (n + 0x9E3779B9) * 0x45d9f3b;
    x = ((x >> 16) ^ x) * 0x45d9f3b;
    x = (x >> 16) ^ x;
    return x & 0x7fffffff;
  }

  static double _unit(int n) => _hash(n) / 0x7fffffff;

  void _rebuild(double w, double vh, double t, double top, double bot) {
    _w = w;
    _vh = vh;
    _t = t;
    _top = top;
    _bot = bot;
    _hasSky = top > t * 0.9;
    _hasSea = vh - bot > t * 0.9;
    _sky.shader = Gradient.linear(Offset.zero, Offset(0, top), [
      skyTop,
      skyLow,
    ]);
    _sea.shader = Gradient.linear(Offset(0, bot), Offset(0, vh), [
      seaTop,
      seaDeep,
    ]);

    // Ridges: periodic sums of integer-frequency sines, so each path tiles
    // seamlessly every [_ridgePeriod] px.
    _ridgePeriod = math.max(w, 360.0);
    final amp = math.min(top * 0.34, t * 2.6);
    Path ridge(double base, double height, List<(int, double, double)> waves) {
      final p = Path()..moveTo(0, base);
      const steps = 48;
      for (var i = 0; i <= steps; i++) {
        final x = _ridgePeriod * i / steps;
        var y = 0.0;
        for (final (k, a, ph) in waves) {
          y +=
              a *
              (0.5 + 0.5 * math.sin(2 * math.pi * k * x / _ridgePeriod + ph));
        }
        p.lineTo(x, base - height * y);
      }
      return p
        ..lineTo(_ridgePeriod, base)
        ..close();
    }

    _ridgeFarPath = ridge(top, amp, [
      (2, 0.55, 0.3),
      (5, 0.3, 1.7),
      (9, 0.15, 4.1),
    ]);
    _ridgeNearPath = ridge(top, amp * 0.62, [
      (3, 0.6, 2.2),
      (7, 0.28, 0.4),
      (13, 0.12, 5.3),
    ]);

    // The dark lighthouse on its headland, drawn once per long period.
    _lighthousePeriod = _ridgePeriod * 2.5;
    final lhH = math.min(amp * 1.35, t * 3.2);
    final lhW = lhH * 0.2;
    final baseY = top - amp * 0.22;
    _lighthouse = Path()
      ..moveTo(-lhW * 0.5, baseY)
      ..lineTo(-lhW * 0.32, baseY - lhH * 0.78)
      ..lineTo(-lhW * 0.46, baseY - lhH * 0.78) // gallery
      ..lineTo(-lhW * 0.46, baseY - lhH * 0.83)
      ..lineTo(-lhW * 0.26, baseY - lhH * 0.83)
      ..lineTo(-lhW * 0.26, baseY - lhH * 0.94) // lamp room
      ..lineTo(0, baseY - lhH) // dome
      ..lineTo(lhW * 0.26, baseY - lhH * 0.94)
      ..lineTo(lhW * 0.26, baseY - lhH * 0.83)
      ..lineTo(lhW * 0.46, baseY - lhH * 0.83)
      ..lineTo(lhW * 0.46, baseY - lhH * 0.78)
      ..lineTo(lhW * 0.32, baseY - lhH * 0.78)
      ..lineTo(lhW * 0.5, baseY)
      ..close();
    _lighthouseWindow = Rect.fromCenter(
      center: Offset(0, baseY - lhH * 0.885),
      width: lhW * 0.34,
      height: lhH * 0.06,
    );

    // Moon high on the sky side, away from the player column (x = 32 %).
    _moonR = math.max(4, math.min(w, top) * 0.055);
    _moon = Offset(w * 0.8, math.max(_moonR * 2.2, top * 0.26));
    _moonHalo.shader = Gradient.radial(
      _moon,
      _moonR * 4.5,
      [
        moonTint.withValues(alpha: 0.16),
        moonTint.withValues(alpha: 0.05),
        moonTint.withValues(alpha: 0),
      ],
      [0, 0.4, 1],
    );

    _starStrip = math.max(w, 360.0) * 1.3;

    // Waves: one sine polyline per band, one wavelength wider than the view.
    final seaH = vh - bot;
    for (var i = 0; i < 3; i++) {
      final len = t * (3.4 + i * 1.6);
      _waveLen[i] = len;
      _waveY[i] = bot + seaH * (0.12 + 0.2 * i + 0.05 * i * i);
      final a = t * (0.09 + 0.04 * i);
      final p = Path();
      final span = w + len * 2;
      const perLen = 16;
      final n = (span / len * perLen).ceil();
      for (var s = 0; s <= n; s++) {
        final x = s * len / perLen;
        final y = a * math.sin(2 * math.pi * x / len);
        if (s == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      _wavePaths[i] = p;
      _wavePaints[i].strokeWidth = math.max(1.2, t * (0.05 - i * 0.01));
    }
    _glint.strokeWidth = math.max(1.5, t * 0.06);
    for (final sp in _starPaints) {
      sp.strokeWidth = math.max(1.4, t * 0.045);
    }
  }

  /// Draw sky (0..[top]) and sea ([bot]..[vh]). [camX] is the camera in
  /// tiles, [clock] the game clock in seconds.
  void render(
    Canvas canvas, {
    required double w,
    required double vh,
    required double t,
    required double top,
    required double bot,
    required double camX,
    required double clock,
  }) {
    // A zero-size view (hidden embed, split-screen transition) has nothing to
    // draw, and a zero tile would make the wave paths divide 0 by 0.
    if (w <= 0 || vh <= 0 || t <= 0) return;
    if (w != _w || vh != _vh || t != _t || top != _top || bot != _bot) {
      _rebuild(w, vh, t, top, bot);
    }
    final camPx = camX * t;
    if (_hasSky) _renderSky(canvas, w, top, camPx, clock);
    if (_hasSea) _renderSea(canvas, w, vh, bot, camPx, clock);
  }

  void _renderSky(
    Canvas canvas,
    double w,
    double top,
    double camPx,
    double clock,
  ) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, top));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, top), _sky);

    // Stars: fixed hashed layout, barely drifting (parallax 0.02), twinkling
    // in three alpha buckets = three batched calls.
    for (var b = 0; b < _starBuckets; b++) {
      _starFill[b] = 0;
    }
    final drift = camPx * 0.02;
    // Keep the top band (course title, progress, attempt counter) clear.
    final starMinY = top * 0.24;
    final starMaxY = top * 0.74;
    for (var i = 0; i < starCount; i++) {
      var x = (_unit(i * 3) * _starStrip - drift) % _starStrip;
      if (x < 0) x += _starStrip;
      if (x > w) continue;
      final y = starMinY + _unit(i * 3 + 1) * (starMaxY - starMinY);
      final tw =
          0.5 + 0.5 * math.sin(clock * (0.6 + _unit(i * 3 + 2) * 1.8) + i);
      final b = (tw * _starBuckets).floor().clamp(0, _starBuckets - 1);
      final n = _starFill[b];
      _starBuf[b]
        ..[n] = x
        ..[n + 1] = y;
      _starFill[b] = n + 2;
    }
    for (var b = 0; b < _starBuckets; b++) {
      final n = _starFill[b];
      if (n > 0) {
        canvas.drawRawPoints(
          PointMode.points,
          Float32List.sublistView(_starBuf[b], 0, n),
          _starPaints[b],
        );
      }
    }

    canvas.drawCircle(_moon, _moonR * 4.5, _moonHalo);
    canvas.drawCircle(_moon, _moonR, _moonDisc);

    _tile(canvas, _ridgeFarPath, _ridgePeriod, camPx * 0.06, w, _ridgeFarPaint);
    // Lighthouse between the ridges (parallax 0.09), one per long period.
    var lx = (_lighthousePeriod * 0.55 - camPx * 0.09) % _lighthousePeriod;
    if (lx < 0) lx += _lighthousePeriod;
    for (final x in [lx, lx - _lighthousePeriod]) {
      if (x > -_t * 2 && x < w + _t * 2) {
        canvas.save();
        canvas.translate(x, 0);
        canvas.drawPath(_lighthouse, _ridgeNearPaint);
        canvas.drawRect(_lighthouseWindow, _window);
        canvas.restore();
      }
    }
    _tile(
      canvas,
      _ridgeNearPath,
      _ridgePeriod,
      camPx * 0.12,
      w,
      _ridgeNearPaint,
    );
    canvas.restore();
  }

  void _renderSea(
    Canvas canvas,
    double w,
    double vh,
    double bot,
    double camPx,
    double clock,
  ) {
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, bot, w, vh));
    canvas.drawRect(Rect.fromLTRB(0, bot, w, vh), _sea);
    // Waves: the nearest band moves fastest (parallax + a slow swell).
    for (var i = 0; i < 3; i++) {
      final len = _waveLen[i];
      final factor = 0.42 - i * 0.12;
      var off = (camPx * factor + clock * _t * (0.35 - i * 0.08)) % len;
      if (off < 0) off += len;
      canvas.save();
      canvas.translate(-off - len, _waveY[i]);
      canvas.drawPath(_wavePaths[i], _wavePaints[i]);
      canvas.restore();
    }
    // Moon glint: a broken column of light under the moon.
    final gx = _moon.dx;
    final seaH = vh - bot;
    for (var k = 0; k < 5; k++) {
      final y = bot + seaH * (0.1 + k * 0.13);
      final half =
          _t *
          (0.55 - k * 0.07) *
          (0.6 + 0.4 * math.sin(clock * 1.7 + k * 1.3));
      if (half <= 0.5) continue;
      canvas.drawLine(Offset(gx - half, y), Offset(gx + half, y), _glint);
    }
    canvas.restore();
  }

  void _tile(
    Canvas canvas,
    Path p,
    double period,
    double scroll,
    double w,
    Paint paint,
  ) {
    var x = -(scroll % period);
    if (x > 0) x -= period;
    for (; x < w; x += period) {
      canvas.save();
      canvas.translate(x, 0);
      canvas.drawPath(p, paint);
      canvas.restore();
    }
  }
}

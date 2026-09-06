/// Renders the share card as a PNG with dart:ui — no widget tree needed.
/// 1080×1080: safe for every chat app; the course map is the hook.
library;

import '../sim/physics.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../game/palette.dart';
import '../sim/course.dart';

class ShareCardData {
  const ShareCardData({
    required this.dailyNumber,
    required this.progress,
    required this.attempts,
    required this.course,
    required this.won,
    required this.streak,
    this.deathXs = const [],
  });
  final int dailyNumber;
  final double progress;
  final int attempts;
  final Course course;
  final bool won;
  final int streak;

  /// Every death x of today (tiny ticks under the map).
  final List<double> deathXs;
}

Future<Uint8List> renderShareCard(ShareCardData d) async {
  const size = 1080.0;
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, size, size), Paint()..color = Palette.bg);

  void text(String s, double x, double y, double fs, {Color color = Palette.text, FontWeight w = FontWeight.w800, TextAlign align = TextAlign.left, double maxW = size - 160}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: 'Inter', color: color, fontSize: fs, fontWeight: w, letterSpacing: fs > 100 ? -4 : 0)),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxW);
    final dx = align == TextAlign.center ? x - tp.width / 2 : (align == TextAlign.right ? x - tp.width : x);
    tp.paint(c, Offset(dx, y));
  }

  text('FLIPTIDE', 80, 70, 64, color: Palette.player);
  text('DAILY #${d.dailyNumber}', size - 80, 84, 40, color: Palette.textDim, align: TextAlign.right);

  final pct = percentOf(d.progress);
  if (d.won) {
    text('CLEARED', size / 2, 230, 170, color: Palette.finish, align: TextAlign.center);
  } else {
    text('$pct%', size / 2, 200, 260, align: TextAlign.center);
  }
  text(d.won ? 'in ${d.attempts} ${d.attempts == 1 ? "attempt" : "attempts"}' : 'attempt ${d.attempts} · ${(d.course.length / d.course.speed).round()}s course', size / 2, d.won ? 440 : 500, 52, color: Palette.textDim, w: FontWeight.w600, align: TextAlign.center);

  // Course map: one thin bar, hazards as ticks, X where you died.
  const mapL = 80.0;
  const mapR = size - 80.0;
  const mapY = 700.0;
  final mapW = mapR - mapL;
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(mapL, mapY - 22, mapW, 44), const Radius.circular(22)), Paint()..color = Palette.corridor);
  final n = d.course.length;
  final hz = Paint()..color = Palette.slabEdge;
  final sp = Paint()..color = Palette.spike;
  for (var i = 0; i < n; i++) {
    final col = d.course.columns[i];
    final x = mapL + mapW * (i + 0.5) / n;
    if (col.floorSpike) c.drawRect(Rect.fromLTWH(x - 2, mapY + 4, 4, 14), sp);
    if (col.ceilSpike) c.drawRect(Rect.fromLTWH(x - 2, mapY - 18, 4, 14), sp);
    if (col.floorH > 0) c.drawRect(Rect.fromLTWH(x - 2, mapY + 8, 4, 10.0 * col.floorH), hz);
    if (col.ceilH > 0) c.drawRect(Rect.fromLTWH(x - 2, mapY - 8 - 10.0 * col.ceilH, 4, 10.0 * col.ceilH), hz);
    if (col.isPit) c.drawRect(Rect.fromLTWH(x - 3, mapY + 6, 6, 16), Paint()..color = Palette.bg);
  }
  // Reached portion.
  final reachX = mapL + mapW * d.progress;
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(mapL, mapY - 6, (reachX - mapL).clamp(12, mapW), 12), const Radius.circular(6)), Paint()..color = d.won ? Palette.finish : Palette.player);
  // Earlier deaths as faint ticks.
  for (final dx in d.deathXs) {
    final x = mapL + mapW * (dx / n).clamp(0.0, 1.0);
    c.drawCircle(Offset(x, mapY + 52), 6, Paint()..color = Palette.marker.withValues(alpha: 0.35));
  }
  if (!d.won) {
    final xp = Paint()
      ..color = Palette.marker
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(reachX - 26, mapY - 26), Offset(reachX + 26, mapY + 26), xp);
    c.drawLine(Offset(reachX - 26, mapY + 26), Offset(reachX + 26, mapY - 26), xp);
  }

  if (d.streak > 1) {
    text('${d.streak}-day streak', size / 2, 800, 44, color: Palette.textDim, w: FontWeight.w600, align: TextAlign.center);
  }
  text('Same course for everyone today. Beat it.', size / 2, 930, 40, color: Palette.textDim, w: FontWeight.w600, align: TextAlign.center);
  text('tapiwamakandigona.github.io/fliptide-ci', size / 2, 990, 34, color: Palette.slabEdge, w: FontWeight.w600, align: TextAlign.center);

  final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

import 'dart:ui';

/// One strong accent per skin; everything else is shared so a 9:16 thumbnail
/// still reads floor / ceiling / player in a glance.
class Palette {
  static const bg = Color(0xFF0B0F1A);
  static const corridor = Color(0xFF131A2C);
  static const grid = Color(0x14FFFFFF);
  static const slab = Color(0xFF2A3352);
  static const slabEdge = Color(0xFF4B5A8A);
  static const spike = Color(0xFFFF4D5E);
  static const spikeTip = Color(0xFFFFE3E6);
  static const player = Color(0xFFFFC93C);
  static const playerDark = Color(0xFFB8861B);
  static const ghost = Color(0x66FFFFFF);
  static const marker = Color(0xFFFF4D5E);
  static const text = Color(0xFFF4F6FF);
  static const textDim = Color(0xFF8A93B5);
  static const finish = Color(0xFF3DFFA0);

  // Depth & polish (render-only).
  static const corridorDeep = Color(0xFF0E1424);
  static const pillar = Color(0x0AFFFFFF);
  static const seam = Color(0x10000000);
  static const slabLight = Color(0xFF3A4670);
  static const slabFar = Color(0xFF1C2340);
  static const shadow = Color(0x66000000);
  static const dust = Color(0xFF6E7BA6);
  static const eyeDark = Color(0xFF1A1A2E);
}

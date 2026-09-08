/// Shared menu widgets: buttons, stat chips, star rows, the course-code prompt.
library;

import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../sim/campaign.dart';
import 'language.dart';

class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    this.sub,
    required this.onTap,
    this.primary = false,
    this.trailing,
  });
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  final bool primary;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Palette.bg : Palette.text;
    return Material(
      color: primary ? Palette.player : Palette.slab,
      borderRadius: BorderRadius.circular(16),
      elevation: primary ? 8 : 0,
      shadowColor: primary
          ? Palette.player.withValues(alpha: 0.45)
          : Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: primary
                ? null
                : Border.all(
                    color: Palette.slabEdge.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                        fontSize: 16,
                        color: fg,
                      ),
                    ),
                    if (sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          sub!,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: primary
                                ? Palette.playerDark
                                : Palette.textDim,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: primary ? Palette.playerDark : Palette.textDim,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class SmallButton extends StatelessWidget {
  const SmallButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.corridor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.slabEdge.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Palette.textDim),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    color: Palette.textDim,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.corridor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Palette.text,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: Palette.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

/// Three stars, [earned] of them lit.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.earned, this.size = 16});
  final int earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < kMaxStars; i++)
          Icon(
            i < earned ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < earned ? Palette.player : Palette.slabEdge,
          ),
      ],
    );
  }
}

/// Modal prompt for a 6-char course code. Returns the raw text or null.
Future<String?> promptCourseCode(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Palette.slab,
      title: Text(
        ft(ctx, 'Play a course code'),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: 7,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
        decoration: const InputDecoration(hintText: 'ABC-123', counterText: ''),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ft(ctx, 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: Text(ft(ctx, 'PLAY')),
        ),
      ],
    ),
  );
}

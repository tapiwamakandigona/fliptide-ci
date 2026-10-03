// A canvas that records every call instead of drawing (test support, not a
// test file). Used to assert what the game actually draws: glow flare scale,
// eye and pupil geometry, burst particles, and that scenery hands the canvas
// the same cached objects every frame.
import 'dart:ui' as ui;

/// One recorded canvas call. [args] are the raw positional arguments (so
/// identity can be checked); [colors] and [shaded] snapshot every [ui.Paint]
/// argument at call time, because the game reuses and mutates its paints.
class CanvasCall {
  CanvasCall(this.name, this.args, this.named)
    : colors = [
        for (final a in args)
          if (a is ui.Paint) a.color,
      ],
      shaded = args.any((a) => a is ui.Paint && a.shader != null);

  final String name;
  final List<Object?> args;
  final Map<Symbol, Object?> named;
  final List<ui.Color> colors;
  final bool shaded;

  /// The colour of the (first) paint argument, or null.
  ui.Color? get color => colors.isEmpty ? null : colors.first;

  @override
  String toString() => '$name$args';
}

class RecordingCanvas implements ui.Canvas {
  final List<CanvasCall> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString(); // Symbol("drawCircle")
    calls.add(
      CanvasCall(
        name.substring(8, name.length - 2),
        List.unmodifiable(invocation.positionalArguments),
        Map.unmodifiable(invocation.namedArguments),
      ),
    );
    if (invocation.memberName == #getSaveCount) return 1;
    return null;
  }

  Iterable<CanvasCall> named(String name) => calls.where((c) => c.name == name);
}

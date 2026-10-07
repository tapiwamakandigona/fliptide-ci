/// Campaign-only content. NEVER add these to generator v1's frozen pool.
/// Long visible groups, safe landing stretches and no opposing hazards at
/// once: react, cross, settle. Later tides still deliver the sharper patterns.
library;

import 'chunks.dart';
import 'course.dart';

Chunk _rest(int count) =>
    Chunk('breath_$count', 0, List.filled(count, Column.flat));
Chunk _floor(int count) => Chunk(
  'floor_field_$count',
  1,
  List.filled(count, const Column(floorSpike: true)),
);
Chunk _ceiling(int count) => Chunk(
  'ceiling_field_$count',
  1,
  List.filled(count, const Column(ceilSpike: true)),
);
Chunk _pit(int count) => Chunk(
  'open_water_$count',
  1,
  List.filled(count, const Column(floorH: kPit)),
);
Chunk _step(int count) =>
    Chunk('sandbar_$count', 1, List.filled(count, const Column(floorH: 1)));
Chunk _hang(int count) =>
    Chunk('overhang_$count', 1, List.filled(count, const Column(ceilH: 1)));

/// A gravity pad sitting on flat floor: [lead] clear tiles, the pad, then
/// [trail] clear tiles so the auto-flip has somewhere to land.
Chunk _padHop(int lead, int trail) => Chunk(
  'spring_pad_${lead}_$trail',
  1,
  [...List.filled(lead, Column.flat), const Column(pad: true), ...List.filled(trail, Column.flat)],
);

/// Each course is storyboarded, not a seed with fortunate rerolls.
/// At these speeds a crossing costs under 3.2 tiles. Eight clear columns
/// between unlike obstacles leave time to land, read and choose again.
final List<List<Chunk>> shallows = [
  // First Light: see a floor field, cross, breathe, return, repeat.
  [
    kStart,
    _rest(2),
    _floor(5),
    _rest(10),
    _ceiling(5),
    _rest(10),
    _floor(5),
    _rest(10),
    kFinish,
  ],
  // Low Water: the same rhythm with an obvious gap; ceiling is safe.
  [
    kStart,
    _rest(3),
    _pit(5),
    _rest(10),
    _ceiling(5),
    _rest(10),
    _pit(7),
    _rest(10),
    _ceiling(5),
    _rest(8),
    kFinish,
  ],
  // Sandbar: solid side walls introduce a different reason to flip early.
  [
    kStart,
    _rest(2),
    _step(5),
    _rest(9),
    _hang(5),
    _rest(9),
    _step(7),
    _rest(9),
    _ceiling(5),
    _rest(9),
    kFinish,
  ],
  // Ripples: practise a steady alternating beat, never compulsory mashing.
  [
    kStart,
    _rest(2),
    _floor(5),
    _rest(8),
    _ceiling(5),
    _rest(8),
    _floor(5),
    _rest(8),
    _ceiling(5),
    _rest(8),
    _floor(5),
    _rest(8),
    kFinish,
  ],
  // Rock Pool: a long floor field teaches staying put rather than tapping.
  [
    kStart,
    _rest(2),
    _floor(11),
    _rest(9),
    _ceiling(6),
    _rest(9),
    _pit(8),
    _rest(9),
    _hang(5),
    _rest(9),
    kFinish,
  ],
  // Ebb: combine everything, still with clean gaps before the Drift.
  [
    kStart,
    _rest(2),
    _step(5),
    _rest(8),
    _ceiling(6),
    _rest(8),
    _pit(7),
    _rest(8),
    _hang(5),
    _rest(8),
    _floor(8),
    _rest(8),
    _ceiling(5),
    _rest(8),
    kFinish,
  ],
  // Spring Tide: the first gravity pad. Run onto it and it flips you up for
  // free; ride the ceiling over the fields below. Teaches pads safely.
  [
    kStart,
    _rest(3),
    _padHop(2, 3),
    _rest(10),
    _floor(5),
    _rest(10),
    _floor(5),
    _rest(10),
    _rest(6),
    kFinish,
  ],
];

const shallowsHints = [
  'Tap before the red teeth. Land, then tap back.',
  'Open water below? Cross to the ceiling and stay there.',
  'Flip before a wall. You cannot run through its side.',
  'Read the next side. One calm tap is enough.',
  'Stay above a long hazard. There is no need to keep tapping.',
  'Walls, water, teeth. Find the safe side and trust the rhythm.',
  'Run onto the glowing pad — it flips you up for free. Ride the ceiling.',
];

const shallowsStory = [
  'The lighthouse is dark. Carry its last spark inland.',
  'The tide took the path. The ceiling is another shore.',
  'Old sea walls still hold. Go around, not through.',
  'The beacon answers in pulses. Learn its rhythm.',
  'Light moves over still water. Give yourself room to breathe.',
  'Behind you, the first beacon wakes. Ahead: the Drift.',
  'A spring tide lifts you without a step. Let it carry you up.',
];

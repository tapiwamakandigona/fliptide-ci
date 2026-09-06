/// The Tides — Fliptide's authored campaign.
///
/// Five tides, six courses each. Every course is a fixed [GenSpec]: a frozen
/// seed plus the knobs that shape difficulty (length, speed, which chunk
/// tiers may appear and how often). Because the generator is deterministic,
/// a campaign course is identical on every device forever, exactly like a
/// Daily — but here the *curve* is designed instead of rolled:
///
///   Tide 1  Shallows   — short, slow, tier-1 hazards only; teaches the flip.
///   Tide 2  Drift      — medium pace, tier-2 shapes enter.
///   Tide 3  Undertow   — tier-3 patterns, longer courses.
///   Tide 4  Riptide    — tier-4 "brutal" chunks appear, speed 9.5.
///   Tide 5  Maelstrom  — long, fast, hard-weighted. The ending.
///
/// Pure Dart: no Flutter imports (headless-testable, like the rest of `sim/`).
library;

import 'generator.dart';

class Tide {
  const Tide({required this.index, required this.name, required this.tagline, required this.levels});

  /// 1-based.
  final int index;
  final String name;
  final String tagline;
  final List<CampaignLevel> levels;
}

class CampaignLevel {
  const CampaignLevel({
    required this.id,
    required this.tide,
    required this.index,
    required this.name,
    required this.spec,
  });

  /// Stable save key, e.g. `t2l4`. Never renumber a shipped id.
  final String id;

  /// 1-based tide and level-in-tide.
  final int tide;
  final int index;
  final String name;
  final GenSpec spec;

  /// HUD label: `TIDE 2 · 4`.
  String get label => 'TIDE $tide · $index';
}

GenSpec _spec(int seed, {required int columns, required double speed, required int maxTier, required Map<int, int> weights}) =>
    GenSpec(seed: seed, targetColumns: columns, speed: speed, maxTier: maxTier, tierWeights: weights);

List<CampaignLevel> _tide(int t, List<String> names, List<GenSpec> specs) => [
      for (var i = 0; i < names.length; i++)
        CampaignLevel(id: 't${t}l${i + 1}', tide: t, index: i + 1, name: names[i], spec: specs[i]),
    ];

const _w1 = {1: 1};
const _w2 = {1: 3, 2: 2};
const _w3 = {1: 2, 2: 3, 3: 2};
const _w4 = {1: 1, 2: 3, 3: 3, 4: 1};
const _w5 = {2: 2, 3: 3, 4: 2};

/// The campaign. Seeds are arbitrary constants chosen once; changing one
/// changes that course for everyone, so treat them as content.
final List<Tide> kTides = [
  Tide(
    index: 1,
    name: 'Shallows',
    tagline: 'Learn the flip.',
    levels: _tide(1, ['First Light', 'Low Water', 'Sandbar', 'Ripples', 'Rock Pool', 'Ebb'], [
      _spec(1001, columns: 60, speed: 6.5, maxTier: 1, weights: _w1),
      _spec(1002, columns: 70, speed: 6.5, maxTier: 1, weights: _w1),
      _spec(1003, columns: 80, speed: 7.0, maxTier: 1, weights: _w1),
      _spec(1004, columns: 90, speed: 7.0, maxTier: 1, weights: _w1),
      _spec(1005, columns: 100, speed: 7.5, maxTier: 1, weights: _w1),
      _spec(1006, columns: 110, speed: 7.5, maxTier: 2, weights: {1: 4, 2: 1}),
    ]),
  ),
  Tide(
    index: 2,
    name: 'Drift',
    tagline: 'The current picks up.',
    levels: _tide(2, ['Open Water', 'Kelp Line', 'Cross-Swell', 'Wreck', 'Shoal', 'Slack Tide'], [
      _spec(2001, columns: 110, speed: 8.0, maxTier: 2, weights: _w2),
      _spec(2002, columns: 120, speed: 8.0, maxTier: 2, weights: _w2),
      _spec(2003, columns: 130, speed: 8.0, maxTier: 2, weights: _w2),
      _spec(2004, columns: 140, speed: 8.5, maxTier: 2, weights: _w2),
      _spec(2005, columns: 150, speed: 8.5, maxTier: 2, weights: {1: 2, 2: 3}),
      _spec(2006, columns: 150, speed: 8.5, maxTier: 3, weights: {1: 2, 2: 3, 3: 1}),
    ]),
  ),
  Tide(
    index: 3,
    name: 'Undertow',
    tagline: 'What pulls you under.',
    levels: _tide(3, ['Blue Hole', 'Reef Teeth', 'Down-Draft', 'Cavern', 'Pressure', 'Surge'], [
      _spec(3001, columns: 150, speed: 8.5, maxTier: 3, weights: _w3),
      _spec(3002, columns: 160, speed: 9.0, maxTier: 3, weights: _w3),
      _spec(3003, columns: 170, speed: 9.0, maxTier: 3, weights: _w3),
      _spec(3004, columns: 180, speed: 9.0, maxTier: 3, weights: _w3),
      _spec(3005, columns: 190, speed: 9.0, maxTier: 3, weights: {1: 1, 2: 3, 3: 3}),
      _spec(3006, columns: 190, speed: 9.0, maxTier: 4, weights: {1: 1, 2: 3, 3: 3, 4: 1}),
    ]),
  ),
  Tide(
    index: 4,
    name: 'Riptide',
    tagline: 'No slack left.',
    levels: _tide(4, ['Breakwater', 'Spindrift', 'Whitecaps', 'Gully', 'Tempest', 'Storm Wall'], [
      _spec(4001, columns: 190, speed: 9.5, maxTier: 4, weights: _w4),
      _spec(4002, columns: 200, speed: 9.5, maxTier: 4, weights: _w4),
      _spec(4003, columns: 210, speed: 9.5, maxTier: 4, weights: _w4),
      _spec(4004, columns: 220, speed: 9.5, maxTier: 4, weights: _w4),
      _spec(4005, columns: 230, speed: 10.0, maxTier: 4, weights: _w4),
      _spec(4006, columns: 230, speed: 10.0, maxTier: 4, weights: {2: 2, 3: 3, 4: 2}),
    ]),
  ),
  Tide(
    index: 5,
    name: 'Maelstrom',
    tagline: 'The last flip.',
    levels: _tide(5, ['Vortex', 'Black Water', 'Crush Depth', 'The Drop', 'Eye of It', 'Fliptide'], [
      _spec(5001, columns: 230, speed: 10.0, maxTier: 4, weights: _w5),
      _spec(5002, columns: 240, speed: 10.0, maxTier: 4, weights: _w5),
      _spec(5003, columns: 250, speed: 10.5, maxTier: 4, weights: _w5),
      _spec(5004, columns: 260, speed: 10.5, maxTier: 4, weights: _w5),
      _spec(5005, columns: 270, speed: 10.5, maxTier: 4, weights: _w5),
      _spec(5006, columns: 280, speed: 11.0, maxTier: 4, weights: {3: 3, 4: 3}),
    ]),
  ),
];

/// All levels in play order.
final List<CampaignLevel> kCampaign = [for (final t in kTides) ...t.levels];

CampaignLevel? levelById(String id) {
  for (final l in kCampaign) {
    if (l.id == id) return l;
  }
  return null;
}

/// The level after [level], or null after the last one.
CampaignLevel? nextLevel(CampaignLevel level) {
  final i = kCampaign.indexOf(level);
  return i < 0 || i + 1 >= kCampaign.length ? null : kCampaign[i + 1];
}

/// Stars for clearing a course in [sessionAttempts] tries (1-based):
/// first try → 3, within three → 2, otherwise 1.
int starsFor(int sessionAttempts) => sessionAttempts <= 1 ? 3 : (sessionAttempts <= 3 ? 2 : 1);

const int kMaxStars = 3;

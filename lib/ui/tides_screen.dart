/// The Tides — level select. Five tides, six courses each, stars and locks.
library;

import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../main.dart' show PlayScreen;
import '../sim/campaign.dart';
import '../store/store.dart';
import 'widgets.dart';
import 'language.dart';

class TidesScreen extends StatefulWidget {
  const TidesScreen({super.key});

  @override
  State<TidesScreen> createState() => _TidesScreenState();
}

class _TidesScreenState extends State<TidesScreen> {
  Store? _store;

  @override
  void initState() {
    super.initState();
    Store.open().then((s) {
      if (mounted) setState(() => _store = s);
    });
  }

  Future<void> _play(CampaignLevel l) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PlayScreen(level: l)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return Scaffold(
      backgroundColor: Palette.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Palette.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          ft(context, 'THE TIDES'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 15,
            color: Palette.text,
          ),
        ),
        centerTitle: true,
        actions: [
          if (store != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: StatChip(
                  icon: Icons.star_rounded,
                  color: Palette.player,
                  value: '${store.totalStars}',
                  label: '/ ${kCampaign.length * kMaxStars}',
                ),
              ),
            ),
        ],
      ),
      body: store == null
          ? const Center(
              child: CircularProgressIndicator(color: Palette.player),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              itemCount: kTides.length,
              itemBuilder: (_, i) =>
                  _TideSection(tide: kTides[i], store: store, onPlay: _play),
            ),
    );
  }
}

class _TideSection extends StatelessWidget {
  const _TideSection({
    required this.tide,
    required this.store,
    required this.onPlay,
  });
  final Tide tide;
  final Store store;
  final void Function(CampaignLevel) onPlay;

  @override
  Widget build(BuildContext context) {
    final unlocked = store.levelUnlocked(tide.levels.first);
    final stars = tide.levels.fold<int>(
      0,
      (n, l) => n + store.levelStars(l.id),
    );
    final cleared = tide.levels.where((l) => store.levelCleared(l.id)).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(
              children: [
                Text(
                  ft(context, 'TIDE {number}', args: {'number': tide.index}),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    color: Palette.textDim,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ft(context, tide.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: unlocked ? Palette.text : Palette.textDim,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (unlocked)
                  Text(
                    '$cleared/${tide.levels.length}  ·  $stars★',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Palette.textDim,
                    ),
                  )
                else
                  const Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: Palette.slabEdge,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              unlocked
                  ? ft(context, tide.tagline)
                  : ft(
                      context,
                      'Clear Tide {number} to open.',
                      args: {'number': tide.index - 1},
                    ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Palette.textDim,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, box) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              return GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: box.maxWidth < 320 || scale > 1.2 ? 2 : 3,
                  mainAxisExtent: 96 * scale.clamp(1.0, 3.0),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final l in tide.levels)
                    _LevelTile(level: l, store: store, onPlay: onPlay),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.store,
    required this.onPlay,
  });
  final CampaignLevel level;
  final Store store;
  final void Function(CampaignLevel) onPlay;

  @override
  Widget build(BuildContext context) {
    final unlocked = store.levelUnlocked(level);
    final stars = store.levelStars(level.id);
    final isNext = unlocked && stars == 0 && store.nextCampaignLevel == level;
    final secs = level.estimatedSeconds.round();
    return Material(
      key: Key('tile-${level.id}'),
      color: unlocked ? Palette.slab : Palette.corridor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: unlocked ? () => onPlay(level) : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isNext
                  ? Palette.player
                  : Palette.slabEdge.withValues(alpha: unlocked ? 0.5 : 0.2),
              width: isNext ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${level.index}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: unlocked
                          ? (isNext ? Palette.player : Palette.text)
                          : Palette.slabEdge,
                    ),
                  ),
                  const Spacer(),
                  if (!unlocked)
                    const Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: Palette.slabEdge,
                    )
                  else
                    Text(
                      '~${secs}s',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Palette.textDim,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                ft(context, level.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: unlocked ? Palette.text : Palette.slabEdge,
                ),
              ),
              const SizedBox(height: 3),
              StarRow(earned: stars, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

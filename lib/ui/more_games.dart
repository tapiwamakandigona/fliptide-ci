// "More from Tsoro Studios" — one quiet cross-promotion row (owner directive
// 2026-09-05b). Title screen footer only; never on the death or CLEARED cards.
// No badge, no modal, no analytics event: the Play install-referrer already
// measures the tap.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../game/palette.dart';

/// This game's id, used as the utm_source / install referrer on Android.
const kThisGame = 'fliptide';

/// Pyregrove's Play listing is still in review (2026-09-05). Flip to true once
/// it is public; the entry is hidden until then.
const kShowPyregrove = false;

class MoreGame {
  const MoreGame({required this.name, required this.hook, required this.packageId, this.webUrl});
  final String name;
  final String hook;
  final String packageId;
  /// Where web builds (and the https fallback) go. Defaults to the Play listing.
  final String? webUrl;

  Uri get playUri => Uri.parse('https://play.google.com/store/apps/details?id=$packageId');
  Uri get marketUri => Uri.parse('market://details?id=$packageId&referrer=utm_source%3D$kThisGame');
  Uri get httpsUri => webUrl != null ? Uri.parse(webUrl!) : playUri;
}

const kEmberdelve = MoreGame(
  name: 'Emberdelve',
  hook: 'Dice roguelite. No ads, offline.',
  packageId: 'com.tsorostudios.emberdelve',
);

const kPyregrove = MoreGame(
  name: 'Pyregrove',
  hook: 'Pixel platformer. Two worlds of handcrafted levels, no ads.',
  packageId: 'com.tsorostudios.pyregrove',
);

/// The entries shown in this game, in order.
List<MoreGame> moreGames({bool showPyregrove = kShowPyregrove}) => [
      kEmberdelve,
      if (showPyregrove) kPyregrove,
    ];

typedef UriLauncher = Future<bool> Function(Uri uri, {LaunchMode mode});

/// Android: try the Play app (market://) first, then https. Everywhere else:
/// the https URL in a new tab / external browser.
Future<bool> openMoreGame(MoreGame g, {UriLauncher? launcher, TargetPlatform? platform, bool? isWeb}) async {
  final launch = launcher ?? launchUrl;
  final web = isWeb ?? kIsWeb;
  final tp = platform ?? defaultTargetPlatform;
  if (!web && tp == TargetPlatform.android) {
    try {
      if (await launch(g.marketUri, mode: LaunchMode.externalApplication)) return true;
    } catch (_) {
      // No Play app on this device — fall through to https.
    }
  }
  try {
    return await launch(g.httpsUri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// The row itself: "More from Tsoro Studios" + one text link per game.
class MoreFromTsoro extends StatelessWidget {
  const MoreFromTsoro({super.key, this.games, this.onOpen, this.compact = false});
  final List<MoreGame>? games;
  /// One line per game ("Emberdelve — hook · MORE FROM TSORO STUDIOS" header dropped)
  /// for title screens that already carry other rows.
  final bool compact;
  /// Test seam; defaults to [openMoreGame].
  final Future<bool> Function(MoreGame g)? onOpen;

  static const _label = TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Palette.textDim);
  static const _name = TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Palette.text);
  static const _hook = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.textDim);

  @override
  Widget build(BuildContext context) {
    final list = games ?? moreGames();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('more-from-tsoro'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) ...[
          const Text('MORE FROM TSORO STUDIOS', style: _label),
          const SizedBox(height: 4),
        ],
        for (final g in list)
          InkWell(
            key: Key('more-${g.packageId}'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => (onOpen ?? openMoreGame)(g),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text.rich(
                TextSpan(children: [
                  if (compact) const TextSpan(text: 'More from Tsoro Studios: ', style: _hook),
                  TextSpan(text: g.name, style: _name),
                  TextSpan(text: ' — ${g.hook}', style: _hook),
                ]),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ),
      ],
    );
  }
}

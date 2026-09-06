/// Local persistence (shared_preferences). No server, no accounts.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../sim/campaign.dart';

class DailyRecord {
  DailyRecord({required this.number, this.best = 0, this.attempts = 0, this.won = false, this.ghost = const []});
  final int number;
  double best;
  int attempts;
  bool won;
  List<int> ghost;
}

class Store {
  Store._(this._p);
  final SharedPreferences _p;

  static Future<Store> open() async => Store._(await SharedPreferences.getInstance());

  DailyRecord daily(int number) {
    final g = _p.getString('d$number.ghost');
    return DailyRecord(
      number: number,
      best: _p.getDouble('d$number.best') ?? 0,
      attempts: _p.getInt('d$number.attempts') ?? 0,
      won: _p.getBool('d$number.won') ?? false,
      ghost: g == null || g.isEmpty ? const [] : g.split(',').map(int.parse).toList(),
    );
  }

  Future<void> save(DailyRecord r) async {
    await _p.setDouble('d${r.number}.best', r.best);
    await _p.setInt('d${r.number}.attempts', r.attempts);
    await _p.setBool('d${r.number}.won', r.won);
    await _p.setString('d${r.number}.ghost', r.ghost.join(','));
  }

  int get streak => _p.getInt('streak') ?? 0;
  int get lastPlayedDay => _p.getInt('lastDay') ?? 0;

  /// Call once per day on first attempt. Streak counts consecutive days played.
  Future<void> touchDay(int number) async {
    final last = lastPlayedDay;
    if (last == number) return;
    final s = last == number - 1 ? streak + 1 : 1;
    await _p.setInt('streak', s);
    await _p.setInt('lastDay', number);
  }

  int get totalDeaths => _p.getInt('deaths') ?? 0;
  Future<void> addDeath() => _p.setInt('deaths', totalDeaths + 1);

  // ---- ads / supporter (directive 02k) ---------------------------------

  /// Supporter IAP owned → no ads, ever. Persisted locally; checked before any load.
  bool get supporter => _p.getBool('supporter') ?? false;
  Future<void> setSupporter(bool v) => _p.setBool('supporter', v);

  /// The rewarded "second chance" is offered at most once per Daily.
  bool secondChanceUsed(int number) => _p.getBool('d$number.secondChance') ?? false;
  Future<void> setSecondChanceUsed(int number) => _p.setBool('d$number.secondChance', true);

  /// Epoch ms of the first ever launch (DEMAND §3: no interstitial in the first 3 min of a fresh install).
  Future<int> installMs() async {
    final v = _p.getInt('installMs');
    if (v != null) return v;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _p.setInt('installMs', now);
    return now;
  }
  // ---- The Tides (campaign) -------------------------------------------

  /// Best stars (0..3) for a campaign level id; 0 = never cleared.
  int levelStars(String id) => _p.getInt('lvl.$id.stars') ?? 0;
  bool levelCleared(String id) => levelStars(id) > 0;

  /// Record a clear. Keeps the best star count; never lowers it.
  Future<void> clearLevel(String id, int stars) async {
    if (stars > levelStars(id)) await _p.setInt('lvl.$id.stars', stars);
  }

  /// A level is playable when it is the first one or its predecessor is cleared.
  bool levelUnlocked(CampaignLevel level) {
    final i = kCampaign.indexOf(level);
    if (i <= 0) return true;
    return levelCleared(kCampaign[i - 1].id);
  }

  /// The first uncleared level, or the last level once everything is cleared.
  CampaignLevel get nextCampaignLevel {
    for (final l in kCampaign) {
      if (!levelCleared(l.id)) return l;
    }
    return kCampaign.last;
  }

  int get totalStars {
    var n = 0;
    for (final l in kCampaign) {
      n += levelStars(l.id);
    }
    return n;
  }

  int get levelsCleared => kCampaign.where((l) => levelCleared(l.id)).length;
}

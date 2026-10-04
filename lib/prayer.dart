import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';
import 'services.dart';
import 'storage.dart';
import 'utils.dart';

List<PrayTime> fallbackVakitler() => [
  PrayTime('\u0130msak', '--:--'),
  PrayTime('G\u00FCne\u015F', '--:--'),
  PrayTime('\u00D6\u011Fle', '--:--'),
  PrayTime('\u0130kindi', '--:--'),
  PrayTime('Ak\u015Fam', '--:--'),
  PrayTime('Yats\u0131', '--:--'),
];

class PrayerTime {
  final int hour;
  final int minute;
  PrayerTime(this.hour, this.minute);
}

PrayerTime? parseTime(String s) {
  if (s.isEmpty || s == '--:--') return null;
  final p = s.split(':');
  if (p.length < 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return PrayerTime(h, m);
}

class PrayerService extends ChangeNotifier {
  final Storage storage;
  PrayerService(this.storage);

  List<PrayTime> vakitler = fallbackVakitler();
  String districtName = '';
  String ipCity = '';
  double? userLat;
  double? userLng;

  DateTime? _cachedFrom;
  int _index = 0; // şu anki vakit indeksi
  Duration _nextIn = Duration.zero; // sonraki vakite kalan
  String _nextLabel = ''; // 'kaldı' | 'yarın için kaldı'
  int _nextIndex = 0; // sıradaki vakit indeksi
  Timer? _ticker;
  Timer? _dayCheck;
  bool _disposed = false;

  String _lastFetchDate = '';
  String _lastFetchLoc = '';

  int get currentIndex => _index;
  String get nextLabel => _nextLabel;
  String get nextDistance => fmtDuration(_nextIn.inSeconds);
  int get nextPrayerIndex => _nextIndex;
  DateTime? get cachedFrom => _cachedFrom;

  void start() {
    compute(false);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => compute(false));
    _dayCheck = Timer.periodic(const Duration(minutes: 1), (_) {
      if (isoDate(DateTime.now()) != _lastFetchDate) {
        fetch(fetchAlways: true);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _dayCheck?.cancel();
    super.dispose();
  }

  void recompute() => compute(true);

  /// vakitler hesaplama: geçerli/gelecek indeks + geri sayım.
  void compute(bool force) {
    final n = DateTime.now();
    final ns = n.hour * 3600 + n.minute * 60 + n.second;
    var nextIdx = -1;
    for (var i = 0; i < vakitler.length; i++) {
      final t = parseTime(vakitler[i].time);
      if (t == null) continue;
      if (t.hour * 3600 + t.minute * 60 >= ns) {
        nextIdx = i;
        break;
      }
    }
    int diff;
    String label;
    if (nextIdx == -1) {
      nextIdx = 0;
      final t = parseTime(vakitler[nextIdx].time);
      diff = (86400 - ns) + (t != null ? t.hour * 3600 + t.minute * 60 : 0);
      label = 'yar\u0131n i\u00E7in kald\u0131';
    } else {
      final t = parseTime(vakitler[nextIdx].time);
      diff = t != null ? t.hour * 3600 + t.minute * 60 - ns : 0;
      label = 'kald\u0131';
    }
    diff = diff < 0 ? 0 : diff;
    if (diff > 86399) diff = 86399;

    // şu anki vakit indeksi: kalan gün içinde o vakitten sonraki ilk vakit?
    var ci = -1;
    final nm = n.hour * 60 + n.minute;
    for (var i = 0; i < vakitler.length; i++) {
      final t = parseTime(vakitler[i].time);
      if (t != null && t.hour * 60 + t.minute > nm) {
        ci = i;
        break;
      }
    }
    if (ci == -1) ci = 0;

    final changed =
        _index != ci ||
        _nextIndex != nextIdx ||
        _nextIn.inSeconds != diff ||
        _nextLabel != label;
    if (!force && !changed) return;
    _cachedFrom = n;
    _index = ci;
    _nextIndex = nextIdx;
    _nextIn = Duration(seconds: diff);
    _nextLabel = label;
    notifyListeners();
  }

  /// Gün/konum değişmediyse çekme (legacy fetchPrayerTimes).
  Future<void> fetch({
    bool fetchAlways = false,
    double? lat,
    double? lng,
  }) async {
    final lat2 = lat ?? userLat;
    final lng2 = lng ?? userLng;
    if (lat2 == null || lng2 == null) return;
    final today = isoDate(DateTime.now());
    final loc = '$lat2,$lng2';
    if (!fetchAlways && today == _lastFetchDate && loc == _lastFetchLoc) return;
    _lastFetchDate = today;
    _lastFetchLoc = loc;
    debugPrint('NKDBG: prayer.fetch begin $lat2,$lng2 force=$fetchAlways');
    try {
      final dist = await Api.resolveDistrict(
        lat2,
        lng2,
        cached: storage.loadDistrict(),
        ipCity: ipCity,
      );
      debugPrint(
        'NKDBG: resolveDistrict -> ${dist?.districtId} ${dist?.districtName}',
      );
      if (dist != null) {
        districtName = capTr(dist.districtName);
        storage.saveDistrict(dist);
        final times = await Api.fetchDiyanetTimes(
          dist.districtId,
          source: services.app.remote.prayerSource,
        );
        debugPrint('NKDBG: times fetched ${times.length}');
        vakitler = times;
      }
    } catch (e) {
      debugPrint('NKDBG: prayer fetch ERR $e');
      vakitler = fallbackVakitler();
    }
    if (_disposed) return;
    compute(true);
  }

  Future<void> refresh() => fetch(fetchAlways: true);

  void resetLocation() {
    _lastFetchLoc = '';
  }
}

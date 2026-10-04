import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'api.dart';
import 'models.dart';
import 'utils.dart';

enum LocStatus { idle, locating, ipFallback, done, denied }

class LocationService extends ChangeNotifier {
  double userLat = 37.87;
  double userLng = 32.49;
  String ipCity = '';

  List<Mosque> places = [];

  /// Panelden onaylanıp uygulamaya eklenen mescitler (OSM listesine birleştirilir).
  List<Mosque> _approved = [];
  LocStatus status = LocStatus.idle;
  bool mounted = false;
  String? message;

  bool permissionDenied = false;
  bool permissionDeniedForever = false;
  bool locationServiceDisabled = false;

  final Set<String> skippedArrivals = {};
  bool hasArrived = false;
  Mosque? arrivedMosque;
  ValueChanged<Mosque>? onArrived;

  double _lastFetchLat = 0;
  double _lastFetchLng = 0;
  bool firstGpsTryDone = false;

  Future<void> Function(double lat, double lng)? onLoadAround;
  void Function(Mosque nearest)? onExport;

  LocationService._();
  static final LocationService instance = LocationService._();

  bool get isGps => status == LocStatus.done;
  bool get hasLocation =>
      status == LocStatus.done || status == LocStatus.ipFallback;

  void reassign(double lat, double lng) {
    userLat = lat;
    userLng = lng;
    notifyListeners();
  }

  /// Web startLocation: GPS (2 deneme) → IP. Sadece giriş yapınca.
  Future<void> start({bool force = false}) async {
    if (mounted && !force) return;
    mounted = true;
    await tryBrowserLocation();
  }

  Future<void> tryBrowserLocation() async {
    status = LocStatus.locating;
    locationServiceDisabled = false;
    notifyListeners();
    debugPrint('NKDBG: tryBrowserLocation start');
    bool serviceOn = true;
    try {
      serviceOn = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      serviceOn = true;
    }
    debugPrint('NKDBG: serviceOn=$serviceOn');
    if (!serviceOn) {
      locationServiceDisabled = true;
      message = 'Cihaz konum servisi kapal\u0131yken konum al\u0131namaz';
      notifyListeners();
      await tryIpLocation();
      firstGpsTryDone = true;
      return;
    }
    LocationPermission perm;
    try {
      perm = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      perm = LocationPermission.denied;
    }
    if (perm == LocationPermission.denied) {
      try {
        perm = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 30),
        );
      } on LocationServiceDisabledException {
        locationServiceDisabled = true;
        message = 'Cihaz konum servisi kapal\u0131yken konum al\u0131namaz';
        notifyListeners();
        await tryIpLocation();
        firstGpsTryDone = true;
        return;
      } catch (_) {
        perm = LocationPermission.denied;
      }
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      permissionDeniedForever = perm == LocationPermission.deniedForever;
      permissionDenied = true;
      message = permissionDeniedForever
          ? 'Konum izni kal\u0131c\u0131 olarak reddedildi'
          : 'Konum izni verilmedi, IP tabanl\u0131 tahmin kullan\u0131l\u0131yor';
      notifyListeners();
      await tryIpLocation();
      firstGpsTryDone = true;
      return;
    }
    debugPrint('NKDBG: perm=$perm');
    var ok = false;
    for (var i = 0; i < 2 && !ok; i++) {
      try {
        debugPrint('NKDBG: gps attempt $i');
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        ).timeout(const Duration(seconds: 9));
        debugPrint('NKDBG: gps got ${pos.latitude},${pos.longitude}');
        onLocSuccess(pos.latitude, pos.longitude);
        ok = true;
        permissionDenied = false;
        permissionDeniedForever = false;
        break;
      } on LocationServiceDisabledException {
        locationServiceDisabled = true;
        message = 'Cihaz konum servisi kapal\u0131yken konum al\u0131namaz';
        notifyListeners();
        break;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
    if (!ok) {
      debugPrint('NKDBG: gps loop failed -> ip fallback');
      await tryIpLocation();
    }
    firstGpsTryDone = true;
  }

  /// İzin uyarı ekranından: kalıcı reddetmede ayarlar, aksi hâlde izin iste.
  Future<void> askPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      permissionDenied = true;
      permissionDeniedForever = true;
      locationServiceDisabled = false;
      notifyListeners();
      await Geolocator.openAppSettings();
      return;
    }
    if (perm == LocationPermission.denied) {
      permissionDenied = true;
      permissionDeniedForever = false;
      locationServiceDisabled = false;
      notifyListeners();
      return;
    }
    permissionDenied = false;
    permissionDeniedForever = false;
    await start(force: true);
  }

  /// Konum servisi (GPS) kapalıysa sistem ayarlarına götür, sonra tekrar dene.
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
    await Future.delayed(const Duration(milliseconds: 800));
    await start(force: true);
  }

  Future<void> tryIpLocation() async {
    if (hasLocation) return;
    status = LocStatus.ipFallback;
    message = 'Konum izni yok, IP ile tahmin ediliyor\u2026';
    notifyListeners();
    debugPrint('NKDBG: tryIpLocation calling Api.ipLocation');
    final ip = await Api.ipLocation();
    debugPrint('NKDBG: tryIpLocation done ip=$ip');
    if (ip != null && !hasLocation) {
      ipCity = ip.city;
      onLocSuccess(ip.lat, ip.lng);
    } else {
      message =
          'Konum al\u0131namad\u0131, varsay\u0131lan kullan\u0131l\u0131yor';
      status = LocStatus.denied;
      notifyListeners();
      loadAround(userLat, userLng, recenter: false);
    }
  }

  void onLocSuccess(double lat, double lng) {
    userLat = lat;
    userLng = lng;
    status = LocStatus.done;
    message = null;
    permissionDenied = false;
    permissionDeniedForever = false;
    locationServiceDisabled = false;
    notifyListeners();
    if (!firstGpsTryDone) {
      firstGpsTryDone = true;
      loadAround(lat, lng, recenter: true);
    } else if (_lastFetchLat != 0) {
      final moved = haversine(_lastFetchLat, _lastFetchLng, lat, lng);
      if (moved > 500) loadAround(lat, lng, recenter: false);
    }
  }

  /// Web loadAround: vakit + yakın mescitler.
  Future<void> loadAround(
    double lat,
    double lng, {
    bool recenter = false,
  }) async {
    if (onLoadAround != null) await onLoadAround!(lat, lng);
    _lastFetchLat = lat;
    _lastFetchLng = lng;
    await fetchNearby(lat, lng);
    notifyListeners();
  }

  Future<void> fetchNearby(double lat, double lng) async {
    status = LocStatus.locating;
    message = 'Mescitler yükleniyor…';
    places = await Api.nearbyMosques(lat, lng);
    _mergeApproved();
    status = LocStatus.done;
    message = null;
    notifyListeners();
  }

  /// Panelden gelen onaylı önerileri yer listesine birleştirir (30m içinde
  /// OSM kaydı varsa kopya oluşmasın diye atlanır).
  void setApproved(List<Mosque> list) {
    _approved = list;
    _mergeApproved();
    notifyListeners();
  }

  void _mergeApproved() {
    final osm = places.where((p) => !p.key.startsWith('ap')).toList();
    final merged = [...osm];
    for (final a in _approved) {
      final dup = merged.any((p) => haversine(p.lat, p.lon, a.lat, a.lon) < 30);
      if (!dup) merged.add(a);
    }
    places = merged;
  }

  /// Web checkArrival: 150m içinde mescide varış tespiti.
  void checkArrival() {
    if (hasArrived) return;
    for (final p in places) {
      if (skippedArrivals.contains(p.key)) continue;
      if (haversine(userLat, userLng, p.lat, p.lon) < 150) {
        hasArrived = true;
        arrivedMosque = p;
        onArrived?.call(p);
        break;
      }
    }
    if (onExport != null && places.isNotEmpty) {
      Mosque nearest = places.first;
      var best = double.infinity;
      for (final p in places) {
        final d = haversine(userLat, userLng, p.lat, p.lon);
        if (d < best) {
          best = d;
          nearest = p;
        }
      }
      onExport!(nearest);
    }
  }

  void skipArrival(Mosque p) {
    skippedArrivals.add(p.key);
    hasArrived = false;
    arrivedMosque = null;
    notifyListeners();
  }

  void clearArrival() {
    hasArrived = false;
    arrivedMosque = null;
    notifyListeners();
  }

  void resetForLogout() {
    mounted = false;
    firstGpsTryDone = false;
  }

  /// Aktif rota.
  List<List<double>>? activeRoute;
  String? activeRouteKey;

  Future<void> routeTo(Mosque m, {String profile = 'walking'}) async {
    activeRoute = null;
    activeRouteKey = null;
    final r = await Api.route(userLat, userLng, m.lat, m.lon, profile);
    if (r != null) {
      activeRoute = r.coords;
      activeRouteKey = m.key;
    }
    notifyListeners();
  }

  void clearRoute() {
    activeRoute = null;
    activeRouteKey = null;
    notifyListeners();
  }

  Future<bool> ensurePermission({bool silent = false}) async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      final p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        if (!silent) {
          await Geolocator.openAppSettings();
          final p2 = await Geolocator.checkPermission();
          return p2 == LocationPermission.whileInUse ||
              p2 == LocationPermission.always;
        }
        return false;
      }
      return true;
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }
}

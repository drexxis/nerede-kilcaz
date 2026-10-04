import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'utils.dart';

class Api {
  static Future<http.Response?> _retried(
    Future<http.Response> Function() fn,
  ) async {
    try {
      final r = await fn().timeout(const Duration(seconds: 20));
      debugPrint('NKDBG: done ${r.request?.url} -> ${r.statusCode}');
      if (r.statusCode >= 200 && r.statusCode < 300) return r;
      if (r.statusCode == 429 || r.statusCode >= 500) {
        await Future.delayed(const Duration(milliseconds: 700));
        final r2 = await fn().timeout(const Duration(seconds: 20));
        debugPrint('NKDBG: retry ${r2.request?.url} -> ${r2.statusCode}');
        if (r2.statusCode >= 200 && r2.statusCode < 300) return r2;
      }
    } catch (e) {
      debugPrint('NKDBG: ERR $e');
    }
    return null;
  }

  static Map<String, dynamic> _strMap(dynamic v) {
    if (v is Map) {
      try {
        return Map<String, dynamic>.from(v);
      } catch (_) {}
    }
    return {};
  }

  static List<Map<String, dynamic>> _mapList(dynamic v) {
    if (v is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in v) {
      if (e is Map) {
        try {
          out.add(Map<String, dynamic>.from(e));
        } catch (_) {}
      }
    }
    return out;
  }

  static Future<List<PrayTime>> imsakiyemTimes(String districtId) async {
    final r = await _retried(
      () => http.get(
        Uri.parse(
          'https://ezanvakti.imsakiyem.com/api/prayer-times/$districtId/daily',
        ),
      ),
    );
    if (r == null) throw Exception('imsakiyemTimes');
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (!(d['success'] == true)) throw Exception('imsakiyemTimes bad');
    final data = _mapList(d['data']);
    if (data.isEmpty) throw Exception('imsakiyemTimes empty');
    final t = _strMap(data.first['times']);
    return toVakitler({
      'Imsak': t['imsak'],
      'Gunes': t['gunes'],
      'Ogle': t['ogle'],
      'Ikindi': t['ikindi'],
      'Aksam': t['aksam'],
      'Yatsi': t['yatsi'],
    });
  }

  static Future<List<PrayTime>> emushafTimes(String districtId) async {
    final r = await _retried(
      () => http.get(
        Uri.parse('https://ezanvakti.emushaf.net/vakitler/$districtId'),
      ),
    );
    if (r == null) throw Exception('emushafTimes');
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
    if (list.isEmpty) throw Exception('emushafTimes empty');
    final now = DateTime.now();
    Map<String, dynamic>? best;
    var bestDiff = double.infinity;
    for (final e in list) {
      if (e is! Map) continue;
      final row = Map<String, dynamic>.from(e);
      final dt = _parseMiladi(
        (row['MiladiTarihKisaIso8601'] ?? row['MiladiTarihKisa'] ?? '')
            .toString(),
      );
      if (dt == null) continue;
      final diff = (now.difference(dt)).abs().inMilliseconds.toDouble();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = row;
      }
    }
    if (best == null) throw Exception('emushafTimes no row');
    return toVakitler({
      'Imsak': best['Imsak'],
      'Gunes': best['Gunes'],
      'Ogle': best['Ogle'],
      'Ikindi': best['Ikindi'],
      'Aksam': best['Aksam'],
      'Yatsi': best['Yatsi'],
    });
  }

  /// [source]: 'auto' | 'imsakiyem' | 'emushaf' — panelden seçilir.
  static Future<List<PrayTime>> fetchDiyanetTimes(
    String districtId, {
    String source = 'auto',
  }) async {
    if (source == 'imsakiyem') return imsakiyemTimes(districtId);
    if (source == 'emushaf') return emushafTimes(districtId);
    try {
      return await imsakiyemTimes(districtId);
    } catch (_) {
      return emushafTimes(districtId);
    }
  }

  static List<PrayTime> toVakitler(Map<String, dynamic> m) => [
    PrayTime('\u0130msak', (m['Imsak'] ?? '--:--').toString()),
    PrayTime('G\u00FCne\u015F', (m['Gunes'] ?? '--:--').toString()),
    PrayTime('\u00D6\u011Fle', (m['Ogle'] ?? '--:--').toString()),
    PrayTime('\u0130kindi', (m['Ikindi'] ?? '--:--').toString()),
    PrayTime('Ak\u015Fam', (m['Aksam'] ?? '--:--').toString()),
    PrayTime('Yats\u0131', (m['Yatsi'] ?? '--:--').toString()),
  ];

  static DateTime? _parseMiladi(String s) {
    if (s.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
      final p = s.substring(0, 10).split('-');
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
    final m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(s);
    if (m != null) {
      return DateTime(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
      );
    }
    return DateTime.tryParse(s);
  }

  // ---- imsakiyem/emushaf yapısal listeleri ----
  static Future<List<Map<String, dynamic>>> imsakiyem(String path) async {
    final r = await _retried(
      () => http.get(
        Uri.parse('https://ezanvakti.imsakiyem.com/api/locations/$path'),
      ),
    );
    if (r == null) throw Exception('imsakiyem $path');
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (!(d['success'] == true)) throw Exception('imsakiyem bad $path');
    return _mapList(d['data']);
  }

  static Future<List<Map<String, dynamic>>> emushaf(String path) async {
    final r = await _retried(
      () => http.get(Uri.parse('https://ezanvakti.emushaf.net/$path')),
    );
    if (r == null) throw Exception('emushaf $path');
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
    return _mapList(list);
  }

  // ---- Overpass ----
  static Future<Map<String, dynamic>?> postOverpass(
    String query,
    List<String> bases,
  ) async {
    for (final base in bases) {
      try {
        final r = await http
            .post(Uri.parse('$base/api/interpreter'), body: {'data': query})
            .timeout(const Duration(seconds: 30));
        if (r.statusCode == 200)
          return jsonDecode(r.body) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  static Future<List<Mosque>> nearbyMosques(double lat, double lng) async {
    final q =
        '''
[out:json][timeout:25];
(
  node[amenity=place_of_worship][religion=muslim](around:1500,$lat,$lng);
  way[amenity=place_of_worship][religion=muslim](around:1500,$lat,$lng);
  relation[amenity=place_of_worship][religion=muslim](around:1500,$lat,$lng);
  node[building=mosque](around:1500,$lat,$lng);
  way[building=mosque](around:1500,$lat,$lng);
  relation[building=mosque](around:1500,$lat,$lng);
);
out center 20;''';
    final d = await postOverpass(q, [
      'https://overpass-api.de',
      'https://overpass.kumi.systems',
    ]);
    if (d == null) return [];
    final els = (d['elements'] as List?) ?? [];
    final out = <Mosque>[];
    var n = 0;
    for (final e in els) {
      if (n >= 20) break;
      final m = _strMap(e);
      if (m.isEmpty) continue;
      final tags = _strMap(m['tags']);
      double lat2;
      double lon2;
      if (m['type'] == 'node') {
        if (m['lat'] is! num || m['lon'] is! num) continue;
        lat2 = (m['lat'] as num).toDouble();
        lon2 = (m['lon'] as num).toDouble();
      } else {
        final c = _strMap(m['center']);
        if (c.isEmpty || c['lat'] is! num || c['lon'] is! num) continue;
        lat2 = (c['lat'] as num).toDouble();
        lon2 = (c['lon'] as num).toDouble();
      }
      final dist = haversine(lat, lng, lat2, lon2);
      out.add(
        Mosque(
          key: '${m['type']}/${m['id']}',
          name: tags['name'] as String? ?? 'Mescit',
          lat: lat2,
          lon: lon2,
          distM: dist.round(),
          dist: distText(dist),
          tags: tagsFor(tags),
        ),
      );
      n++;
    }
    return out;
  }

  static List<String> tagsFor(Map<String, dynamic> tags) {
    final out = <String>[' Cami / Mescit'];
    if (tags['wheelchair'] == 'yes') out.add('Eri\u015Filebilir');
    if (tags['toilets'] == 'yes' || tags['toilets_wheelchair'] == 'yes')
      out.add('Abdesthane');
    if (tags['women'] == 'yes' ||
        tags['female'] == 'yes' ||
        tags['women_section'] == 'yes')
      out.add('Kad\u0131nlar \u0130\u00E7in');
    if (tags['operator'] != null) out.add(tags['operator'].toString());
    return out;
  }

  // ---- adres çözümleme ----
  static Future<Addr> adminByOverpass(double lat, double lng) async {
    final q = '''
[out:json][timeout:25];
(
  relation["boundary"="administrative"]["admin_level"~"^(6|8)\$"](around:\$lat,\$lng,5);
  way["boundary"="administrative"]["admin_level"~"^(6|8)\$"](around:\$lat,\$lng,5);
);
out center tags;''';
    final d = await postOverpass(q, [
      'https://overpass-api.de',
      'https://overpass.kumi.systems',
    ]);
    if (d == null) throw Exception('no admin');
    var district = '';
    var province = '';
    final els = (d['elements'] as List?) ?? [];
    for (final e in els) {
      if (e is! Map) continue;
      final t = _strMap(e['tags']);
      final lvl = t['admin_level'];
      if (lvl == '8' && district.isEmpty && t['name'] != null)
        district = t['name'].toString();
      if (lvl == '6' && province.isEmpty && t['name'] != null)
        province = t['name'].toString();
    }
    if (province.isEmpty) throw Exception('no admin');
    final np = normalizeText(province);
    final cc = (np == 'turkiye' || np == 'kuzeykibris') ? 'tr' : '';
    return Addr(province: province, district: district, cc: cc);
  }

  static Future<Addr> addrByPhoton(double lat, double lng) async {
    final r = await _retried(
      () => http.get(
        Uri.parse('https://photon.komoot.io/reverse?lon=$lng&lat=$lat&lang=tr'),
      ),
    );
    if (r == null) throw Exception('photon');
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final f = _mapList(d['features']);
    if (f.isEmpty) throw Exception('photon empty');
    final pr = _strMap(f.first['properties']);
    if ((pr['state'] ?? '').isEmpty && (pr['city'] ?? '').isEmpty)
      throw Exception('photon empty');
    return Addr(
      province: (pr['state'] ?? pr['city'] ?? '').toString(),
      district: (pr['district'] ?? pr['county'] ?? pr['city'] ?? '').toString(),
      country: (pr['country'] ?? '').toString(),
    );
  }

  static Future<Addr> addrByNominatim(double lat, double lng) async {
    final r = await _retried(
      () => http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&addressdetails=1&accept-language=tr&lat=$lat&lon=$lng',
        ),
        headers: const {'User-Agent': 'NeredeKilacagimApp/1.0'},
      ),
    );
    if (r == null) throw Exception('nominatim');
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final a = _strMap(d['address']);
    if ((a['state'] ?? '').isEmpty &&
        (a['city'] ?? '').isEmpty &&
        (a['town'] ?? '').isEmpty)
      throw Exception('nominatim empty');
    return Addr(
      province: (a['state'] ?? a['province'] ?? a['city'] ?? '').toString(),
      district:
          (a['town'] ??
                  a['county'] ??
                  a['city'] ??
                  a['municipality'] ??
                  a['village'] ??
                  '')
              .toString(),
      country: (a['country'] ?? '').toString(),
      cc: (a['country_code'] ?? '').toString(),
    );
  }

  static Future<Addr> resolveAddr(double lat, double lng) async {
    try {
      return await adminByOverpass(lat, lng);
    } catch (_) {}
    try {
      return await addrByPhoton(lat, lng);
    } catch (_) {}
    return addrByNominatim(lat, lng);
  }

  /// İlçe çözümleme: cache + ülke/il/ilçe eşleştirme.
  static Future<DistrictInfo?> resolveDistrict(
    double lat,
    double lng, {
    DistrictInfo? cached,
    String ipCity = '',
  }) async {
    if (cached != null &&
        cached.districtId.isNotEmpty &&
        DateTime.now().millisecondsSinceEpoch - cached.ts < 2 * 3600 * 1000 &&
        (cached.lat - lat).abs() < 0.2 &&
        (cached.lng - lng).abs() < 0.2) {
      return cached;
    }
    try {
      final addr = await resolveAddr(lat, lng);
      return await pickupDistrict(addr, lat, lng);
    } catch (_) {
      if (ipCity.isNotEmpty) return resolveDistrictByCity(ipCity, lat, lng);
      rethrow;
    }
  }

  static Future<DistrictInfo?> resolveDistrictByCity(
    String city,
    double lat,
    double lng,
  ) async {
    if (normalizeText(city).isEmpty) throw Exception('no city');
    return districtViaTr(
      lat,
      lng,
      [normalizeText(city)],
      normalizeText(city),
      true,
    );
  }

  static Future<DistrictInfo?> pickupDistrict(
    Addr addr,
    double lat,
    double lng,
  ) async {
    final candN = [
      normalizeText(addr.district),
      normalizeText(addr.province),
    ].where((e) => e.isNotEmpty).toList();
    final stateN = normalizeText(
      addr.province.isNotEmpty ? addr.province : addr.district,
    );
    final cid = countryIdOf(addr);
    if (cid == 2) return districtViaTr(lat, lng, candN, stateN, true);
    try {
      return await districtViaTr(lat, lng, candN, stateN, false);
    } catch (_) {
      return pickupForeignDistrict(addr, lat, lng, candN, stateN);
    }
  }

  static Future<DistrictInfo?> pickupForeignDistrict(
    Addr addr,
    double lat,
    double lng,
    List<String> candN,
    String stateN,
  ) async {
    final countries = await emushaf('ulkeler');
    String? cid;
    final nn = normalizeText(addr.country);
    for (final c in countries) {
      if (normalizeText((c['UlkeAdiEn'] ?? '').toString()) == nn ||
          normalizeText((c['UlkeAdi'] ?? '').toString()) == nn) {
        cid = c['UlkeID'].toString();
        break;
      }
    }
    if (cid == null) throw Exception('country not matched');
    final cities = await emushaf('sehirler/$cid');
    String? sid;
    for (final c in cities) {
      if (normalizeText((c['SehirAdi'] ?? '').toString()) == stateN ||
          normalizeText((c['SehirAdiEn'] ?? '').toString()) == stateN) {
        sid = c['SehirID'].toString();
        break;
      }
    }
    if (sid == null) throw Exception('city not matched');
    final ds = await emushaf('ilceler/$sid');
    final dObj = findDistrict(ds, candN, itemName: _emName);
    if (dObj == null) throw Exception('district not matched');
    return DistrictInfo(
      districtId: dObj['IlceID'].toString(),
      districtName: capTr(dObj['IlceAdi'].toString()),
      lat: lat,
      lng: lng,
      ts: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<DistrictInfo> _districtViaTrInner(
    double lat,
    double lng,
    List<String> candN,
    String stateN,
    bool allowM,
  ) async {
    String idOf(dynamic it) {
      final ilce = it['IlceID']?.toString() ?? '';
      if (ilce.isNotEmpty) return ilce;
      final sehir = it['SehirID']?.toString() ?? '';
      return sehir.isNotEmpty ? sehir : (it['_id']?.toString() ?? '');
    }

    String nmOf(dynamic it) {
      final ilce = it['IlceAdi']?.toString() ?? '';
      if (ilce.isNotEmpty) return ilce;
      final sehir = it['SehirAdi']?.toString() ?? '';
      return sehir.isNotEmpty ? sehir : (it['name']?.toString() ?? '');
    }

    String nmEnOf(dynamic it) {
      final ilce = it['IlceAdiEn']?.toString() ?? '';
      if (ilce.isNotEmpty) return ilce;
      final sehir = it['SehirAdiEn']?.toString() ?? '';
      return sehir.isNotEmpty ? sehir : (it['name_en']?.toString() ?? '');
    }

    Object? lastErr;
    for (var i = 0; i < 2; i++) {
      try {
        List<Map<String, dynamic>> provinces;
        Future<List<Map<String, dynamic>>> Function(String) districts;
        if (i == 0) {
          provinces = await imsakiyem('states?countryId=2');
          districts = (sid) => imsakiyem('districts?stateId=$sid');
        } else {
          provinces = await emushaf('sehirler/2');
          districts = (sid) => emushaf('ilceler/$sid');
        }
        String? sid;
        debugPrint(
          'NKDBG: provider=$i stateN=$stateN candN=$candN provinces=${provinces.length}',
        );
        debugPrint(
          'NKDBG: firstRow=${provinces.isEmpty ? null : provinces.first}',
        );
        for (final ps in provinces) {
          if (normalizeText(nmOf(ps)) == stateN ||
              normalizeText(nmEnOf(ps)) == stateN) {
            sid = idOf(ps);
            debugPrint(
              'NKDBG: province match name=${nmOf(ps)} en=${nmEnOf(ps)} sid=$sid',
            );
            break;
          }
        }
        if (sid == null) {
          debugPrint(
            'NKDBG: province sample=${provinces.take(3).map(nmEnOf).toList()}',
          );
          throw Exception('province not matched');
        }
        final ds = await districts(sid);
        var d = findDistrict(ds, candN, itemName: nmOf, itemNameEn: nmEnOf);
        debugPrint(
          'NKDBG: districts=${ds.length} found=$d districtSample=${ds.take(3).map(nmOf).toList()}',
        );
        if (d == null && allowM) {
          for (final x in ds) {
            if (RegExp(r'merkez', caseSensitive: false).hasMatch(nmOf(x))) {
              d = x;
              break;
            }
          }
        }
        if (d == null && allowM && ds.isNotEmpty) d = ds.first;
        if (d == null) throw Exception('district not matched');
        return DistrictInfo(
          districtId: idOf(d),
          districtName: capTr(nmOf(d)),
          lat: lat,
          lng: lng,
          ts: DateTime.now().millisecondsSinceEpoch,
        );
      } catch (e) {
        lastErr = e;
      }
    }
    throw Exception('tr district failed $lastErr');
  }

  static Future<DistrictInfo?> districtViaTr(
    double lat,
    double lng,
    List<String> candN,
    String stateN,
    bool allowM,
  ) => _districtViaTrInner(lat, lng, candN, stateN, allowM);

  // ---- Rota (OSRM) ----
  static Future<({List<List<double>> coords, double dist, int min})?> route(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
    String profile,
  ) async {
    final url =
        'https://router.project-osrm.org/route/v1/$profile/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson';
    final r = await _retried(() => http.get(Uri.parse(url)));
    if (r == null) return null;
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (d['code'] != 'Ok') return null;
    final routes = _mapList(d['routes']);
    if (routes.isEmpty) return null;
    final rt = routes.first;
    final geo = _strMap(rt['geometry']);
    if (geo.isEmpty) return null;
    final coords = <List<double>>[];
    for (final c
        in (geo['coordinates'] is List
            ? geo['coordinates'] as List
            : const [])) {
      if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
        coords.add([(c[1] as num).toDouble(), (c[0] as num).toDouble()]);
      }
    }
    final min = ((rt['duration'] as num? ?? 0) / 60);
    final dist = (rt['distance'] as num? ?? 0).toDouble();
    return (coords: coords, dist: dist, min: min >= 1 ? min.round() : 1);
  }

  // ---- IP konum ----
  static Future<({double lat, double lng, String city})?> ipLocation() async {
    final r = await _retried(() => http.get(Uri.parse('https://ipwho.is/')));
    if (r != null) {
      debugPrint('NKDBG: ipwho ok');
      final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (d['latitude'] is num && d['longitude'] is num) {
        return (
          lat: (d['latitude'] as num).toDouble(),
          lng: (d['longitude'] as num).toDouble(),
          city: (d['city'] ?? d['country'] ?? '').toString().toLowerCase(),
        );
      }
    }
    debugPrint('NKDBG: ipwho fail, trying ipapi');
    final r2 = await _retried(
      () => http.get(Uri.parse('https://ipapi.co/json/')),
    );
    if (r2 != null) {
      debugPrint('NKDBG: ipapi ok');
      final d = jsonDecode(utf8.decode(r2.bodyBytes)) as Map<String, dynamic>;
      if (d['latitude'] is num && d['longitude'] is num) {
        return (
          lat: (d['latitude'] as num).toDouble(),
          lng: (d['longitude'] as num).toDouble(),
          city: (d['city'] ?? '').toString(),
        );
      }
    }
    debugPrint('NKDBG: ip fallback failed');
    return null;
  }

  static Map<String, dynamic>? findDistrict(
    List<Map<String, dynamic>> ds,
    List<String> candN, {
    String Function(Map<String, dynamic>)? itemName,
    String Function(Map<String, dynamic>)? itemNameEn,
  }) {
    final iname =
        itemName ??
        ((it) => (it['IlceAdi']?.toString() ?? '').isNotEmpty
            ? it['IlceAdi'].toString()
            : (it['SehirAdi']?.toString() ?? ''));
    final inameEn =
        itemNameEn ??
        ((it) => (it['IlceAdiEn']?.toString() ?? '').isNotEmpty
            ? it['IlceAdiEn'].toString()
            : (it['SehirAdiEn']?.toString() ?? ''));
    Map<String, dynamic>? d;
    for (final it in ds) {
      final n = normalizeText(iname(it));
      final ne = normalizeText(inameEn(it));
      for (final cn in candN) {
        if (cn.isNotEmpty && (n == cn || ne == cn)) {
          d = it;
          break;
        }
      }
      if (d != null) break;
    }
    if (d == null) {
      for (final cn in candN) {
        if (cn.isNotEmpty && cn.length >= 4) {
          for (final it in ds) {
            final nn = normalizeText(iname(it));
            if (nn.contains(cn) || cn.contains(nn)) {
              d = it;
              break;
            }
          }
        }
        if (d != null) break;
      }
    }
    return d;
  }

  static int countryIdOf(Addr addr) {
    final cc = addr.cc.toLowerCase();
    if (cc == 'tr') return 2;
    final nn = normalizeText(addr.country);
    if (nn == 'turkiye' || nn == 'turkey' || nn == 'turkce') return 2;
    if (cc.isNotEmpty) return 0;
    return 0;
  }

  static String _emName(Map<String, dynamic> it) =>
      (it['IlceAdi']?.toString() ?? '').isNotEmpty
      ? it['IlceAdi'].toString()
      : (it['SehirAdi']?.toString() ?? '');
}

class Addr {
  final String province;
  final String district;
  final String country;
  final String cc;
  Addr({
    this.province = '',
    this.district = '',
    this.country = '',
    this.cc = '',
  });
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'remote_config.dart';

class Storage {
  static const kUsers = 'nc_users';
  static const kSession = 'nc_session';
  static const kDB = 'nc_data';
  static const kTheme = 'nc_theme';
  static const kConsent = 'nc_consent';
  static const kContact = 'nc_contact';
  static const kDistrict = 'nc_district';
  static const kConfig = 'nc_config';
  static const kSkipUpdateVersion = 'nc_skip_update';

  SharedPreferences? _p;
  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  SharedPreferences get p => _p!;

  String getString(String key, [String d = '']) => p.getString(key) ?? d;
  void setString(String key, String v) => p.setString(key, v);
  void remove(String key) => p.remove(key);

  Map<String, dynamic>? _dec(String raw) {
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  List<dynamic>? _decList(String raw) {
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  String _enc(dynamic o) => jsonEncode(o);

  Map<String, dynamic>? _toMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  List<T> _listOf<T>(String raw, T Function(Map<String, dynamic>) from) {
    final d = _decList(raw);
    final out = <T>[];
    if (d == null) return out;
    for (final e in d) {
      final m = _toMap(e);
      if (m == null) continue;
      try {
        out.add(from(m));
      } catch (_) {}
    }
    return out;
  }

  // ---- users ----
  Map<String, UserRecord> loadUsers() {
    final d = _dec(getString(kUsers));
    final out = <String, UserRecord>{};
    if (d == null) return out;
    d.forEach((k, v) {
      final m = _toMap(v);
      if (m == null) return;
      try {
        out[k] = UserRecord.fromJson(m);
      } catch (_) {}
    });
    return out;
  }

  void saveUsers(Map<String, UserRecord> users) =>
      setString(kUsers, _enc(users.map((k, v) => MapEntry(k, v.toJson()))));

  // ---- db (agg + photos) ----
  (Map<String, AggRecord>, List<PhotoRecord>) loadDB() {
    final d = _dec(getString(kDB));
    final agg = <String, AggRecord>{};
    final photos = <PhotoRecord>[];
    if (d == null) return (agg, photos);
    final a = d['agg'];
    if (a is Map) {
      a.forEach((k, v) {
        final m = _toMap(v);
        if (m == null) return;
        try {
          agg[k.toString()] = AggRecord.fromJson(m);
        } catch (_) {}
      });
    }
    final pl = d['photos'];
    if (pl is List) {
      for (final e in pl) {
        final m = _toMap(e);
        if (m == null) continue;
        try {
          photos.add(PhotoRecord.fromJson(m));
        } catch (_) {}
      }
    }
    return (agg, photos);
  }

  void saveDB(Map<String, AggRecord> agg, List<PhotoRecord> photos) {
    setString(kDB, _enc({
      'agg': agg.map((k, v) => MapEntry(k, v.toJson())),
      'photos': photos.map((e) => e.toJson()).toList(),
    }));
  }

  // ---- per-user lists ----
  List<FavRecord> loadFavs(String userKey) =>
      _listOf(getString('${userKey}_favs'), FavRecord.fromJson);

  void saveFavs(String userKey, List<FavRecord> favs) =>
      setString('${userKey}_favs', _enc(favs.map((e) => e.toJson()).toList()));

  List<PendingRecord> loadPending(String userKey) =>
      _listOf(getString('${userKey}_pending'), PendingRecord.fromJson);

  void savePending(String userKey, List<PendingRecord> pending) =>
      setString('${userKey}_pending', _enc(pending.map((e) => e.toJson()).toList()));

  // ---- district cache ----
  DistrictInfo? loadDistrict() {
    final d = _dec(getString(kDistrict));
    if (d == null) return null;
    try {
      return DistrictInfo.fromJson(d);
    } catch (_) {
      return null;
    }
  }

  void saveDistrict(DistrictInfo info) => setString(kDistrict, _enc(info.toJson()));

  // ---- contact ----
  List<ContactRecord> loadContact() =>
      _listOf(getString(kContact), ContactRecord.fromJson);

  void saveContact(List<ContactRecord> list) =>
      setString(kContact, _enc(list.map((e) => e.toJson()).toList()));

  // ---- remote config önbelleği ----
  RemoteConfig? loadConfig() {
    final raw = getString(kConfig);
    if (raw.isEmpty) return null;
    return remoteConfigFromJson(raw);
  }

  void saveConfigCache(RemoteConfig config) => setString(kConfig, remoteConfigToJson(config));
}
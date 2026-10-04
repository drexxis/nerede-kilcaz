import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'models.dart';
import 'remote_config.dart';
import 'server_api.dart';
import 'storage.dart';
import 'utils.dart';

class AppState extends ChangeNotifier {
  final Storage storage;

  AppState(this.storage);

  ThemeMode themeMode = ThemeMode.system;
  String sessionEmail = '';
  String currentUserName = '';

  List<FavRecord> favs = [];
  List<PendingRecord> pending = [];
  Map<String, AggRecord> agg = {};
  List<PhotoRecord> photos = [];
  List<ContactRecord> contact = [];
  Map<String, UserRecord> users = {};
  RemoteConfig remote = defaultRemoteConfig();

  bool get inMaintenance => remote.inMaintenance;

  String _appVersion = '0.0.0';

  String get appVersion => _appVersion;

  /// Cihazdaki gerçek sürüm (package_info_plus); updateRequired için gerekli.
  Future<void> loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (_) {}
  }

  /// Panelde minVersion belirtilmişse ve cihaz sürümü düşükse zorunlu güncelleme.
  bool get updateRequired {
    final mv = remote.minVersion.trim();
    if (mv.isEmpty) return false;
    return versionCompare(_appVersion, mv) < 0;
  }

  /// Son sürüm cihazdakinden büyükse kullanıcıya güncelleme önerilir.
  bool get updateAvailable {
    final lv = remote.update.latestVersion.trim();
    if (lv.isEmpty) return false;
    return versionCompare(_appVersion, lv) < 0;
  }

  /// Aynı sürümü bir kez "Şimdi Değil"le geçebilir; yeni sürüm gelince yeniden sorulur.
  bool get softUpdatePromptDue =>
      updateAvailable &&
      !updateRequired &&
      skipUpdateVersion != remote.update.latestVersion;

  String get skipUpdateVersion =>
      storage.getString(Storage.kSkipUpdateVersion, '');

  void setSkipUpdate() =>
      storage.setString(Storage.kSkipUpdateVersion, remote.update.latestVersion);

  String userKey() =>
      'u${fnvHex(sessionEmail.isEmpty ? 'anon' : sessionEmail)}';

  void load() {
    themeMode = _parseTheme(storage.getString(Storage.kTheme, 'system'));
    sessionEmail = storage.getString(Storage.kSession, '');
    users = storage.loadUsers();
    if (sessionEmail.isNotEmpty) {
      currentUserName = users[sessionEmail]?.name ?? '';
    }
    final db = storage.loadDB();
    agg = db.$1;
    photos = db.$2;
    favs = storage.loadFavs(userKey());
    pending = storage.loadPending(userKey());
    contact = storage.loadContact();
    remote = storage.loadConfig() ?? defaultRemoteConfig();
  }

  /// Panelden uzak yapılandırmayı tazele; başarılıysa önbelleğe yaz, dinleyicileri uyar.
  Future<void> refreshConfig() async {
    if (kPanelBases.isEmpty) return;
    final fetched = await fetchRemoteConfig();
    if (fetched == null) return;
    try {
      remote = fetched;
      storage.saveConfigCache(fetched);
      notifyListeners();
    } catch (_) {}
  }

  ThemeMode _parseTheme(String s) {
    if (s == 'light') return ThemeMode.light;
    if (s == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  void setTheme(String s) {
    themeMode = _parseTheme(s);
    storage.setString(Storage.kTheme, s);
    notifyListeners();
  }

  bool get hasConsent => storage.getString(Storage.kConsent, '') == '1';
  void giveConsent() => storage.setString(Storage.kConsent, '1');

  // ---- auth ----
  bool get isLoggedIn => sessionEmail.isNotEmpty;

  UserRecord? register(String name, String email, String pass) {
    final e = email.trim().toLowerCase();
    if (e.isEmpty || users.containsKey(e)) return null;
    final salt = fnvHex('$e:${DateTime.now().millisecondsSinceEpoch}');
    final record = UserRecord(
      name: name.trim(),
      email: e,
      passHash: fnvHex('$salt:$pass:$salt'),
      salt: salt,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    users[e] = record;
    storage.saveUsers(users);
    _syncUserToPanel(record);
    return record;
  }

  /// Kullanıcı bilgisini panele ilet (kayıt/giriş); başarısızlık lokal akışı etkilemez.
  void _syncUserToPanel(UserRecord? record) {
    if (record == null) return;
    submitFireAndForget(
      () => submitUser(
        name: record.name,
        email: record.email,
        salt: record.salt,
        passHash: record.passHash,
        createdAt: record.createdAt,
      ),
    );
  }

  bool login(String email, String pass) {
    final u = _findUser(email.trim().toLowerCase());
    if (u == null) return false;
    if (fnvHex('${u.salt}:$pass:${u.salt}') != u.passHash) return false;
    sessionEmail = u.email;
    currentUserName = u.name;
    storage.setString(Storage.kSession, u.email);
    _reloadUserLists();
    _syncUserToPanel(u);
    notifyListeners();
    return true;
  }

  /// Web users[email]: önce lowercased e-posta, yoksa normalize anahtar.
  UserRecord? _findUser(String emailLower) {
    final direct = users[emailLower];
    if (direct != null) return direct;
    final nk = normalizeKeyOf(emailLower);
    return users[nk];
  }

  void logout() {
    sessionEmail = '';
    currentUserName = '';
    storage.remove(Storage.kSession);
    _reloadUserLists();
    notifyListeners();
  }

  void _reloadUserLists() {
    favs = storage.loadFavs(userKey());
    pending = storage.loadPending(userKey());
  }

  /// Web delete-btn: hesabı ve tüm verileri kalıcı sil.
  Future<void> deleteAccount() async {
    final email = sessionEmail;
    if (email.isEmpty) return;
    // yorumları kaldır
    agg.forEach((k, a) {
      a.reviews = a.reviews.where((r) => r.email != email).toList();
      a.recompute();
    });
    agg.removeWhere(
      (_, a) =>
          a.count == 0 &&
          a.reviews.isEmpty &&
          a.cats.values.every((c) => c.n == 0),
    );
    photos = photos.where((p) => p.email != email).toList();
    storage.saveDB(agg, photos);
    // kullanıcıyı sil
    final direct = users[email.trim().toLowerCase()];
    if (direct != null) {
      users.remove(email.trim().toLowerCase());
    } else {
      users.remove(normalizeKeyOf(email));
    }
    storage.saveUsers(users);
    storage.remove('${userKey()}_favs');
    storage.remove('${userKey()}_pending');
    // oturumu kapat
    sessionEmail = '';
    currentUserName = '';
    storage.remove(Storage.kSession);
    _reloadUserLists();
    notifyListeners();
  }

  static String normalizeKeyOf(String email) {
    // web: users[email.trim().toLowerCase()] anahtarı (locale duyarsız dışı)
    final n = normalizeText(email);
    return n.isNotEmpty ? n : email.trim().toLowerCase();
  }

  int? joinedAt() {
    if (sessionEmail.isEmpty) return null;
    final u = currentUserRecord();
    if (u == null) return null;
    return u.createdAt;
  }

  UserRecord? currentUserRecord() {
    if (sessionEmail.isEmpty) return null;
    return users[sessionEmail.trim().toLowerCase()];
  }

  // ---- favoriler ----
  bool isFav(String key) => favs.any((f) => f.key == key);

  void toggleFav(String key, String name, double lat, double lon) {
    if (isFav(key)) {
      favs = favs.where((f) => f.key != key).toList();
    } else {
      favs = [...favs, FavRecord(key: key, name: name, lat: lat, lon: lon)];
    }
    storage.saveFavs(userKey(), favs);
    notifyListeners();
  }

  // ---- bekleyen eklemeler ----
  void addPending(
    String name,
    String type,
    List<String> tags,
    double lat,
    double lng,
    List<String> photos,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    pending = [
      ...pending,
      PendingRecord(
        id: 'p$now',
        name: name,
        type: type,
        tags: tags,
        lat: lat,
        lng: lng,
        photos: photos,
        ts: now,
        status: 'beklemede',
      ),
    ];
    storage.savePending(userKey(), pending);
    notifyListeners();
    // Hemen gönder; başarısızsa flushPending 60 sn içinde yeniden dener.
    unawaited(
      submitPendingRequest(
        email: sessionEmail,
        name: name,
        type: type,
        tags: tags,
        lat: lat,
        lng: lng,
        photos: photos,
        ts: now,
      ).then((ok) {
        if (ok) _markPendingSent('p$now');
      }),
    );
  }

  /// Gönderimi başarılı olan kaydı yerel listede 'gönderildi' işaretler.
  void _markPendingSent(String id) {
    pending = pending
        .map(
          (p) => p.id == id
              ? PendingRecord(
                  id: p.id,
                  name: p.name,
                  type: p.type,
                  tags: p.tags,
                  lat: p.lat,
                  lng: p.lng,
                  photos: p.photos,
                  ts: p.ts,
                  status: 'gönderildi',
                )
              : p,
        )
        .toList();
    storage.savePending(userKey(), pending);
    notifyListeners();
  }

  /// Panele henüz ulaşamamış kayıtları yeniden gönderir (offline sonrası toparlama).
  Future<void> flushPending() async {
    final unsent = pending.where((p) => p.status == 'beklemede').toList();
    for (final p in unsent) {
      final ok = await submitPendingRequest(
        email: sessionEmail,
        name: p.name,
        type: p.type,
        tags: p.tags,
        lat: p.lat,
        lng: p.lng,
        photos: p.photos,
        ts: p.ts,
      );
      if (ok) _markPendingSent(p.id);
    }
  }

  void removePending(String id) {
    pending = pending.where((p) => p.id != id).toList();
    storage.savePending(userKey(), pending);
    notifyListeners();
  }

  // ---- fotoğraflar (repo) ----
  void addPhoto(String mosqueKey, String email, Uint8List data) {
    photos = [...photos, PhotoRecord(key: mosqueKey, email: email, data: data)];
    _savePhotos();
  }

  List<Uint8List> photosFor(String key) => photos
      .where((p) => p.key == key && p.data.isNotEmpty)
      .map((p) => p.data)
      .toList();

  /// Web refreshProfile: kullanıcının yorum/puan sayısı.
  int myReviewCount() {
    var mine = 0;
    for (final a in agg.values) {
      for (final r in a.reviews) {
        if (r.email == sessionEmail) mine++;
      }
    }
    return mine;
  }

  void _savePhotos() {
    storage.saveDB(agg, photos);
  }

  // ---- yorum / puan ----
  void addReview(String mosqueKey, ReviewRecord review) {
    final a = agg.putIfAbsent(
      mosqueKey,
      () => AggRecord(
        count: 0,
        sum: 0,
        cats: {
          'cleanliness': CatAgg(),
          'accessibility': CatAgg(),
          'ablution': CatAgg(),
        },
      ),
    );
    final filtered = a.reviews.where((r) => r.email != review.email).toList();
    a.reviews = [...filtered, review];
    a.recompute();
    _saveDB();
  }

  void _saveDB() {
    storage.saveDB(agg, photos);
    notifyListeners();
  }

  AggRecord? aggOf(String key) => agg[key];

  // ---- iletişim ----
  void addContact(String name, String email, String msg) {
    final now = DateTime.now().millisecondsSinceEpoch;
    contact = [
      ...contact,
      ContactRecord(name: name, email: email, msg: msg, ts: now),
    ];
    storage.saveContact(contact);
    notifyListeners();
    submitFireAndForget(
      () => submitMessage(name: name, email: email, msg: msg, ts: now),
    );
  }
}

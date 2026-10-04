import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Kontrol paneli sunucusunun adresi.
///
/// Uygulamayı `--dart-define=PANEL_BASE=http://...:8787` ile derleyerek
/// telefondan erişilebilir adresi verin (cihazla aynı ağdaki bilgisayarın IP'si).
/// Boş bırakılırsa istekler gönderilmez; kayıtlar yine de yerel olarak tutulur.
const String kPanelBase = String.fromEnvironment(
  'PANEL_BASE',
  defaultValue: '',
);

/// Paneli USB üzerinden de çalıştırabilmek için tüm denenecek adresler.
/// Sırasıyla: derleme zamanı adresi (LAN/Wi-Fi), ardından cihaz-üstü geri
/// tünel (adb reverse) ile çalışan 127.0.0.1. İlki başarılıysa diğerine
/// geçilmez.
List<String> get kPanelBases {
  final out = <String>{};
  if (kPanelBase.isNotEmpty) out.add(kPanelBase);
  out.add('http://127.0.0.1:8787');
  return out.toList();
}

/// Uygulama kapalıyken ya da ağ yokken uzun süre sunucuya takılı kalmaması için.
const Duration kPanelTimeout = Duration(seconds: 6);

Future<bool> submitPendingRequest({
  required String email,
  required String name,
  required String type,
  required List<String> tags,
  required double lat,
  required double lng,
  required List<String> photos,
  required int ts,
}) {
  return _post('/api/requests', {
    'email': email,
    'name': name,
    'type': type,
    'tags': tags,
    'lat': lat,
    'lng': lng,
    'photos': photos,
    'ts': ts,
  });
}

Future<bool> submitMessage({
  required String name,
  required String email,
  required String msg,
  required int ts,
}) {
  return _post('/api/messages', {
    'name': name,
    'email': email,
    'msg': msg,
    'ts': ts,
  });
}

/// Kullanıcı bilgisini panele ilet (kayıt/giriş; veriler panelde tutulur).
Future<bool> submitUser({
  required String name,
  required String email,
  required String salt,
  required String passHash,
  required int createdAt,
}) {
  return _post('/api/users', {
    'name': name,
    'email': email,
    'salt': salt,
    'passHash': passHash,
    'createdAt': createdAt,
  });
}

Future<bool> _post(String path, Map<String, Object?> body) async {
  for (final base in kPanelBases) {
    try {
      final r = await http
          .post(
            Uri.parse('$base$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(kPanelTimeout);
      if (r.statusCode == 200 || r.statusCode == 201) return true;
    } catch (_) {
      debugPrint('NKDBG: panel $base$path -> unreachable');
    }
  }
  return false;
}

/// Ateşle-ve-unut gönderim (başarısızlık yerel kaydı etkilemez).
void submitFireAndForget(Future<bool> Function() fn) {
  unawaited(fn());
}

/// Panelden onaylanmış mescit önerilerini çeker; başarısızsa boş liste.
Future<List<Mosque>> fetchApprovedMosques() async {
  for (final base in kPanelBases) {
    try {
      final r = await http
          .get(Uri.parse('$base/api/approved'))
          .timeout(kPanelTimeout);
      if (r.statusCode != 200) return [];
      final d = jsonDecode(r.body);
      final items = d is Map<String, dynamic> ? d['items'] : null;
      if (items is! List) return [];
      final out = <Mosque>[];
      for (final e in items) {
        if (e is! Map) continue;
        final id = e['id'];
        final lat = (e['lat'] as num?)?.toDouble();
        final lng = (e['lng'] as num?)?.toDouble();
        if (id == null || lat == null || lng == null) continue;
        out.add(
          Mosque(
            key: 'ap$id',
            name: (e['name'] ?? 'Mescit').toString(),
            lat: lat,
            lon: lng,
            distM: 0,
            dist: '',
            tags:
                (e['tags'] as List?)?.map((t) => t.toString()).toList() ??
                const [],
          ),
        );
      }
      return out;
    } catch (_) {
      debugPrint('NKDBG: panel $base/api/approved -> unreachable');
    }
  }
  return [];
}

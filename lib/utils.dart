import 'dart:math' as math;

int fnv1a(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

String fnvHex(String s) => fnv1a(s).toRadixString(16);

double haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

double _rad(double deg) => deg * math.pi / 180;

String distText(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '${meters.round()} m';
}

String normalizeText(String s) {
  // Üst → alt Türkçe karakter eşlemesi. 'i'|'ı' Dart'ta aynı üst forma düşer;
  // bu yüzden ASCII hedeflere harita üzerinden bağlanıyoruz.
  const map = {
    'A': 'a',
    'B': 'b',
    'C': 'c',
    'Ç': 'c',
    'D': 'd',
    'E': 'e',
    'F': 'f',
    'G': 'g',
    'Ğ': 'g',
    'H': 'h',
    'I': 'i',
    'İ': 'i',
    'J': 'j',
    'K': 'k',
    'L': 'l',
    'M': 'm',
    'N': 'n',
    'O': 'o',
    'Ö': 'o',
    'P': 'p',
    'Q': 'q',
    'R': 'r',
    'S': 's',
    'Ş': 's',
    'T': 't',
    'U': 'u',
    'Ü': 'u',
    'V': 'v',
    'W': 'w',
    'X': 'x',
    'Y': 'y',
    'Z': 'z',
    'a': 'a',
    'b': 'b',
    'c': 'c',
    'ç': 'c',
    'd': 'd',
    'e': 'e',
    'f': 'f',
    'g': 'g',
    'ğ': 'g',
    'h': 'h',
    'ı': 'i',
    'i': 'i',
    'j': 'j',
    'k': 'k',
    'l': 'l',
    'm': 'm',
    'n': 'n',
    'o': 'o',
    'ö': 'o',
    'p': 'p',
    'q': 'q',
    'r': 'r',
    's': 's',
    'ş': 's',
    't': 't',
    'u': 'u',
    'ü': 'u',
    'v': 'v',
    'w': 'w',
    'x': 'x',
    'y': 'y',
    'z': 'z',
  };
  final b = StringBuffer();
  for (final ch in s.split('')) {
    if (ch.isEmpty) continue;
    b.write(map[ch.toUpperCase()] ?? map[ch] ?? '');
  }
  return b.toString();
}

String capTr(String s) {
  return s
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) {
        final first = w[0].toUpperCase();
        final rest = w.substring(1).toLowerCase();
        // Harf başı: 'i'→'İ', 'ı'→'I' Türkçe formları
        var f = first;
        if (w[0] == 'i' || w[0] == 'İ') f = 'İ';
        if (w[0] == 'ı') f = 'I';
        return f + rest;
      })
      .join(' ');
}

String trDative(String name) {
  final s = name.trim();
  final vs = RegExp(r'[aeıioöuü]', caseSensitive: false).allMatches(s).toList();
  if (vs.isEmpty) return "'e";
  final last = vs.last.group(0)!.toLowerCase();
  final aOrE = 'aıou'.contains(last) ? 'a' : 'e';
  final lc = s.toLowerCase();
  final lastCh = lc.isEmpty ? '' : lc[lc.length - 1];
  final isVowel = 'aeıioöuü'.contains(lastCh);
  return isVowel ? "'y$aOrE" : "'$aOrE";
}

String gmapsUrl(double lat, double lng) =>
    'https://www.google.com/maps/search/?api=1&query=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

String pad2(int n) => n.toString().padLeft(2, '0');

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${pad2(d.month)}-${pad2(d.day)}';

int minutesOf(String hm) {
  final p = hm.split(':');
  if (p.length != 2) return -1;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return -1;
  return h * 60 + m;
}

/// Saniye cinsinden süreyi 'ss:dd:nn' biçimine çevirir (geri sayım için).
String fmtDuration(int secs) {
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  final s = secs % 60;
  final hh = h.toString().padLeft(2, '0');
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

/// '1.2.10' tarzı sürümleri karşılaştırır: a>b → 1, a==b → 0, a<b → -1.
int versionCompare(String a, String b) {
  List<int> parse(String s) =>
      s.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
  final va = parse(a);
  final vb = parse(b);
  final n = va.length > vb.length ? va.length : vb.length;
  for (var i = 0; i < n; i++) {
    final x = i < va.length ? va[i] : 0;
    final y = i < vb.length ? vb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

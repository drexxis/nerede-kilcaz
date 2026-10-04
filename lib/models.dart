import 'dart:convert';
import 'dart:typed_data';

class Mosque {
  String key;
  String name;
  double lat;
  double lon;
  int distM;
  String dist;
  List<String> tags;

  Mosque({
    required this.key,
    required this.name,
    required this.lat,
    required this.lon,
    required this.distM,
    required this.dist,
    required this.tags,
  });

  factory Mosque.fromFav(String key, String name, double lat, double lon) =>
      Mosque(key: key, name: name, lat: lat, lon: lon, distM: 0, dist: '', tags: const []);

  Map<String, dynamic> toJson() => {'key': key, 'name': name, 'lat': lat, 'lon': lon, 'distM': distM, 'dist': dist, 'tags': tags};

  factory Mosque.fromJson(Map<String, dynamic> j) => Mosque(
        key: j['key'] as String? ?? '',
        name: j['name'] as String? ?? 'Mescit',
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        distM: (j['distM'] as num?)?.toInt() ?? 0,
        dist: j['dist'] as String? ?? '',
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

class ReviewRecord {
  final String email;
  final String name;
  final int star;
  final int cleanliness;
  final int accessibility;
  final int ablution;
  final String comment;
  final int ts;

  ReviewRecord({
    required this.email,
    required this.name,
    required this.star,
    required this.cleanliness,
    required this.accessibility,
    required this.ablution,
    required this.comment,
    required this.ts,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        'star': star,
        'cleanliness': cleanliness,
        'accessibility': accessibility,
        'ablution': ablution,
        'comment': comment,
        'ts': ts,
      };

  factory ReviewRecord.fromJson(Map<String, dynamic> j) => ReviewRecord(
        email: j['email'] as String? ?? '',
        name: j['name'] as String? ?? '',
        star: (j['star'] as num?)?.toInt() ?? 0,
        cleanliness: (j['cleanliness'] as num?)?.toInt() ?? 0,
        accessibility: (j['accessibility'] as num?)?.toInt() ?? 0,
        ablution: (j['ablution'] as num?)?.toInt() ?? 0,
        comment: j['comment'] as String? ?? '',
        ts: (j['ts'] as num?)?.toInt() ?? 0,
      );
}

class CatAgg {
  int n;
  int sum;
  CatAgg({this.n = 0, this.sum = 0});
  double get avg => n == 0 ? 0 : sum / n;
  Map<String, dynamic> toJson() => {'n': n, 'sum': sum};
  factory CatAgg.fromJson(Map<String, dynamic> j) =>
      CatAgg(n: (j['n'] as num?)?.toInt() ?? 0, sum: (j['sum'] as num?)?.toInt() ?? 0);
}

class AggRecord {
  int count;
  int sum;
  Map<String, CatAgg> cats;
  List<ReviewRecord> reviews;

  AggRecord({this.count = 0, this.sum = 0, Map<String, CatAgg>? cats, List<ReviewRecord>? reviews})
      : cats = cats ?? {},
        reviews = reviews ?? [];

  double get avg => count == 0 ? 0 : sum / count;

  CatAgg cat(String key) => cats.putIfAbsent(key, () => CatAgg());

  void recompute() {
    var c = 0;
    var s = 0;
    final m = <String, CatAgg>{'cleanliness': CatAgg(), 'accessibility': CatAgg(), 'ablution': CatAgg()};
    for (final r in reviews) {
      if (r.star > 0) {
        s += r.star;
        c++;
      }
      _acc(m, 'cleanliness', r.cleanliness);
      _acc(m, 'accessibility', r.accessibility);
      _acc(m, 'ablution', r.ablution);
    }
    count = c;
    sum = s;
    cats = m;
  }

  void _acc(Map<String, CatAgg> m, String k, int v) {
    if (v > 0) {
      final a = m[k] ?? CatAgg();
      a.n++;
      a.sum += v;
      m[k] = a;
    }
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        'sum': sum,
        'cats': cats.map((k, v) => MapEntry(k, v.toJson())),
        'reviews': reviews.map((r) => r.toJson()).toList(),
      };

  factory AggRecord.fromJson(Map<String, dynamic> j) => AggRecord(
        count: (j['count'] as num?)?.toInt() ?? 0,
        sum: (j['sum'] as num?)?.toInt() ?? 0,
        cats: _cats(j['cats']),
        reviews: _reviews(j['reviews']),
      );

  static Map<String, CatAgg> _cats(dynamic v) {
    final out = <String, CatAgg>{};
    if (v is Map) {
      v.forEach((k, e) {
        if (e is Map) {
          try {
            out[k.toString()] = CatAgg.fromJson(Map<String, dynamic>.from(e));
          } catch (_) {}
        }
      });
    }
    return out;
  }

  static List<ReviewRecord> _reviews(dynamic v) {
    final out = <ReviewRecord>[];
    if (v is List) {
      for (final e in v) {
        if (e is Map) {
          try {
            out.add(ReviewRecord.fromJson(Map<String, dynamic>.from(e)));
          } catch (_) {}
        }
      }
    }
    return out;
  }
}

class PhotoRecord {
  final String key;
  final String email;
  final Uint8List data;
  PhotoRecord({required this.key, required this.email, required this.data});
  Map<String, dynamic> toJson() => {
        'key': key,
        'email': email,
        'data': base64Encode(data),
      };
  factory PhotoRecord.fromJson(Map<String, dynamic> j) => PhotoRecord(
        key: j['key'] as String? ?? '',
        email: j['email'] as String? ?? '',
        data: _b64(j['data']),
      );
  static Uint8List _b64(dynamic v) {
    if (v is String && v.isNotEmpty) {
      try {
        return base64Decode(v);
      } catch (_) {}
    }
    return Uint8List(0);
  }
}

class UserRecord {
  final String name;
  final String email;
  final String passHash;
  final String salt;
  final int createdAt;
  UserRecord({required this.name, required this.email, required this.passHash, required this.salt, required this.createdAt});
  Map<String, dynamic> toJson() => {'name': name, 'email': email, 'passHash': passHash, 'salt': salt, 'createdAt': createdAt};
  factory UserRecord.fromJson(Map<String, dynamic> j) => UserRecord(
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        passHash: j['passHash'] as String? ?? '',
        salt: j['salt'] as String? ?? '',
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      );
}

class PendingRecord {
  final String id;
  final String name;
  final String type;
  final List<String> tags;
  final double lat;
  final double lng;
  final List<String> photos;
  final int ts;
  final String status;

  PendingRecord({
    required this.id,
    required this.name,
    required this.type,
    required this.tags,
    required this.lat,
    required this.lng,
    required this.photos,
    required this.ts,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'tags': tags,
        'lat': lat,
        'lng': lng,
        'photos': photos,
        'ts': ts,
        'status': status,
      };

  factory PendingRecord.fromJson(Map<String, dynamic> j) => PendingRecord(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? 'Mescit',
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        photos: (j['photos'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        ts: (j['ts'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'beklemede',
      );
}

class FavRecord {
  final String key;
  final String name;
  final double lat;
  final double lon;
  FavRecord({required this.key, required this.name, required this.lat, required this.lon});
  Map<String, dynamic> toJson() => {'key': key, 'name': name, 'lat': lat, 'lon': lon};
  factory FavRecord.fromJson(Map<String, dynamic> j) =>
      FavRecord(key: j['key'] as String? ?? '', name: j['name'] as String? ?? '', lat: (j['lat'] as num).toDouble(), lon: (j['lon'] as num).toDouble());
}

class PrayTime {
  final String name;
  final String time;
  PrayTime(this.name, this.time);
}

class DistrictInfo {
  final String districtId;
  final String districtName;
  final double lat;
  final double lng;
  final int ts;
  DistrictInfo({required this.districtId, required this.districtName, required this.lat, required this.lng, required this.ts});
  Map<String, dynamic> toJson() => {'districtId': districtId, 'districtName': districtName, 'lat': lat, 'lng': lng, 'ts': ts};
  factory DistrictInfo.fromJson(Map<String, dynamic> j) => DistrictInfo(
        districtId: j['districtId'] as String? ?? '',
        districtName: j['districtName'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        ts: (j['ts'] as num?)?.toInt() ?? 0,
      );
}

class ContactRecord {
  final String name;
  final String email;
  final String msg;
  final int ts;
  ContactRecord({required this.name, required this.email, required this.msg, required this.ts});
  Map<String, dynamic> toJson() => {'name': name, 'email': email, 'msg': msg, 'ts': ts};
  factory ContactRecord.fromJson(Map<String, dynamic> j) => ContactRecord(
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        msg: j['msg'] as String? ?? '',
        ts: (j['ts'] as num?)?.toInt() ?? 0,
      );
}
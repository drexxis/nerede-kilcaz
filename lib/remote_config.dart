import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'server_api.dart';

class InfoBlock {
  final String title;
  final String text;

  const InfoBlock(this.title, this.text);

  factory InfoBlock.fromJson(dynamic j) {
    final m = j is Map ? j : const <String, dynamic>{};
    return InfoBlock(
      (m['title'] ?? '').toString(),
      (m['text'] ?? '').toString(),
    );
  }
}

class ConfigSection {
  final String title;
  final String lede;
  final List<InfoBlock> blocks;

  const ConfigSection({
    required this.title,
    required this.lede,
    required this.blocks,
  });

  factory ConfigSection.fromJson(dynamic j) {
    final m = j is Map ? j : const <String, dynamic>{};
    final bl = m['blocks'];
    final blocks = <InfoBlock>[];
    if (bl is List) {
      for (final b in bl) {
        try {
          blocks.add(InfoBlock.fromJson(b));
        } catch (_) {}
      }
    }
    return ConfigSection(
      title: (m['title'] ?? '').toString(),
      lede: (m['lede'] ?? '').toString(),
      blocks: blocks,
    );
  }
}

class Faq {
  final String q;
  final String a;

  const Faq(this.q, this.a);

  factory Faq.fromJson(dynamic j) {
    final m = j is Map ? j : const <String, dynamic>{};
    return Faq((m['q'] ?? '').toString(), (m['a'] ?? '').toString());
  }
}

class Maintenance {
  final bool enabled;
  final String message;

  const Maintenance({required this.enabled, required this.message});
}

/// Panelden açılıp kapanabilen özellik anahtarları.
class FeatureFlags {
  final bool addMosque;
  final bool reviews;
  final bool photos;
  final bool favorites;
  final bool contact;

  const FeatureFlags({
    this.addMosque = true,
    this.reviews = true,
    this.photos = true,
    this.favorites = true,
    this.contact = true,
  });

  static bool _on(dynamic v, {bool def = true}) => v is bool ? v : def;

  factory FeatureFlags.fromJson(dynamic j) {
    final m = j is Map ? j : const <String, dynamic>{};
    return FeatureFlags(
      addMosque: _on(m['addMosque']),
      reviews: _on(m['reviews']),
      photos: _on(m['photos']),
      favorites: _on(m['favorites']),
      contact: _on(m['contact']),
    );
  }

  Map<String, dynamic> toJson() => {
    'addMosque': addMosque,
    'reviews': reviews,
    'photos': photos,
    'favorites': favorites,
    'contact': contact,
  };
}

/// Ayarlar sekmesinde listelenen panelden yönetilen bağlantı.
class AppLink {
  final String label;
  final String url;

  const AppLink({required this.label, required this.url});

  factory AppLink.fromJson(dynamic j) {
    final m = j is Map ? j : const <String, dynamic>{};
    return AppLink(
      label: (m['label'] ?? '').toString(),
      url: (m['url'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'url': url};
}

/// Namaz vakti kaynağı: 'auto' | 'imsakiyem' | 'emushaf'
const String kDefaultPrayerSource = 'auto';

class Announcement {
  final bool enabled;
  final String text;

  const Announcement({required this.enabled, required this.text});
}

/// Panel Güncellemeler bölümünden gelen sürüm bilgisi.
class UpdateSpec {
  final String latestVersion;
  final String minVersion;
  final String url;
  final String apkUrl;
  final String note;
  final String apkSha;
  final int apkSize;

  const UpdateSpec({
    this.latestVersion = '',
    this.minVersion = '',
    this.url = '',
    this.apkUrl = '',
    this.note = '',
    this.apkSha = '',
    this.apkSize = 0,
  });

  factory UpdateSpec.fromJson(dynamic j) {
    final m = j is Map ? j : const <String, dynamic>{};
    return UpdateSpec(
      latestVersion: (m['latestVersion'] ?? '').toString(),
      minVersion: (m['minVersion'] ?? '').toString(),
      url: (m['url'] ?? '').toString(),
      apkUrl: (m['apkUrl'] ?? '').toString(),
      note: (m['note'] ?? '').toString(),
      apkSha: (m['apkSha'] ?? '').toString(),
      apkSize: (m['apkSize'] is int) ? m['apkSize'] : 0,
    );
  }

  bool get hasApk => apkUrl.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'latestVersion': latestVersion,
    'minVersion': minVersion,
    'url': url,
    'apkUrl': apkUrl,
    'note': note,
    'apkSha': apkSha,
    'apkSize': apkSize,
  };
}

class RemoteConfig {
  final Maintenance maintenance;
  final Announcement announcement;
  final List<Faq> faq;
  final ConfigSection about;
  final ConfigSection privacy;
  final ConfigSection terms;
  final String appName;
  final String heroVakitTitle;
  final String contactLede;
  final FeatureFlags features;
  final String prayerSource;
  final List<AppLink> links;
  final String minVersion;
  final UpdateSpec update;
  final int updatedAt;

  const RemoteConfig({
    required this.maintenance,
    required this.announcement,
    required this.faq,
    required this.about,
    required this.privacy,
    required this.terms,
    this.appName = 'Nerede K\u0131laca\u011F\u0131m?',
    this.heroVakitTitle = 'Bug\u00FCn\u00FCn vakitleri',
    this.contactLede = '',
    this.features = const FeatureFlags(),
    this.prayerSource = kDefaultPrayerSource,
    this.links = const [],
    this.minVersion = '',
    this.update = const UpdateSpec(),
    this.updatedAt = 0,
  });

  bool get inMaintenance => maintenance.enabled;

  factory RemoteConfig.fromJson(Map<String, dynamic> j) {
    final m = j['maintenance'];
    final a = j['announcement'];
    final fq = j['faq'];
    final faq = <Faq>[];
    if (fq is List) {
      for (final f in fq) {
        try {
          faq.add(Faq.fromJson(f));
        } catch (_) {}
      }
    }
    final links = <AppLink>[];
    final lj = j['links'];
    if (lj is List) {
      for (final l in lj) {
        final link = AppLink.fromJson(l);
        if (link.url.isNotEmpty) links.add(link);
      }
    }
    RemoteConfig base = defaultRemoteConfig();
    return RemoteConfig(
      maintenance: Maintenance(
        enabled: (m is Map && m['enabled'] == true),
        message: (m is Map && m['message'] != null)
            ? m['message'].toString()
            : base.maintenance.message,
      ),
      announcement: Announcement(
        enabled: (a is Map && a['enabled'] == true),
        text: (a is Map && a['text'] != null) ? a['text'].toString() : '',
      ),
      faq: faq,
      about: j['about'] != null
          ? ConfigSection.fromJson(j['about'])
          : base.about,
      privacy: j['privacy'] != null
          ? ConfigSection.fromJson(j['privacy'])
          : base.privacy,
      terms: j['terms'] != null
          ? ConfigSection.fromJson(j['terms'])
          : base.terms,
      appName:
          (j['branding'] is Map &&
              j['branding']['appName'] != null &&
              j['branding']['appName'].toString().trim().isNotEmpty)
          ? j['branding']['appName'].toString()
          : base.appName,
      heroVakitTitle:
          (j['ui'] is Map &&
              j['ui']['heroVakitTitle'] != null &&
              j['ui']['heroVakitTitle'].toString().trim().isNotEmpty)
          ? j['ui']['heroVakitTitle'].toString()
          : base.heroVakitTitle,
      contactLede: (j['ui'] is Map && j['ui']['contactLede'] != null)
          ? j['ui']['contactLede'].toString()
          : base.contactLede,
      features: FeatureFlags.fromJson(j['features']),
      prayerSource:
          (j['prayerSource'] is String &&
              ['auto', 'imsakiyem', 'emushaf'].contains(j['prayerSource']))
          ? j['prayerSource'] as String
          : base.prayerSource,
      links: links,
      minVersion: (j['update'] is Map &&
              j['update']['minVersion'] != null &&
              j['update']['minVersion'].toString().trim().isNotEmpty)
          ? j['update']['minVersion'].toString()
          : (j['minVersion'] ?? '').toString(),
      update: UpdateSpec.fromJson(j['update']),
      updatedAt: j['updatedAt'] is int ? j['updatedAt'] : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'maintenance': {
      'enabled': maintenance.enabled,
      'message': maintenance.message,
    },
    'announcement': {
      'enabled': announcement.enabled,
      'text': announcement.text,
    },
    'faq': faq.map((f) => {'q': f.q, 'a': f.a}).toList(),
    'about': sectionToJson(about),
    'privacy': sectionToJson(privacy),
    'terms': sectionToJson(terms),
    'branding': {'appName': appName},
    'ui': {'heroVakitTitle': heroVakitTitle, 'contactLede': contactLede},
    'features': features.toJson(),
    'prayerSource': prayerSource,
    'links': links.map((l) => l.toJson()).toList(),
    'minVersion': minVersion,
    'update': update.toJson(),
    'updatedAt': updatedAt,
  };

  static Map<String, dynamic> sectionToJson(ConfigSection s) => {
    'title': s.title,
    'lede': s.lede,
    'blocks': s.blocks.map((b) => {'title': b.title, 'text': b.text}).toList(),
  };
}

RemoteConfig defaultRemoteConfig() => RemoteConfig(
  maintenance: const Maintenance(
    enabled: false,
    message:
        'Bak\u0131m \u00E7al\u0131\u015Fmas\u0131 nedeniyle uygulama ge\u00E7ici olarak hizmet d\u0131\u015F\u0131d\u0131r. L\u00FCtfen k\u0131sa s\u00FCre sonra tekrar deneyin.',
  ),
  announcement: const Announcement(enabled: false, text: ''),
  contactLede:
      'Mescit ekleme, puanlama, hata bildirimi veya i\u015F birli\u011Fi i\u00E7in bize yaz\u0131n. Genellikle 1 i\u015F g\u00FCn\u00FC i\u00E7inde d\u00F6n\u00FC\u015F yap\u0131yoruz.',
  faq: const [
    Faq(
      'Nerede K\u0131laca\u011F\u0131m? nedir?',
      'Nerede K\u0131laca\u011F\u0131m?, bulundu\u011Funuz konuma en yak\u0131n cami ve mescitleri g\u00F6steren, namaz vakitlerini sunan, mescitleri puanlaman\u0131z\u0131 ve favorilere eklemenizi sa\u011Flayan bir uygulamad\u0131r.',
    ),
    Faq(
      'Namaz vakitleri nas\u0131l belirleniyor?',
      'Vakitler \u00FClke genelinde kullan\u0131lan ezan vakitleri veri kaynaklar\u0131ndan (imsakiyem ve em\u00FC\u015Faf) \u00E7ekilir ve konumunuza en yak\u0131n il\u00E7enin vakitleri g\u00F6sterilir.',
    ),
    Faq(
      'Konumum nas\u0131l kullan\u0131l\u0131yor?',
      'Konumunuz yaln\u0131zca yak\u0131n\u0131n\u0131zdaki mescitleri listelemek ve namaz vakti il\u00E7enizi bulmak i\u00E7in kullan\u0131l\u0131r. Konum bilgisi sunucular\u0131m\u0131zda saklanmaz; yaln\u0131zca cihaz\u0131n\u0131zda i\u015Flenir.',
    ),
    Faq(
      'Mescit nas\u0131l ekleyebilirim veya puanlayabilirim?',
      'Alt men\u00FCdeki \u201CMescit Ekle\u201D butonu ile yeni mescit ekleyebilir; bir mescide yakla\u015Ft\u0131\u011F\u0131n\u0131zda \u00E7\u0131kan puanlama ekran\u0131n\u0131 kullanarak ger\u00E7ek yerinde iken puanlayabilirsiniz.',
    ),
    Faq(
      'Hesap olu\u015Fturmak zorunlu mu?',
      'Evet, puanlamalar\u0131n ve favorilerin hesab\u0131n\u0131za ba\u011Flanmas\u0131 i\u00E7in giri\u015F yapman\u0131z gerekir. Kay\u0131t e-posta ve \u015Fifre ile yap\u0131l\u0131r; \u015Fifreniz cihaz\u0131n\u0131zda d\u00FCz metin olarak de\u011Fil, tuzlanm\u0131\u015F \u00F6zet (hash) olarak saklan\u0131r.',
    ),
  ],
  about: const ConfigSection(
    title: 'Hakk\u0131m\u0131zda',
    lede: 'Nerede K\u0131laca\u011F\u0131m? bir topluluk giri\u015Fimidir.',
    blocks: [
      InfoBlock(
        'Amac\u0131m\u0131z',
        '\u015Eehirde, yolda veya tatilde iken en yak\u0131n cami ve mescidi kolayca bulabilmek; namaz vakitlerini tek ekrandan \u00F6\u011Frenebilmek ve mescitlerin temizlik, eri\u015Filebilirlik ve abdest imk\u00E2n\u0131 gibi \u00F6zelliklerini kullan\u0131c\u0131 puanlar\u0131yla payla\u015Fabilmek.',
      ),
      InfoBlock(
        'Nas\u0131l \u00E7al\u0131\u015F\u0131yor?',
        'Mescitler OpenStreetMap gibi a\u00E7\u0131k veri kaynaklar\u0131ndan \u00E7ekilir, namaz vakitleri kamuya a\u00E7\u0131k ezan vakitleri servislerinden al\u0131n\u0131r. T\u00FCm uygulama tek bir ekrandan \u00E7al\u0131\u015F\u0131r ve verileriniz cihaz\u0131n\u0131zda kal\u0131r.',
      ),
      InfoBlock(
        'Topluluk & Ekip',
        'Nerede K\u0131laca\u011F\u0131m? g\u00F6n\u00FCl\u00FClerden olu\u015Fan k\u00FC\u00E7\u00FCk bir ekiple geli\u015Ftirilir. Yeni fikirleriniz, geri bildirimleriniz ve hata bildirimleriniz bizim i\u00E7in \u00E7ok de\u011Ferli. Bize ileti\u015Fim sayfas\u0131ndan ula\u015Fabilirsiniz.',
      ),
    ],
  ),
  privacy: const ConfigSection(
    title: 'Gizlilik Politikas\u0131',
    lede:
        'Verilerinizin nas\u0131l i\u015Flendi\u011Fini \u015Feffaf bi\u00E7imde a\u00E7\u0131kl\u0131yoruz.',
    blocks: [
      InfoBlock(
        '1. Hangi veriler saklan\u0131yor?',
        'Hesap bilgileriniz (ad, e-posta, \u015Fifre), mescit puanlar\u0131n\u0131z, favorileriniz ve ekledi\u011Finiz kay\u0131tlar yaln\u0131zca cihaz\u0131n\u0131z\u0131n yerel depolama alan\u0131nda saklan\u0131r. Sunucular\u0131m\u0131zda hesap verisi tutulmaz.',
      ),
      InfoBlock(
        '2. Konum bilgisi',
        'Konumunuz yaln\u0131zca yak\u0131n\u0131n\u0131zdaki mescitleri ve namaz vakitlerini bulmak i\u00E7in kullan\u0131l\u0131r; saklanmaz ve \u00FC\u00E7\u00FCnc\u00FC ki\u015Filere aktar\u0131lmaz. \u0130zin vermezseniz IP tabanl\u0131 yakla\u015F\u0131k konum ile devam edebilirsiniz.',
      ),
      InfoBlock(
        '3. \u00DC\u00E7\u00FCnc\u00FC taraf hizmetleri',
        'Harita (OpenStreetMap), mescit verisi (Overpass API), rota (OSRM), namaz vakitleri (imsakiyem / em\u00FC\u015Faf) ve konum tahmini hizmetlerinden yararlan\u0131l\u0131r. Bu hizmetler kendi gizlilik politikalar\u0131na tabidir.',
      ),
      InfoBlock(
        '4. \u00C7erezler ve izleme',
        'Uygulama \u00FC\u00E7\u00FCnc\u00FC taraf reklam ya da izleme \u00E7erezi kullanmaz. Verilerinizi \u00FC\u00E7\u00FCnc\u00FC ki\u015Filere satmay\u0131z.',
      ),
      InfoBlock(
        '5. Haklar\u0131n\u0131z',
        'Verilerinizi istedi\u011Finiz zaman \u201CHesab\u0131m\u0131 Sil\u201D butonuyla veya uygulama verilerini temizleyerek kal\u0131c\u0131 olarak silebilirsiniz.',
      ),
      InfoBlock(
        '6. Kullan\u0131m \u015Eartlar\u0131',
        'Uygulaman\u0131n kullan\u0131m ko\u015Fullar\u0131 ayr\u0131 bir sayfada toplanm\u0131\u015Ft\u0131r.',
      ),
    ],
  ),
  terms: const ConfigSection(
    title: 'Kullan\u0131m \u015Eartlar\u0131',
    lede:
        'Nerede K\u0131laca\u011F\u0131m? hizmetinin kullan\u0131m ko\u015Fullar\u0131. Uygulamay\u0131 kullanarak bu \u015Fartlar\u0131 kabul etmi\u015F say\u0131l\u0131rs\u0131n\u0131z.',
    blocks: [
      InfoBlock(
        '1. Hizmet kapsam\u0131',
        'Nerede K\u0131laca\u011F\u0131m?, \u00E7evrenizdeki cami ve mescitleri g\u00F6steren, namaz vakitlerini sunan, mescit puanlama ve favorilere ekleme imk\u00E2n\u0131 veren bir uygulamad\u0131r. Hizmet; harita (OpenStreetMap), a\u00E7\u0131k mescit verileri (Overpass API) ve namaz vakti sa\u011Flay\u0131c\u0131lar\u0131 \u00FCzerine kuruludur.',
      ),
      InfoBlock(
        '2. Veri kayna\u011F\u0131',
        'Mescit bilgileri a\u00E7\u0131k kaynaklardan (OpenStreetMap ve di\u011Ferleri) gelir; bu bilgiler hatal\u0131 veya g\u00FCncel olmayabilir. G\u00F6r\u00FCn\u00FCrl\u00FCk i\u00E7in eklenen \u00F6rnek kay\u0131tlar \u201C\u00F6rnek\u201D olarak i\u015Faretlenir ve kald\u0131r\u0131labilir. Haritay\u0131 kullan\u0131rken do\u011Frulu\u011Fu kendi sorumlulu\u011Funuzda teyit edin.',
      ),
      InfoBlock(
        '3. Hesap ve i\u00E7erik',
        'Hesap verileriniz yaln\u0131zca cihaz\u0131n\u0131z\u0131n yerel depolama alan\u0131nda tutulur. Mescit puanlama ve ekleme \u00F6zellikleri yaln\u0131zca do\u011Fru ve iyi niyetli kullan\u0131m i\u00E7indir; yanl\u0131\u015F bilgi, sahte puanlama ve k\u00F6t\u00FCye kullan\u0131m yasakt\u0131r ve hesab\u0131n kapat\u0131lmas\u0131yla sonu\u00E7lanabilir.',
      ),
      InfoBlock(
        '4. Sorumluluk',
        'Uygulama \u201Coldu\u011Fu gibi\u201D sunulur. Namaz vakti, mescit konumu, adres veya y\u00F6n bulma bilgilerindeki hatalardan, eksikliklerden ya da kullan\u0131mdan kaynaklanan zararlardan sorumluluk kabul edilmez.',
      ),
      InfoBlock(
        '5. Fikri m\u00FClkiyet',
        'Uygulama ad\u0131, aray\u00FCz ve marka \u00F6\u011Feleri Nerede K\u0131laca\u011F\u0131m?\u2019e aittir. Harita ve mescit verileri a\u00E7\u0131k lisanslarla korunur; kendi lisans ko\u015Fullar\u0131na tabidir.',
      ),
      InfoBlock(
        '6. De\u011Fi\u015Fiklikler',
        'Bu \u015Fartlar de\u011Fi\u015Ftirildi\u011Finde bu sayfa g\u00FCncellenir; kullan\u0131m\u0131 s\u00FCrd\u00FCrd\u00FC\u011F\u00FCn\u00FCzde g\u00FCncel \u015Fartlar\u0131 kabul etmi\u015F say\u0131l\u0131rs\u0131n\u0131z. \u015Eartlar\u0131n bir b\u00F6l\u00FCm\u00FCn\u00FCn ge\u00E7ersiz say\u0131lmas\u0131 di\u011Fer b\u00F6l\u00FCmleri etkilemez.',
      ),
      InfoBlock(
        '7. \u0130leti\u015Fim',
        '\u015Eartlarla ilgili sorular\u0131n\u0131z i\u00E7in ileti\u015Fim sayfas\u0131n\u0131 kullanabilirsiniz.',
      ),
    ],
  ),
);

String remoteConfigToJson(RemoteConfig c) => jsonEncode(c.toJson());

RemoteConfig? remoteConfigFromJson(String raw) {
  try {
    final d = jsonDecode(raw);
    if (d is Map<String, dynamic>) return RemoteConfig.fromJson(d);
  } catch (_) {}
  return null;
}

/// Panelden /api/config çeker; başarısızsa null (offline-first: önbellek kullanılır).
Future<RemoteConfig?> fetchRemoteConfig() async {
  for (final base in kPanelBases) {
    try {
      final r = await http
          .get(Uri.parse('$base/api/config'))
          .timeout(kPanelTimeout);
      if (r.statusCode != 200) return null;
      final d = jsonDecode(r.body);
      if (d is Map<String, dynamic>) return RemoteConfig.fromJson(d);
      return null;
    } catch (_) {
      debugPrint('NKDBG: panel $base/api/config -> unreachable');
    }
  }
  return null;
}

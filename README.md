# Nerede Kılacağım?

Çevrenizdeki cami ve mescitleri bulan, Diyanet namaz vakitlerini gösteren, mescit puanlama ve favori özellikleri sunan, topluluk gönüllüleri tarafından geliştirilen açık kaynak mobil uygulamadır.

## Özellikler

- Harita (OpenStreetMap) üzerinden cami ve mescitler
- Overpass API ile açık mescit verileri
- Diyanet namaz vakitleri
- Mescit ekleme önerisi (control panel onayı ile)
- Mescit puanlama ve favoriler
- Sıkça Sorulan Sorular / Hakkımızda / Gizlilik / Şartlar (panelden yönetilebilir)

## Mimari

- **Uygulama:** Flutter (Android + iOS)
- **Panel:** Node.js + JSON dosya depolama, sıfır bağımlılık (`server/`)
- **Veri:** Harita OSM, mescitler Overpass, namaz vakitleri Diyanet

## Geliştirme

```sh
flutter pub get
flutter run
```

Panel:

```sh
node server/server.js
```

Varsayılan panel adresi `http://127.0.0.1:8787`; yönetici şifresi `002011` (ortam değişkeni `ADMIN_PASS` ile değiştirilebilir).

Uygulamanın panele ulaşacağı adres derleme zamanında verilir:

```sh
flutter build apk --release --dart-define=PANEL_BASE=http://<BILGISAYAR_IP>:8787
```

Boş bırakılırsa panel özellikleri kapalı kalır; kayıtlar yine de yerel olarak tutulur (offline-first).
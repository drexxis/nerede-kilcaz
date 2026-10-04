import 'package:flutter/material.dart';

import 'app_state.dart';
import 'location.dart';
import 'prayer.dart';
import 'storage.dart';

/// Tekil servis tutucusu (main tarafından kurulur).
class Services {
  Services._();
  static final Services instance = Services._();

  late Storage storage;
  late AppState app;
  late PrayerService prayer;
  late LocationService location;

  /// Global gezinme (root navigator context).
  final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();

  Future<void> load() async {
    storage = Storage();
    await storage.init();
    app = AppState(storage);
    await app.loadAppVersion();
    prayer = PrayerService(storage);
    location = LocationService.instance;
    app.load();

    // Vakit + yakın mescitler birlikte (loadAround bağlantısı).
    location.userLat = prayer.userLat ?? 37.87;
    location.userLng = prayer.userLng ?? 32.49;
    location.onLoadAround = (lat, lng) async {
      prayer.userLat = lat;
      prayer.userLng = lng;
      location.reassign(lat, lng);
      await prayer.fetch();
    };
  }
}

Services get services => Services.instance;

/// Bağlamdan navigasyon kolaylığı.
void navPush(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

void navReplaceAll(BuildContext context, Widget page) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => page),
    (route) => false,
  );
}

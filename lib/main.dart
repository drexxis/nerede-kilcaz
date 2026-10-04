import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'auth_screen.dart';
import 'screens/arrival_modal.dart';
import 'screens/home_screen.dart';
import 'screens/info_pages.dart';
import 'screens/list_screen.dart';
import 'screens/map_screen.dart';
import 'screens/settings_screen.dart';
import 'server_api.dart';
import 'services.dart';
import 'theme.dart';
import 'update_service.dart';
import 'remote_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await services.load();
  unawaited(services.app.refreshConfig());
  runApp(const NkApp());
}

class NkApp extends StatelessWidget {
  const NkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.app,
      builder: (_, _) {
        final m = services.app.themeMode;
        return MaterialApp(
          title: services.app.remote.appName,
          debugShowCheckedModeBanner: false,
          theme: buildLight(),
          darkTheme: buildDark(),
          themeMode: m,
          navigatorKey: services.nav,
          home: const _Root(),
        );
      },
    );
  }
}

/// Giriş kapısı: bakım modu, misafir (AuthScreen) veya 4 sekmeli gövde.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.app,
      builder: (_, _) {
        if (services.app.updateRequired) return const UpdateScreen();
        if (services.app.inMaintenance) return const MaintenanceScreen();
        if (!services.app.isLoggedIn) return const AuthScreen();
        return const _Shell();
      },
    );
  }
}

/// Bakım modu tam ekranı.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.app,
      builder: (_, _) {
        final cfg = services.app.remote;
        return Scaffold(
          backgroundColor: ctxBodyBg(context),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: ctxGreenLight(context),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.construction,
                        size: 42,
                        color: T.green600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Bak\u0131mday\u0131z',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ctxInk(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      cfg.maintenance.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: ctxInkSoft(context),
                      ),
                    ),
                    const SizedBox(height: 26),
                    const SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _tab = 1; // Ezan Vakti açılışta
  Timer? _tick;
  Timer? _arrivalTick;
  Timer? _dailyCheck;
  Timer? _configTick;
  Timer? _flushTick;
  bool _updatePromptOpen = false;

  @override
  void initState() {
    super.initState();
    _boot();
    // Uzak yapılandırma yüklendiğinde/bakım değişince yumuşak güncelleme kontrolü.
    services.app.addListener(_maybeUpdatePrompt);
  }

  void _maybeUpdatePrompt() {
    if (_updatePromptOpen || !services.app.softUpdatePromptDue) return;
    _updatePromptOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSoftUpdateDialog(context).whenComplete(() => _updatePromptOpen = false);
    });
  }

  void _boot() {
    services.prayer.start();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => services.prayer.compute(false),
    );
    _arrivalTick = Timer.periodic(const Duration(seconds: 3), (_) {
      services.location.checkArrival();
    });
    // Her gün 15:00'te vakitler yeniden çekilir (K114 kararı).
    _dailyCheck = Timer.periodic(const Duration(minutes: 1), (_) {
      final n = DateTime.now();
      if (n.hour == 15 && n.minute == 0) services.prayer.refresh();
    });
    // Uzak yapılandırma her dakika tazelenir (bakım/duyuru/SSS panelden değişir).
    _configTick = Timer.periodic(const Duration(seconds: 60), (_) {
      services.app.refreshConfig();
      _panelSync();
    });
    // Gönderilemeyen mescit istekleri 20 sn'de bir yeniden denenir (hızlı ulaşır).
    _flushTick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (services.app.pending.any((p) => p.status == 'beklemede')) {
        _panelSync();
      }
    });
    // İlk senkron: onaylı mescitler + gönderilemeyen kayıtlar.
    _panelSync();
    // Konum başlat; ne yapılırsa yapılsın vakitler de tetiklenir.
    if (services.location.hasLocation) {
      services.prayer.fetch();
    } else {
      _startLocation();
    }
    // Gizlilik onayı yoksa ilk açılış modalı.
    if (!services.app.hasConsent) {
      WidgetsBinding.instance.addPostFrameCallback((_) => showConsent(context));
    }
  }

  /// Panelden onaylı mescitleri çeker, gönderilemeyen kayıtları yeniden dener.
  Future<void> _panelSync() async {
    final approved = await fetchApprovedMosques();
    services.location.setApproved(approved);
    await services.app.flushPending();
  }

  Future<void> _startLocation() async {
    try {
      await services.location.start();
    } catch (_) {
      services.location.loadAround(
        services.location.userLat,
        services.location.userLng,
      );
    }
  }

  @override
  void dispose() {
    services.app.removeListener(_maybeUpdatePrompt);
    _tick?.cancel();
    _arrivalTick?.cancel();
    _dailyCheck?.cancel();
    _configTick?.cancel();
    _flushTick?.cancel();
    services.prayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = services.location;
    return Scaffold(
      backgroundColor: ctxBodyBg(context),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: services.app,
            builder: (_, _) {
              if (!services.app.isLoggedIn) return const AuthScreen();
              return IndexedStack(
                index: _tab,
                children: [
                  MapScreen(onGoHome: (_) => setState(() => _tab = 1)),
                  const HomeScreen(),
                  const ListScreen(),
                  const SettingsScreen(),
                ],
              );
            },
          ),
          // Varış modalı: konum değişimlerinde 150m içinde mescit varışı.
          AnimatedBuilder(
            animation: Listenable.merge([loc, services.app]),
            builder: (_, _) {
              // Panelden puanlama kapalıysa varış akışı da kapalıdır.
              if (!services.app.remote.features.reviews) {
                return const SizedBox.shrink();
              }
              final m = loc.arrivedMosque;
              if (!loc.hasArrived || m == null) return const SizedBox.shrink();
              return ArrivalOverlay(mosque: m);
            },
          ),
        ],
      ),
      bottomNavigationBar: _bottomNav(context),
    );
  }

  Widget _bottomNav(BuildContext context) {
    return ListenableBuilder(
      listenable: services.app,
      builder: (_, _) {
        final pending = services.app.pending.length;
        return NavigationBar(
          height: 70,
          selectedIndex: _tab,
          backgroundColor: ctxPaper(context),
          indicatorColor: ctxGreenLight(context),
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Harita',
            ),
            const NavigationDestination(
              icon: Icon(Icons.access_time),
              selectedIcon: Icon(Icons.access_time_filled),
              label: 'Ezan Vakti',
            ),
            const NavigationDestination(
              icon: Icon(Icons.mosque_outlined),
              selectedIcon: Icon(Icons.mosque),
              label: 'Mescitler',
            ),
            NavigationDestination(
              icon: Badge.count(
                count: pending,
                isLabelVisible: pending > 0,
                child: const Icon(Icons.settings_outlined),
              ),
              selectedIcon: Badge.count(
                count: pending,
                isLabelVisible: pending > 0,
                child: const Icon(Icons.settings),
              ),
              label: 'Ayarlar',
            ),
          ],
        );
      },
    );
  }
}

/// Panelden minVersion belirtilip cihaz sürümü düşükse tam ekran güncelleme kapısı.
class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = services.app.remote;
    final upd = cfg.update;
    final storeUrl =
        upd.url.trim().isNotEmpty ? upd.url.trim() : _firstLinkOr(cfg, '');
    final canInstallApk = Platform.isAndroid && upd.hasApk;
    return ListenableBuilder(
      listenable: services.app,
      builder: (context, _) => Scaffold(
        backgroundColor: ctxBodyBg(context),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: ctxGreenLight(context),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.system_update_alt,
                      size: 42,
                      color: T.green600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Yeni S\u00FCr\u00FCm Gerekli',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: ctxInk(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bu s\u00FCr\u00FCm art\u0131k desteklenmiyor. Devam etmek i\u00E7in l\u00FCtfen uygulamay\u0131 g\u00FCncelleyin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: ctxInkSoft(context),
                    ),
                  ),
                  if (upd.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      upd.note,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: ctxInkSoft(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  if (canInstallApk) ...[
                    FilledButton.icon(
                      onPressed: () =>
                          downloadAndInstallApk(context, upd.apkUrl),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('APK ile G\u00FCncelle'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (storeUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => launchUpdateUrl(storeUrl),
                      icon: const Icon(Icons.storefront, size: 18),
                      label: Text(
                        canInstallApk
                            ? 'Ma\u011Fazadan G\u00FCncelle'
                            : (cfg.links.first.label.isEmpty
                                ? 'G\u00FCncelle'
                                : cfg.links.first.label),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _firstLinkOr(RemoteConfig cfg, String fallback) {
  for (final l in cfg.links) {
    if (l.url.trim().isNotEmpty) return l.url.trim();
  }
  return fallback;
}

/// Gizlilik onay modalı: kabul edilirse 1 yazılır, edilmezse açılışta yeniden gösterilir.
Future<void> showConsent(BuildContext context) async {
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.verified_user_outlined, size: 40, color: T.green600),
            const SizedBox(height: 12),
            Text(
              'Ho\u015F geldiniz',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ctxInk(c),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nerede K\u0131laca\u011F\u0131m?, en yak\u0131n cami ve mescitleri bulman\u0131za yard\u0131mc\u0131 olur. Devam etmeden \u00F6nce gizlilik ve kullan\u0131m \u015Fartlar\u0131m\u0131z\u0131 incelemenizi rica ederiz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ctxInkSoft(c), height: 1.5),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _openInfo(c, const PrivacyPage()),
                  child: const Text('Gizlilik Politikas\u0131'),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => _openInfo(c, const TermsPage()),
                  child: const Text('Kullan\u0131m \u015Eartlar\u0131'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Kabul ederek konum verilerinin yaln\u0131zca yak\u0131ndaki mescitleri ve namaz vakitlerini bulmak i\u00E7in kullan\u0131laca\u011F\u0131n\u0131, hesap verilerinin cihaz\u0131n\u0131zda saklanaca\u011F\u0131n\u0131 ve mescit bilgilerinin a\u00E7\u0131k kaynaklardan geldi\u011Fini onaylam\u0131\u015F olursunuz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: ctxInkSoft(c),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: () {
                  services.app.giveConsent();
                  Navigator.of(c).pop(true);
                },
                child: const Text('Kabul Ediyorum'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Onay vermeden uygulamay\u0131 kullanamazs\u0131n\u0131z. \u015Eartlar\u0131 kabul etmeden devam edilemez.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: ctxInkSoft(c),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    ),
  );
}

/// Onay modalından bilgi sayfası aç (modal açık kalır, üstüne itilir).
void _openInfo(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

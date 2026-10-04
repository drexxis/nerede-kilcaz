import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'remote_config.dart';
import 'server_api.dart';
import 'services.dart';
import 'theme.dart';

/// Android kurulum kanalı (MainActivity.kt içinde uygulanır).
const MethodChannel _updaterChannel = MethodChannel('neredekilacagim/updater');

const String kApkFileName = 'neredekilacagim-update.apk';

/// Mağaza bağlantısını harici tarayıcıda açar; iOS'ta App Store, Android'de Play.
Future<bool> launchUpdateUrl(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// APK'yı uygulama önbelleğine indirir ve dosya yolunu döner.
/// `url` tam bir http(s) adresi ya da panele göreli yol olabilir.
Future<String> downloadApk(String url) async {
  final tmp = File('${Directory.systemTemp.path}/$kApkFileName.part');
  final target = File('${Directory.systemTemp.path}/$kApkFileName');
  for (final base in kPanelBases) {
    final u = url.startsWith('http') ? url : '$base$url';
    try {
      final r = await http
          .get(Uri.parse(u))
          .timeout(const Duration(seconds: 90));
      if (r.statusCode != 200) continue;
      await tmp.writeAsBytes(r.bodyBytes, flush: true);
      if (await target.exists()) await target.delete();
      await tmp.rename(target.path);
      return target.path;
    } catch (e) {
      debugPrint('NKDBG: APK indirilemedi $u -> $e');
    }
  }
  throw StateError('apk_download_failed');
}

/// İndirilen APK'yı Android paket kurucusuna iletir (kullanıcı onayı gerekli).
Future<bool> installApk(String path) async {
  if (!Platform.isAndroid) return false;
  try {
    final ok = await _updaterChannel
        .invokeMethod<bool>('installApk', {'path': path});
    return ok ?? false;
  } catch (e) {
    debugPrint('NKDBG: kurulum kanalı hatası -> $e');
    return false;
  }
}

/// APK'yı panelden indirip paket kurucusuna iletir; ilerlemeyi bir pencerede gösterir.
Future<void> downloadAndInstallApk(BuildContext context, String apkUrl) async {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateBusyDialog(apkUrl: apkUrl),
  );
  if (ok == false && context.mounted) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Kurulum ba\u015Flat\u0131lamad\u0131. \u201CBilinmeyen kaynaklar\u201D iznini kontrol edin ya da ma\u011Fazadan kurun.',
        ),
      ),
    );
  }
}

/// İndirme + kurulum akışını kendi içinde yöneten ilerleme penceresi.
class _UpdateBusyDialog extends StatefulWidget {
  final String apkUrl;
  const _UpdateBusyDialog({required this.apkUrl});

  @override
  State<_UpdateBusyDialog> createState() => _UpdateBusyDialogState();
}

class _UpdateBusyDialogState extends State<_UpdateBusyDialog> {
  String _label = 'APK indiriliyor\u2026';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final path = await downloadApk(widget.apkUrl);
      if (!mounted) return;
      setState(() => _label = 'Kurulum ba\u015Flat\u0131l\u0131yor\u2026');
      final ok = await installApk(path);
      if (mounted) Navigator.of(context).pop(ok);
    } catch (_) {
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 18),
            Flexible(child: Text(_label)),
          ],
        ),
      ),
    );
  }
}

/// Mağaza öncelikli, APK fallback'li ilk kullanılabilir bağlantı.
String firstStoreLink(RemoteConfig cfg, String fallback) {
  if (cfg.update.url.trim().isNotEmpty) return cfg.update.url.trim();
  for (final l in cfg.links) {
    if (l.url.trim().isNotEmpty) return l.url.trim();
  }
  return fallback;
}

/// Yumuşak güncelleme penceresi: kapatılabilir, mağaza ya da APK yolu sunar.
Future<void> showSoftUpdateDialog(BuildContext context) async {
  final app = services.app;
  final upd = app.remote.update;
  final storeUrl = upd.url.trim().isNotEmpty ? upd.url.trim() : '';
  final canInstallApk = Platform.isAndroid && upd.hasApk;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.update, color: T.green600),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Yeni S\u00FCr\u00FCm '
                '${upd.latestVersion.trim()}'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kurulu s\u00FCr\u00FCm: ${app.appVersion}. '
              'En yeni s\u00FCr\u00FCme ge\u00E7mek i\u00E7in a\u015Fa\u011F\u0131daki ad\u0131mlardan birini se\u00E7in.',
              style: TextStyle(fontSize: 13, color: ctxInkSoft(c), height: 1.5),
            ),
            if (upd.note.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                upd.note,
                style: TextStyle(
                  fontSize: 12.5,
                  color: ctxInkSoft(c),
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            app.setSkipUpdate();
            Navigator.of(c).pop();
          },
          child: const Text('\u015Eimdi De\u011Fil'),
        ),
        if (storeUrl.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              Navigator.of(c).pop();
              launchUpdateUrl(storeUrl);
            },
            icon: const Icon(Icons.storefront, size: 18),
            label: const Text('Ma\u011Faza'),
          ),
        if (canInstallApk)
          FilledButton.icon(
            onPressed: () {
              Navigator.of(c).pop();
              downloadAndInstallApk(context, upd.apkUrl);
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Hemen Kur'),
          ),
      ],
    ),
  );
}
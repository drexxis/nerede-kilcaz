import 'package:flutter/material.dart';

import '../auth_screen.dart';
import '../links.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'arrival_modal.dart';
import 'detail_screen.dart';

/// Mescite dokununca açılan alt karta (openSheet karşılığı).
///  - Favori durumu
///  - Detaya git
///  - Yol tarifi al (rota + modalda göster)
///  - Google Haritalar'da aç
Future<void> showPlaceSheet(BuildContext context, Mosque m) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark ? T.darkPaper : T.paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _PlaceSheet(m: m),
  );
}

class _PlaceSheet extends StatefulWidget {
  final Mosque m;
  const _PlaceSheet({required this.m});
  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  Mosque get m => widget.m;

  @override
  Widget build(BuildContext context) {
    final app = services.app;
    final agg = app.aggOf(m.key);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ctxLine(context), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(m.name,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ctxInk(context))),
                ),
              ],
            ),
            const SizedBox(height: 6),
            RatingPill(agg: agg),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: m.tags.map((t) => Tag(t)).toList()),
            const SizedBox(height: 16),
            _rowBtn(context, Icons.star_border, app.isFav(m.key) ? 'Favorilerden \u00C7\u0131kar' : 'Favorilere Ekle', () {
              app.toggleFav(m.key, m.name, m.lat, m.lon);
              toast(context, app.isFav(m.key) ? 'Favorilere eklendi' : 'Favorilerden \u00E7\u0131kar\u0131ld\u0131');
              setState(() {});
            }),
            _rowBtn(context, Icons.info_outline, 'Detaylar\u0131 G\u00F6r', () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(mosque: m)));
            }),
            _rowBtn(context, Icons.directions, 'Yol Tarifi Al', () async {
              await services.location.routeTo(m);
              if (context.mounted) {
                toast(context, 'Rota hesapland\u0131');
                Navigator.of(context).pop(true);
              }
            }),
            _rowBtn(context, Icons.map, 'Google Haritalar\'da A\u00E7', () => openGmaps(m.lat, m.lon)),
            const SizedBox(height: 6),
            Text('Puanla', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ctxInk(context))),
            const SizedBox(height: 4),
            if (!app.isLoggedIn)
              _rowBtn(context, Icons.login, 'Puanlamak i\u00E7in giri\u015F yap\u0131n', () {
                Navigator.of(context).pop();
                _goAuth(context, app);
              })
            else
              _rowBtn(context, Icons.star, 'Bu mescidi puanla', () {
                Navigator.of(context).pop();
                showArrivalModal(context, m);
              }),
          ],
        ),
      ),
    );
  }

  Widget _rowBtn(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 19, color: T.green600),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 14, color: ctxInk(context))),
            ],
          ),
        ),
      ),
    );
  }

  void _goAuth(BuildContext context, app) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AuthScreen(reason: AuthReason.mapRequest)))
        .then((ok) {
      if (ok == true) {
        // giriş başarılı; şu anki ekran harita listesi yeniden açılır.
      }
    });
  }
}

/// Web: puanlama giriş zorunlu (am modalı) → giriş ekranı.
Future<void> ensureAuth(BuildContext context, {AuthReason reason = AuthReason.mapRequest}) async {
  if (services.app.isLoggedIn) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthScreen(reason: reason)));
}

/// Haritada rota çizgisi için coord listesi (rx).
List<List<double>> activePolyline() => services.location.activeRoute ?? const [];
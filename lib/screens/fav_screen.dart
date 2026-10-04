import 'package:flutter/material.dart';

import '../auth_screen.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'detail_screen.dart';

class FavScreen extends StatelessWidget {
  const FavScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = services.app;
    final loc = services.location;
    // Route olarak açıldığında Material ancestral için Scaffold şart.
    return Scaffold(
      backgroundColor: ctxBodyBg(context),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([app, loc]),
          builder: (_, _) {
            final favs = app.favs;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Text(
                    'Favorilerin',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ctxInk(context),
                    ),
                  ),
                ),
                Expanded(
                  child: favs.isEmpty
                      ? const EmptyState(
                          text:
                              'Hen\u00FCz favori mescidin yok.\nHaritadan bir yer a\u00E7\u0131p "Favorilere Ekle" diyerek favorilere ekleyebilirsin.',
                          icon: Icons.favorite_border,
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          children: favs
                              .map((f) => _favCard(context, f))
                              .toList(),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _favCard(BuildContext context, FavRecord f) {
    final app = services.app;
    final loc = services.location;
    String d = '';
    if (loc.hasLocation) {
      d = distText(haversine(loc.userLat, loc.userLng, f.lat, f.lon));
    }
    final m = Mosque.fromFav(f.key, f.name, f.lat, f.lon);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => DetailScreen(mosque: m))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ctxGreenLight(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mosque, size: 22, color: T.green600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: ctxInk(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      d.isEmpty ? 'Mescit' : d,
                      style: TextStyle(
                        fontSize: 12,
                        color: ctxInkSoft(context),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  app.toggleFav(f.key, f.name, f.lat, f.lon);
                  toast(context, 'Favorilerden \u00E7\u0131kar\u0131ld\u0131');
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: ctxInkSoft(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

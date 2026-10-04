import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../utils.dart';
import 'place_sheet.dart';

class MapScreen extends StatefulWidget {
  final void Function(int tabIndex)? onGoHome;
  const MapScreen({super.key, this.onGoHome});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _controller = MapController();

  /// GPS ilk geldiğinde haritayı otomatik ortalama; kullanıcı elle oynayınca kapanır.
  bool _followUser = true;

  /// Son kullanıcı jestinin zamanı; jest bitiminde kısa süre otomatik ortalamayı
  /// bastırır (zoom/kaydırma sırasında harita "sıçramasın").
  DateTime _lastGesture = DateTime.fromMillisecondsSinceEpoch(0);

  double? _lastKnownZoom;

  @override
  void initState() {
    super.initState();
    final loc = services.location;
    if (!loc.hasLocation) {
      Future.microtask(() => loc.start());
    }
  }

  /// Güvenli kamera okuması: harita daha kurulmadıysa veya çöktüyse null döner.
  MapCamera? _safeCamera() {
    try {
      return _controller.camera;
    } catch (_) {
      return null;
    }
  }

  void _recenter() {
    final loc = services.location;
    _followUser = true;
    final z = (_lastKnownZoom ?? 14.0).clamp(5.0, 19.0).toDouble();
    try {
      _controller.move(LatLng(loc.userLat, loc.userLng), z);
    } catch (_) {}
  }

  void _zoomBy(double d) {
    final cam = _safeCamera();
    final base = cam?.zoom ?? _lastKnownZoom ?? 14.0;
    final z = (base + d).clamp(5.0, 19.0).toDouble();
    if (cam == null) return;
    try {
      _controller.move(cam.center, z);
      _lastKnownZoom = z;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final app = services.app;
    final loc = services.location;
    final p = services.prayer;
    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([loc, app, p]),
        builder: (_, _) {
          final userPos = LatLng(loc.userLat, loc.userLng);
          // Konum ilk kez geldiğinde/anlamlı değiştiğinde ortala; küçük GPS
          // titremeleri ve her saniyeki yeniden çizimler haritayı oynatmasın.
          // Son 4 saniyede jest yapılmışsa ortalamayı atla (zoom sıçraması önlenir).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_followUser) return;
            if (DateTime.now().difference(_lastGesture).inSeconds < 4) return;
            final cam = _safeCamera();
            if (cam == null) return;
            _lastKnownZoom = cam.zoom;
            final moved = haversine(
              cam.center.latitude,
              cam.center.longitude,
              userPos.latitude,
              userPos.longitude,
            );
            if (moved > 40) {
              try {
                _controller.move(userPos, cam.zoom);
              } catch (_) {}
            }
          });
          return Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: userPos,
                  initialZoom: 14,
                  minZoom: 5,
                  maxZoom: 19,
                  backgroundColor: T.bodyBg,
                  onTap: (_, _) {},
                  onPositionChanged: (camera, hasGesture) {
                    // Kullanıcı elle kaydırdıysa otomatik ortalamayı bırak.
                    if (hasGesture) {
                      _followUser = false;
                      _lastGesture = DateTime.now();
                      _lastKnownZoom = camera.zoom;
                    }
                  },
                ),
                children: [
                  TileLayer(
                    // OSM genel sunucusu alt alan adlarını önermiyor; tek ana makine kullanılır.
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.neredekilacagim.neredekilacagim',
                    maxNativeZoom: 19,
                    maxZoom: 19,
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: userPos,
                        radius: 8,
                        color: T.gold,
                        borderColor: Colors.white,
                        borderStrokeWidth: 3,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: loc.places
                        .map(
                          (m) => Marker(
                            point: LatLng(m.lat, m.lon),
                            width: 34,
                            height: 34,
                            child: GestureDetector(
                              onTap: () => showPlaceSheet(context, m),
                              child: Icon(
                                Icons.location_on,
                                size: 32,
                                color: app.isFav(m.key)
                                    ? T.green700
                                    : T.green600,
                                shadows: const [
                                  Shadow(color: Colors.white, blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (loc.activeRoute != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: loc.activeRoute!
                              .map((c) => LatLng(c[0], c[1]))
                              .toList(),
                          strokeWidth: 4,
                          color: T.green700,
                          borderStrokeWidth: 1,
                          borderColor: Colors.white,
                        ),
                      ],
                    ),
                ],
              ),
              // üst: vakit pill (web vakit-pill)
              Positioned(
                top: 8,
                left: 12,
                child: GestureDetector(
                  onTap: () => widget.onGoHome?.call(0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: T.green600,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${p.vakitler[p.nextPrayerIndex].name} ${p.vakitler[p.nextPrayerIndex].time}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // konum bannerı
              if (loc.message != null)
                Positioned(
                  top: 54,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: ctxPaper(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ctxLine(context)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.my_location,
                          size: 16,
                          color: T.green600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loc.message!,
                            style: TextStyle(
                              fontSize: 12,
                              color: ctxInk(context),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // zoom + konum
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  children: [
                    _iconBtn(Icons.add, () => _zoomBy(1)),
                    _iconBtn(Icons.remove, () => _zoomBy(-1)),
                    _iconBtn(Icons.my_location, _recenter),
                  ],
                ),
              ),
              // yakınlardaki şerit (haritada açılır liste)
              if (loc.places.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: ctxPaper(context),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 8),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: loc.places
                            .take(6)
                            .map((m) => _placeChip(context, m))
                            .toList(),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _placeChip(BuildContext context, Mosque m) {
    return GestureDetector(
      onTap: () => showPlaceSheet(context, m),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ctxCream(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ctxLine(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ctxInk(context),
              ),
              maxLines: 1,
            ),
            Text(
              m.dist,
              style: TextStyle(fontSize: 11, color: ctxInkSoft(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: ctxPaper(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: ctxInk(context)),
      ),
    );
  }
}

/// Haritada aktif rotayı takip eden yardımcı (routes yerel kalır).
List<List<double>> polylineCoords() =>
    services.location.activeRoute ?? const [];

String distHuman(double meters) => distText(meters);

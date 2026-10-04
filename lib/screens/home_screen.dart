import 'dart:async';

import 'package:flutter/material.dart';

import '../location.dart';
import '../prayer.dart';
import '../services.dart';
import '../theme.dart';
import '../utils.dart';

/// CanlÄ± saat satÄ±rÄ± (HH:MM).
class ClockLine extends StatefulWidget {
  const ClockLine({super.key});
  @override
  State<ClockLine> createState() => _ClockLineState();
}

class _ClockLineState extends State<ClockLine> {
  late String _now;

  @override
  void initState() {
    super.initState();
    _now = _fmt(DateTime.now());
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = _fmt(DateTime.now()));
    });
  }

  static String _fmt(DateTime n) => '${pad2(n.hour)}:${pad2(n.minute)}';

  @override
  Widget build(BuildContext context) {
    return Text(
      _now,
      style: TextStyle(
        fontSize: 13,
        color: ctxInkSoft(context),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Ezan Vakti: hero geri sayÄ±m + vakit Ä±zgarasÄ± (+ konum izni uyarÄ±sÄ±).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = services.prayer;
    final loc = services.location;
    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([p, loc, services.app]),
        builder: (_, _) {
          final now = DateTime.now();
          final clock = '${pad2(now.hour)}:${pad2(now.minute)}';
          final ann = services.app.remote.announcement;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              if (ann.enabled && ann.text.trim().isNotEmpty) ...[
                _announceBand(context, ann.text.trim()),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _locText(p, loc),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ctxInk(context),
                      ),
                    ),
                  ),
                  const ClockLine(),
                ],
              ),
              const SizedBox(height: 12),
              _buildHero(context, clock, p),
              if (loc.permissionDenied) ...[
                const SizedBox(height: 10),
                _permWarning(context, loc),
              ],
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: List.generate(
                  p.vakitler.length,
                  (i) => _vakitCard(context, i, p),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _locText(PrayerService p, LocationService loc) {
    if (p.districtName.isNotEmpty) return capTr(p.districtName);
    if (loc.ipCity.isNotEmpty) return 'Yakla\u015F\u0131k: ${loc.ipCity}';
    return 'Konum al\u0131n\u0131yorâ€¦';
  }

  Widget _announceBand(BuildContext context, String text) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0x2B047857) : const Color(0xFFECFDF5);
    final fg = dark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: fg,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, String clock, PrayerService p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [T.green700, T.green600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            p.nextLabel,
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Text(
            p.nextDistance,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${p.vakitler[p.nextPrayerIndex].name} vakti',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: .18), height: 1),
          const SizedBox(height: 10),
          Text(
            '$clock \u00B7 ${services.app.remote.heroVakitTitle}',
            style: const TextStyle(color: Color(0xBBFFFFFF), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _vakitCard(BuildContext context, int i, PrayerService p) {
    final v = p.vakitler[i];
    final cur = i == p.currentIndex;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cur ? ctxGreenLight(context) : ctxPaper(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cur ? T.green600 : ctxLine(context),
          width: cur ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            v.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cur ? T.green700 : ctxInkSoft(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            v.time,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ctxInk(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permWarning(BuildContext context, LocationService loc) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0x2B92400E) : const Color(0xFFFEF3C7);
    final fg = dark ? const Color(0xFFFBBF24) : const Color(0xFF92400E);
    final String msg;
    if (loc.locationServiceDisabled) {
      msg =
          'Cihaz konum servisi kapal\u0131. Namaz vakitleri ve yak\u0131ndaki mescitler do\u011Fru g\u00F6sterilmez; konumu a\u00E7\u0131n.';
    } else if (loc.permissionDeniedForever) {
      msg =
          'Konum izni kal\u0131c\u0131 olarak reddedildi. Namaz vakitleri ve yak\u0131ndaki mescitler tahmini konumla g\u00F6sterilir; do\u011Fruluk i\u00E7in cihaz ayarlar\u0131ndan izin verin.';
    } else {
      msg =
          'Konum izni verilmedi. Namaz vakitleri ve yak\u0131ndaki mescitler yanl\u0131\u015F veya eksik g\u00F6r\u00FCnebilir.';
    }
    final label = loc.locationServiceDisabled
        ? 'Konum A\u00E7'
        : (loc.permissionDeniedForever
              ? 'Ayarlar\u0131 A\u00E7'
              : '\u0130zin Ver');
    final Future<void> Function() action = loc.locationServiceDisabled
        ? loc.openLocationSettings
        : loc.askPermission;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(Icons.gps_off, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(fontSize: 12, color: fg, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: () => action(),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

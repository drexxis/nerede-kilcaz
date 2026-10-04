import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// Legacy starText: n adet ★ (≈ avg).
String starText(double r) => '\u2605' * r.round().clamp(0, 5);

bool validEmail(String e) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e);

/// Küçük işaret sırası (★) — ranking/avg gösterimi.
class StarLine extends StatelessWidget {
  final double rating;
  final double size;
  final bool showNum;
  const StarLine({super.key, required this.rating, this.size = 13, this.showNum = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(starText(rating), style: TextStyle(color: ctxGold(context), fontSize: size, letterSpacing: 1)),
        if (showNum) ...[
          const SizedBox(width: 4),
          Text(rating.toStringAsFixed(1), style: TextStyle(color: ctxInk(context), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

/// Alan adı + meta satırılı liste kartı (nearby-card / fav-card karşılığı).
class MosqueCard extends StatelessWidget {
  final Mosque m;
  final VoidCallback onTap;
  final Widget? trailing;
  final AggRecord? agg;
  const MosqueCard({super.key, required this.m, required this.onTap, this.trailing, this.agg});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                child: Icon(Icons.mosque, size: 22, color: T.green600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ctxInk(context))),
                    const SizedBox(height: 3),
                    Text(metaText(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: ctxInkSoft(context))),
                  ],
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  /// "★·4.5 · 120m" | "Henüz değerlendirme yok · 120m"
  String metaText(BuildContext context) {
    final d = m.dist.isNotEmpty ? m.dist : '';
    if (agg != null && agg!.count > 0) {
      final base = '${starText(agg!.avg)} ${agg!.avg.toStringAsFixed(1)}';
      return d.isEmpty ? base : '$base \u00B7 $d';
    }
    return d.isEmpty ? 'Mescit' : 'Hen\u00FCz de\u011Ferlendirme yok \u00B7 $d';
  }
}

/// Beraberinde detayı açan küçük ilerleme oku.
Widget chevron() => Icon(Icons.chevron_right, size: 20, color: T.gold);

/// Sağ üst "gerçek kullanıcı" işareti yok; bunun yerine yuvarlak simge.
Widget mosIcon() => Icon(Icons.mosque, size: 22, color: T.green600);

/// Genel boş durum (empty-state).
class EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyState({super.key, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 44, color: ctxInkSoft(context)),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ctxInkSoft(context), height: 1.5)),
        ],
      ),
    );
  }
}

/// Küçük etiket (tag).
class Tag extends StatelessWidget {
  final String text;
  const Tag(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      decoration: BoxDecoration(
        color: ctxGreenLight(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, color: T.green700)),
    );
  }
}

/// Yorum başı yıldızlar + veri.
class RatingPill extends StatelessWidget {
  final AggRecord? agg;
  const RatingPill({super.key, this.agg});

  @override
  Widget build(BuildContext context) {
    if (agg == null || agg!.count == 0) {
      return Text('Hen\u00FCz de\u011Ferlendirme yok', style: TextStyle(fontSize: 12, color: ctxInkSoft(context)));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StarLine(rating: agg!.avg),
        Text(' ${agg!.avg.toStringAsFixed(1)} \u00B7 ${agg!.count} de\u011Ferlendirme',
            style: TextStyle(fontSize: 12, color: ctxInk(context))),
      ],
    );
  }
}
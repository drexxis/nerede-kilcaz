import 'package:flutter/material.dart';

import '../api.dart';
import '../links.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

/// Mescit detayı (openDetail karşılığı).
class DetailScreen extends StatefulWidget {
  final Mosque mosque;
  const DetailScreen({super.key, required this.mosque});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final String _addr = 'Adres y\u00FCkleniyor…';
  String? _addrResult;

  @override
  void initState() {
    super.initState();
    _loadAddr();
  }

  Future<void> _loadAddr() async {
    try {
      final a = await Api.resolveAddr(widget.mosque.lat, widget.mosque.lon);
      final parts = <String>[];
      if (a.district.isNotEmpty) parts.add(a.district);
      if (a.province.isNotEmpty && !parts.contains(a.province))
        parts.add(a.province);
      if (a.country.isNotEmpty) parts.add(a.country);
      _addrResult = parts.isNotEmpty
          ? parts.join(', ')
          : 'Adres bulunamad\u0131';
    } catch (_) {
      _addrResult = 'Adres bulunamad\u0131';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = services.app;
    final m = widget.mosque;
    final agg = app.aggOf(m.key);
    final photos = app.photosFor(m.key);
    return Scaffold(
      appBar: AppBar(title: const Text('Mescit Detay\u0131')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          if (photos.isNotEmpty) ...[
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    photos[i],
                    width: 220,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            Container(
              height: 96,
              decoration: BoxDecoration(
                color: ctxGreenLight(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Hen\u00FCz foto\u011Fraf yok',
                  style: TextStyle(fontSize: 13, color: ctxInkSoft(context)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            m.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ctxInk(context),
            ),
          ),
          const SizedBox(height: 6),
          RatingPill(agg: agg),
          const SizedBox(height: 8),
          Text(
            _addrResult ?? _addr,
            style: TextStyle(fontSize: 12.5, color: ctxInkSoft(context)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: m.tags.map((t) => Tag(t)).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => openGmaps(m.lat, m.lon),
                icon: const Icon(Icons.map, size: 16),
                label: const Text('Google Haritalar\'da A\u00E7'),
              ),
              const SizedBox(width: 8),
              if (app.remote.features.favorites)
                OutlinedButton.icon(
                  onPressed: () {
                    app.toggleFav(m.key, m.name, m.lat, m.lon);
                    setState(() {});
                  },
                  icon: Icon(
                    app.isFav(m.key) ? Icons.star : Icons.star_border,
                    size: 16,
                  ),
                  label: Text(
                    app.isFav(m.key)
                        ? 'Favorilerden \u00C7\u0131kar'
                        : 'Favorilere Ekle',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _breakdown(context, agg),
          const SizedBox(height: 14),
          Text(
            'Yorumlar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ctxInk(context),
            ),
          ),
          const SizedBox(height: 8),
          if (agg == null || agg.reviews.isEmpty)
            Text(
              'Hen\u00FCz yorum yok. Mescide var\u0131nca puanlayabilirsiniz.',
              style: TextStyle(fontSize: 13, color: ctxInkSoft(context)),
            )
          else
            ..._sortedReviews(agg).map((r) => _reviewRow(context, r)),
        ],
      ),
    );
  }

  List<ReviewRecord> _sortedReviews(AggRecord agg) {
    final rs = [...agg.reviews]..sort((x, y) => y.ts - x.ts);
    return rs;
  }

  Widget _reviewRow(BuildContext context, ReviewRecord r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ctxPaper(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: ctxInk(context),
                  ),
                ),
              ),
              StarLine(rating: r.star.toDouble()),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            r.comment.isNotEmpty ? r.comment : 'Yorum yaz\u0131lmad\u0131.',
            style: TextStyle(
              fontSize: 13,
              color: r.comment.isNotEmpty
                  ? ctxInk(context)
                  : ctxInkSoft(context),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _mini(r.cleanliness, 'Temizlik'),
              _mini(r.accessibility, 'Eri\u015Filebilirlik'),
              _mini(r.ablution, 'Abdest \u0130mk\u00E2n\u0131'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(int v, String label) => Text(
    '$label: ${v > 0 ? '$v/5' : '–'}',
    style: TextStyle(fontSize: 11.5, color: ctxInkSoft(context)),
  );

  Widget _breakdown(BuildContext context, AggRecord? agg) {
    Widget bar(String label, CatAgg? cat) {
      final v = cat != null && cat.n > 0 ? cat.sum / cat.n : 0.0;
      return Row(
        children: [
          SizedBox(
            width: 106,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: ctxInkSoft(context)),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 8,
                color: ctxLine(context),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v > 0 ? v / 5 : 0,
                  child: Container(color: T.green600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              v > 0 ? v.toStringAsFixed(1) : '–',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12.5, color: ctxInk(context)),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Puan detaylar\u0131',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ctxInk(context),
          ),
        ),
        const SizedBox(height: 8),
        bar('Temizlik', agg?.cats['cleanliness']),
        const SizedBox(height: 6),
        bar('Eri\u015Filebilirlik', agg?.cats['accessibility']),
        const SizedBox(height: 6),
        bar('Abdest \u0130mk\u00E2n\u0131', agg?.cats['ablution']),
      ],
    );
  }
}

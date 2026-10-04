import 'package:flutter/material.dart';

import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'place_sheet.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final app = services.app;
    final loc = services.location;
    final p = services.prayer;
    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([loc, app, p]),
        builder: (_, _) {
          final visible = loc.places.where(listVisible).toList();
          final locText = p.districtName.isNotEmpty
              ? capTr(p.districtName)
              : (loc.ipCity.isNotEmpty ? 'Yakla\u015F\u0131k: ${loc.ipCity}' : 'Konum al\u0131n\u0131yor…');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Mescit Listesi',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ctxInk(context))),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Text(locText, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: ctxInkSoft(context))),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip('all', 'T\u00FCm\u00FC'),
                      _chip('abdest', 'Abdesthane'),
                      _chip('kadin', 'Kad\u0131nlar \u0130\u00E7in'),
                      _chip('erisilebilir', 'Eri\u015Filebilir'),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text('${visible.length} yer bulundu',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ctxInkSoft(context))),
              ),
              Expanded(
                child: loc.places.isEmpty
                    ? EmptyState(text: loc.message ?? 'Mescitler y\u00FCkleniyor…', icon: Icons.mosque_outlined)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        children: visible.map((m) {
                          return MosqueCard(
                            m: m,
                            agg: app.aggOf(m.key),
                            onTap: () => showPlaceSheet(context, m),
                            trailing: const Icon(Icons.chevron_right, size: 20, color: T.gold),
                          );
                        }).toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool listVisible(Mosque m) {
    if (_filter == 'all') return true;
    final nf = normalizeText(_filter);
    return m.tags.any((t) => normalizeText(t).contains(nf));
  }

  Widget _chip(String f, String label) {
    final on = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? T.green600 : ctxPaper(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? T.green600 : ctxLine(context)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: on ? Colors.white : ctxInkSoft(context))),
      ),
    );
  }
}
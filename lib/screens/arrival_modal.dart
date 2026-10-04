import 'package:flutter/material.dart';

import '../auth_screen.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../utils.dart';

/// Varış puanlama modalı (showArrivalModal karşılığı).
/// Puanlamak için giriş gerekir; giriş yoksa giriş ekranı açılır.
Future<void> showArrivalModal(BuildContext context, Mosque m) {
  if (!services.app.isLoggedIn) {
    final nav = services.nav.currentContext;
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AuthScreen(reason: AuthReason.arrivalRequest)))
        .then((_) {
      if (nav != null && nav.mounted && services.app.isLoggedIn) showArrivalModal(nav, m);
    });
  }
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ArrivalDialog(m: m),
  );
}

/// Gövde üstünde sabit alt şerit: varış tespitinde "Puanla" kısayolu.
class ArrivalOverlay extends StatelessWidget {
  final Mosque mosque;
  const ArrivalOverlay({super.key, required this.mosque});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Material(
          color: ctxPaper(context),
          elevation: 6,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Icon(Icons.place, color: T.green600),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Var\u0131\u015F!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ctxInk(context))),
                      Text(
                        '${mosque.name}${trDative(mosque.name)} ula\u015Ft\u0131n\u0131z',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: ctxInkSoft(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => showArrivalModal(context, mosque),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(color: T.green600, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Puanla',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                IconButton(
                  onPressed: () => services.location.skipArrival(mosque),
                  icon: const Icon(Icons.close, size: 20),
                  color: ctxInkSoft(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrivalDialog extends StatefulWidget {
  final Mosque m;
  const _ArrivalDialog({required this.m});
  @override
  State<_ArrivalDialog> createState() => _ArrivalDialogState();
}

class _ArrivalDialogState extends State<_ArrivalDialog> {
  int _star = 0;
  final Map<String, int> _cats = {};
  final _comment = TextEditingController();

  bool get _canSubmit =>
      _star > 0 && (_cats['cleanliness'] ?? 0) > 0 && (_cats['accessibility'] ?? 0) > 0 && (_cats['ablution'] ?? 0) > 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    final app = services.app;
    app.addReview(
      widget.m.key,
      ReviewRecord(
        email: app.sessionEmail,
        name: app.currentUserName,
        star: _star,
        cleanliness: _cats['cleanliness'] ?? 0,
        accessibility: _cats['accessibility'] ?? 0,
        ablution: _cats['ablution'] ?? 0,
        comment: _comment.text.trim(),
        ts: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    services.location.clearArrival();
    Navigator.of(context).pop();
    toast(context, 'Puan\u0131n\u0131z kaydedildi. Te\u015Fekk\u00FCrler');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? T.darkPaper : T.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${widget.m.name}${trDative(widget.m.name)} Ula\u015Ft\u0131n\u0131z!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? T.darkInk : T.ink)),
              const SizedBox(height: 8),
              Text('Deneyiminizi puanlayabilir veya \u201CSonra Puanla\u201D ile ge\u00E7ebilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: isDark ? T.darkInkSoft : T.inkSoft)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final on = i < _star;
                  return IconButton(
                    onPressed: () => setState(() => _star = i + 1),
                    icon: Icon(on ? Icons.star : Icons.star_border,
                        size: 34, color: on ? ctxGold(context) : ctxInkSoft(context)),
                  );
                }),
              ),
              const SizedBox(height: 10),
              _catRow(context, 'Temizlik', 'cleanliness'),
              _catRow(context, 'Eri\u015Filebilirlik', 'accessibility'),
              _catRow(context, 'Abdest \u0130mk\u00E2n\u0131', 'ablution'),
              const SizedBox(height: 8),
              TextField(
                controller: _comment,
                maxLines: 2,
                minLines: 1,
                style: TextStyle(fontSize: 13.5, color: isDark ? T.darkInk : T.ink),
                decoration: InputDecoration(
                  hintText: 'Yorum yaz (opsiyonel)…',
                  hintStyle: TextStyle(fontSize: 12.5, color: isDark ? T.darkInkSoft : T.inkSoft),
                  filled: true,
                  fillColor: isDark ? T.darkCream : T.cream,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? T.darkLine : T.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? T.darkLine : T.line)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(disabledBackgroundColor: ctxLine(context)),
                  child: const Text('Puan\u0131 G\u00F6nder'),
                ),
              ),
              TextButton(
                onPressed: () {
                  services.location.skipArrival(widget.m);
                  Navigator.of(context).pop();
                  toast(context, 'Sonra puanlayabilirsiniz');
                },
                child: Text('Sonra Puanla', style: TextStyle(fontSize: 13, color: isDark ? T.darkInkSoft : T.inkSoft)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _catRow(BuildContext context, String label, String key) {
    final cur = _cats[key] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 112, child: Text(label, style: TextStyle(fontSize: 13, color: isDark(context) ? T.darkInk : T.ink))),
          const Spacer(),
          Row(
            children: List.generate(5, (i) {
              final v = i + 1;
              final on = v == cur;
              return GestureDetector(
                onTap: () => setState(() => _cats[key] = v),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 30,
                  height: 26,
                  decoration: BoxDecoration(
                    color: on ? T.green600 : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: on ? T.green600 : ctxLine(context)),
                  ),
                  child: Center(
                    child: Text('$v', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? Colors.white : ctxInkSoft(context))),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
}
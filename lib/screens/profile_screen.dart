import 'package:flutter/material.dart';

import '../auth_screen.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserRecord? _u;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _u = services.app.currentUserRecord();
  }

  String get _name => _u?.name ?? services.app.currentUserName;
  String get _email => _u?.email ?? services.app.sessionEmail;

  int _myRatings() {
    if (_email.isEmpty) return 0;
    var n = 0;
    final email = _email;
    for (final a in services.app.agg.values) {
      for (final r in a.reviews) {
        if (r.email == email) n++;
      }
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final app = services.app;
    // Route olarak açıldığında Material ancestral için Scaffold şart.
    return Scaffold(
      backgroundColor: ctxBodyBg(context),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: app,
          builder: (_, _) {
            _u = app.currentUserRecord();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: T.green600,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (_name.isNotEmpty ? _name : _email).characters.first
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ctxInk(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _email,
                            style: TextStyle(
                              fontSize: 12,
                              color: ctxInkSoft(context),
                            ),
                          ),
                          Text(
                            _joinedLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              color: ctxInkSoft(context),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _statCard(
                      context,
                      Icons.location_on_outlined,
                      app.pending.length.toString(),
                      'Kay\u0131tl\u0131 mescit',
                      flex: 3,
                    ),
                    const SizedBox(width: 8),
                    _statCard(
                      context,
                      Icons.favorite_border,
                      app.favs.length.toString(),
                      'Favoriler',
                      flex: 2,
                    ),
                    const SizedBox(width: 8),
                    _statCard(
                      context,
                      Icons.star_border,
                      _myRatings().toString(),
                      'Puan\u0131m',
                      flex: 2,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Hesap'),
                _settingRow(
                  context,
                  Icons.login,
                  'Google ile giri\u015F',
                  'Yak\u0131nda',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => logout(),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('\u00C7\u0131k\u0131\u015F Yap'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: T.danger,
                      side: const BorderSide(color: Color(0xFFEF9A9A)),
                    ),
                    onPressed: () => _confirmDelete(),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hesab\u0131m\u0131 Sil'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _joinedLabel() {
    final t = _u?.createdAt;
    if (t == null || t == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(t);
    const aylar = [
      'Ocak',
      '\u015E\u0054ubat',
      'Mart',
      'Nisan',
      'May\u0131s',
      'Haziran',
      'Temmuz',
      'A\u011Fustos',
      'Eyl\u00FCl',
      'Ekim',
      'Kas\u0131m',
      'Aral\u0131k',
    ];
    return 'Kat\u0131l\u0131m: ${aylar[d.month - 1]} ${d.year}';
  }

  Widget _sectionTitle(BuildContext c, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ctxInkSoft(c),
      ),
    ),
  );

  Widget _statCard(
    BuildContext c,
    IconData ic,
    String v,
    String l, {
    required int flex,
  }) => Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: ctxPaper(c),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ctxLine(c)),
      ),
      child: Column(
        children: [
          Icon(ic, size: 18, color: T.green600),
          const SizedBox(height: 6),
          Text(
            v,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ctxInk(c),
            ),
          ),
          const SizedBox(height: 2),
          Text(l, style: TextStyle(fontSize: 11, color: ctxInkSoft(c))),
        ],
      ),
    ),
  );

  Widget _settingRow(
    BuildContext c,
    IconData ic,
    String title,
    String subtitle,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: ctxPaper(c),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ctxLine(c)),
    ),
    child: Row(
      children: [
        Icon(ic, size: 18, color: ctxInkSoft(c)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 13.5, color: ctxInk(c)),
          ),
        ),
        Text(subtitle, style: TextStyle(fontSize: 11, color: ctxInkSoft(c))),
      ],
    ),
  );

  void logout() {
    services.app.logout();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hesab\u0131 Sil?'),
        content: const Text(
          'Hesab\u0131n\u0131z ve t\u00FCm verileriniz (puanlar, favoriler, kay\u0131tlar) silinecek. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Vazge\u00E7'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: T.danger),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await services.app.deleteAccount();
    if (mounted) toast(context, 'Hesab\u0131n\u0131z silindi');
  }
}

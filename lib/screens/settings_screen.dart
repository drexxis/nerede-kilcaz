import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services.dart';
import '../theme.dart';
import '../links.dart';
import '../update_service.dart';
import 'add_screen.dart';
import 'fav_screen.dart';
import 'info_pages.dart';
import 'profile_screen.dart';

/// Ayarlar sekmesi: Profil başta olmak üzere favoriler, mescit ekleme,
/// görünüm (tema), bilgi sayfaları ve çıkış.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _storedTheme() {
    switch (services.app.themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final app = services.app;
    return SafeArea(
      child: AnimatedBuilder(
        animation: app,
        builder: (_, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Text(
                'Ayarlar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ctxInk(context),
                ),
              ),
              const SizedBox(height: 14),
              _section(context, 'Hesap'),
              _row(
                context,
                Icons.person_outline,
                'Profil',
                _subProfile(app),
                () => _open(context, const ProfileScreen()),
              ),
              _row(
                context,
                Icons.favorite_border,
                'Favorilerim',
                app.favs.isEmpty
                    ? 'Hen\u00FCz favori yok'
                    : '${app.favs.length} mescit',
                () => _open(context, const FavScreen()),
              ),
              if (app.remote.features.addMosque)
                _row(
                  context,
                  Icons.add_location_alt_outlined,
                  'Mescit Ekle',
                  app.pending.isEmpty
                      ? 'Yeni mescit \u00F6ner'
                      : '${app.pending.length} kay\u0131t onay\u0131 bekleniyor',
                  () => _open(context, const AddMosqueScreen()),
                ),
              const SizedBox(height: 14),
              _section(context, 'G\u00F6r\u00FCn\u00FCm'),
              _themeRow(context),
              const SizedBox(height: 14),
              _section(context, 'Bilgi'),
              _row(
                context,
                Icons.privacy_tip_outlined,
                'Gizlilik Politikas\u0131',
                '',
                () => _open(context, const PrivacyPage()),
              ),
              _row(
                context,
                Icons.description_outlined,
                'Kullan\u0131m \u015Eartlar\u0131',
                '',
                () => _open(context, const TermsPage()),
              ),
              _row(
                context,
                Icons.help_outline,
                'S\u0131k\u00E7a Sorulan Sorular',
                '',
                () => _open(context, const SssPage()),
              ),
              _row(
                context,
                Icons.info_outline,
                'Hakk\u0131m\u0131zda',
                '',
                () => _open(context, const AboutPage()),
              ),
              if (app.remote.features.contact)
                _row(
                  context,
                  Icons.chat_outlined,
                  'Bize Ula\u015F\u0131n',
                  '',
                  () => _open(context, const ContactPage()),
                ),
              if (app.remote.links.isNotEmpty) ...[
                const SizedBox(height: 14),
                _section(context, 'Ba\u011Flant\u0131lar'),
                for (final l in app.remote.links)
                  _row(
                    context,
                    Icons.link,
                    l.label.isEmpty ? l.url : l.label,
                    '',
                    () => openUrl(l.url),
                  ),
              ],
              const SizedBox(height: 14),
              _section(context, 'Uygulama'),
              _row(
                context,
                Icons.update_outlined,
                'G\u00FCncellemeleri Kontrol Et',
                app.updateAvailable ? 'G\u00FCncelleme var' : '',
                () => _checkUpdates(context),
              ),
              _row(
                context,
                Icons.info_outline,
                'S\u00FCr\u00FCm',
                app.appVersion,
                () {},
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => services.app.logout(),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('\u00C7\u0131k\u0131\u015F Yap'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _subProfile(AppState app) {
    final u = app.currentUserRecord();
    return u?.name ?? app.currentUserName;
  }

  Future<void> _checkUpdates(BuildContext context) async {
    final app = services.app;
    final messenger = ScaffoldMessenger.of(context);
    await app.refreshConfig();
    if (!context.mounted) return;
    if (app.updateRequired) {
      // Tam ekran update zaten _Root tarafında görünür; bir şey yapmaya gerek yok.
      return;
    }
    if (app.updateAvailable) {
      await showSoftUpdateDialog(context);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Uygulama g\u00FCncel.')),
      );
    }
  }

  Widget _section(BuildContext c, String t) => Padding(
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

  Widget _row(
    BuildContext c,
    IconData ic,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: ctxPaper(c),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ctxLine(c)),
          ),
          child: Row(
            children: [
              Icon(ic, size: 19, color: T.green600),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: ctxInk(c),
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: ctxInkSoft(c)),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: T.gold),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeRow(BuildContext c) {
    final t = _storedTheme();
    return Row(
      children: [
        _themeOpt(
          c,
          'light',
          'A\u00E7\u0131k',
          Icons.light_mode_outlined,
          t == 'light',
        ),
        const SizedBox(width: 8),
        _themeOpt(c, 'dark', 'Koyu', Icons.dark_mode_outlined, t == 'dark'),
        const SizedBox(width: 8),
        _themeOpt(
          c,
          'system',
          'Sistem',
          Icons.settings_brightness_outlined,
          t == 'system',
        ),
      ],
    );
  }

  Widget _themeOpt(
    BuildContext c,
    String v,
    String label,
    IconData ic,
    bool on,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => services.app.setTheme(v)),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? T.green600 : ctxPaper(c),
            border: Border.all(color: on ? T.green700 : ctxLine(c)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(ic, size: 18, color: on ? Colors.white : ctxInkSoft(c)),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? Colors.white : ctxInkSoft(c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../auth_screen.dart';
import '../services.dart';
import '../theme.dart';

class InfoPage extends StatelessWidget {
  final String title;
  final String lede;
  final List<Widget> body;
  final Widget? footer;

  const InfoPage({
    super.key,
    required this.title,
    required this.lede,
    required this.body,
    this.footer,
  });

  void _mapBack(BuildContext context) {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => _mapBack(context),
        ),
        title: Text('Geri'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ctxInk(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lede,
            style: TextStyle(
              fontSize: 13.5,
              color: ctxInkSoft(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ...body,
          if (footer != null) ...[const SizedBox(height: 20), footer!],
        ],
      ),
    );
  }
}

class InfoBlock extends StatelessWidget {
  final String title;
  final String text;

  const InfoBlock({super.key, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ctxPaper(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ctxLine(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: ctxInk(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: ctxInkSoft(context),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class FaqItem extends StatelessWidget {
  final String q;
  final String a;

  const FaqItem({super.key, required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ctxPaper(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ctxLine(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ctxInk(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            a,
            style: TextStyle(
              fontSize: 13,
              color: ctxInkSoft(context),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class SssPage extends StatelessWidget {
  const SssPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.app,
      builder: (_, _) {
        final faq = services.app.remote.faq;
        return InfoPage(
          title: 'S\u0131k\u00E7a Sorulan Sorular',
          lede:
              'Nerede K\u0131laca\u011F\u0131m? hakk\u0131nda en \u00E7ok merak edilenler.',
          body: faq.isEmpty
              ? [const InfoBlock(title: '', text: 'Hen\u00FCz soru eklenmedi.')]
              : faq.map((f) => FaqItem(q: f.q, a: f.a)).toList(),
          footer: OutlinedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Anasayfaya D\u00F6n'),
          ),
        );
      },
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.app,
      builder: (_, _) {
        final s = services.app.remote.about;
        return InfoPage(
          title: s.title.isEmpty ? 'Hakk\u0131m\u0131zda' : s.title,
          lede: s.lede.isEmpty
              ? 'Nerede K\u0131laca\u011F\u0131m? bir topluluk giri\u015Fimidir.'
              : s.lede,
          body: s.blocks
              .map((b) => InfoBlock(title: b.title, text: b.text))
              .toList(),
          footer: OutlinedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Anasayfaya D\u00F6n'),
          ),
        );
      },
    );
  }
}

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _msg = TextEditingController();

  /// Panelden yönetilen giriş metni (ui.contactLede).
  String get _lede => services.app.remote.contactLede;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _msg.dispose();
    super.dispose();
  }

  void _submit() {
    if (_msg.text.trim().isNotEmpty) {
      services.app.addContact(
        _name.text.trim(),
        _email.text.trim(),
        _msg.text.trim(),
      );
      toast(context, 'Mesaj\u0131n\u0131z bize ula\u015Ft\u0131');
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      toast(context, 'L\u00FCtfen mesaj\u0131n\u0131z\u0131 yaz\u0131n');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.app,
      builder: (context, _) => InfoPage(
        title: 'Bize Ula\u015F\u0131n',
        lede: _lede,
        body: [
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Ad\u0131n\u0131z',
              hintText: 'Ad\u0131n\u0131z Soyad\u0131n\u0131z',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              hintText: 'ornek@eposta.com',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _msg,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mesaj\u0131n\u0131z',
              hintText: 'Mesaj\u0131n\u0131z\u0131 yaz\u0131n\u2026',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _submit, child: const Text('G\u00F6nder')),
        ],
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.app,
      builder: (_, _) {
        final s = services.app.remote.privacy;
        return InfoPage(
          title: s.title.isEmpty ? 'Gizlilik Politikas\u0131' : s.title,
          lede: s.lede.isEmpty
              ? 'Verilerinizin nas\u0131l i\u015Flendi\u011Fini \u015Feffaf bi\u00E7imde a\u00E7\u0131kl\u0131yoruz.'
              : s.lede,
          body: s.blocks
              .map((b) => InfoBlock(title: b.title, text: b.text))
              .toList(),
        );
      },
    );
  }
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.app,
      builder: (_, _) {
        final s = services.app.remote.terms;
        return InfoPage(
          title: s.title.isEmpty ? 'Kullan\u0131m \u015Eartlar\u0131' : s.title,
          lede: s.lede.isEmpty
              ? 'Nerede K\u0131laca\u011F\u0131m? hizmetinin kullan\u0131m ko\u015Fullar\u0131. Uygulamay\u0131 kullanarak bu \u015Fartlar\u0131 kabul etmi\u015F say\u0131l\u0131rs\u0131n\u0131z.'
              : s.lede,
          body: s.blocks
              .map((b) => InfoBlock(title: b.title, text: b.text))
              .toList(),
        );
      },
    );
  }
}

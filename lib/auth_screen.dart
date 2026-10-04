import 'package:flutter/material.dart';

import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

enum AuthReason { mapRequest, addRequest, arrivalRequest, fresh }

class AuthScreen extends StatefulWidget {
  final AuthReason? reason;
  const AuthScreen({super.key, this.reason});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool reg = false;
  String? err;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  void _setTab(bool isReg) {
    setState(() {
      reg = isReg;
      err = null;
    });
  }

  void _err(String msg) => setState(() => err = msg);

  void _completeLogin(String email) {
    services.location.start();
    Navigator.of(context).pop(true);
  }

  void _submitLogin() {
    final email = _email.text.trim().toLowerCase();
    if (!validEmail(email)) return _err('Ge\u00E7erli bir e-posta girin');
    final ok = services.app.login(email, _pass.text);
    if (!ok) return _err('E-posta veya \u015Fifre hatal\u0131');
    _completeLogin(email);
  }

  void _submitReg() {
    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    final pass = _pass.text;
    if (name.isEmpty) return _err('Ad\u0131n\u0131z\u0131 girin');
    if (!validEmail(email)) return _err('Ge\u00E7erli bir e-posta girin');
    if (pass.length < 6) return _err('\u015Eifre en az 6 karakter olmal\u0131');
    if (pass != _pass2.text) return _err('\u015Eifreler e\u015Fle\u015Fmiyor');
    final u = services.app.register(name, email, pass);
    if (u == null) return _err('Bu e-posta zaten kay\u0131tl\u0131. Giri\u015F yap\u0131n.');
    _completeLogin(email);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A1628) : const Color(0xFFEAF2FE);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x293B82F6) : T.greenLight,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: isDark ? T.darkLine : Colors.white),
                  ),
                  child: Icon(Icons.mosque, size: 42, color: T.green600),
                ),
              ),
              const SizedBox(height: 16),
              Text('Nerede K\u0131laca\u011F\u0131m?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDark ? T.darkInk : T.ink)),
              const SizedBox(height: 6),
              Text('Cami ve mescit bul, Diyanet namaz vakitlerini \u00F6\u011Fren',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: isDark ? T.darkInkSoft : T.inkSoft)),
              const SizedBox(height: 26),
              Container(
                decoration: BoxDecoration(
                  color: T.green600,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _tab('Giri\u015F Yap', !reg, () => _setTab(false)),
                        ),
                        Expanded(
                          child: _tab('\u00DCye Ol', reg, () => _setTab(true)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (!reg) ...[
                      _field(_email, 'E-posta', 'ornek@eposta.com', TextInputType.emailAddress, false),
                      const SizedBox(height: 12),
                      _field(_pass, '\u015Eifre', '••••••••', TextInputType.text, true,
                          onSubmitted: _submitLogin),
                    ] else ...[
                      _field(_name, 'Ad\u0131n\u0131z', 'Ad\u0131n\u0131z Soyad\u0131n\u0131z', TextInputType.text, false),
                      const SizedBox(height: 12),
                      _field(_email, 'E-posta', 'ornek@eposta.com', TextInputType.emailAddress, false),
                      const SizedBox(height: 12),
                      _field(_pass, '\u015Eifre', '••••••••', TextInputType.text, true),
                      const SizedBox(height: 12),
                      _field(_pass2, '\u015Eifre Tekrar', '••••••••', TextInputType.text, true,
                          onSubmitted: _submitReg),
                    ],
                    if (err != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x29FFFFFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(err!, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: reg ? _submitReg : _submitLogin,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: Text(reg ? '\u00DCye Ol' : 'Giri\u015F Yap'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => toast(context, 'Google ile giri\u015F yak\u0131nda aktif olacak'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x44FFFFFF)),
                        minimumSize: const Size.fromHeight(44),
                      ),
                      icon: const Icon(Icons.g_mobiledata, size: 20),
                      label: const Text('Google ile giri\u015F'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Uygulamay\u0131 kullanabilmek i\u00E7in hesap olu\u015Fturman\u0131z zorunludur. Puanlamalar\u0131n\u0131z ve favorileriniz hesab\u0131n\u0131za kaydedilir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: isDark ? T.darkInkSoft : T.inkSoft, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool on, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: on ? T.green700 : Colors.white)),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint, TextInputType kt, bool obscure,
      {VoidCallback? onSubmitted}) {
    final white = c.text.isNotEmpty;
    return TextField(
      controller: c,
      keyboardType: kt,
      obscureText: obscure,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12.5),
        labelStyle: TextStyle(color: white ? Colors.white : const Color(0xCCFFFFFF), fontSize: 13),
        filled: true,
        fillColor: const Color(0x14FFFFFF),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white, width: 1.4),
        ),
      ),
    );
  }
}

/// Global toast (web showToast karşılığı).
void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2600)));
}
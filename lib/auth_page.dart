import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_config.dart';
import 'data_store.dart';

class AuthPage extends StatefulWidget {
  final AppDataController ctrl;
  final int initialTab; // 0: Masuk, 1: Daftar, 2: Reset WA
  const AuthPage({super.key, required this.ctrl, this.initialTab = 0});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  late int _modeIndex;
  int _prevModeIndex = 0;
  bool _darkTheme = false;
  bool _loginWithGmail = false;

  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final AnimationController _pulseCtrl;
  final ValueNotifier<String?> _mismatchNotifier = ValueNotifier<String?>(null);

  final _loginPhoneC = TextEditingController();
  final _loginGmailC = TextEditingController();
  final _loginPassC = TextEditingController();

  final _regPhoneC = TextEditingController();
  final _regNameC = TextEditingController();
  final _regPassC = TextEditingController();
  final _regPass2C = TextEditingController();
  final _regRefC = TextEditingController();

  final _resetPhoneC = TextEditingController();
  final _resetPassC = TextEditingController();
  final _resetPass2C = TextEditingController();

  bool _hideLoginPass = true;
  bool _hideRegPass1 = true;
  bool _hideRegPass2 = true;
  bool _hideResPass1 = true;
  bool _hideResPass2 = true;

  bool _loginBusy = false;
  bool _waWaiting = false;
  bool _sheetOpen = false;
  String? _waCode;
  String? _expectedPhone;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _modeIndex = widget.initialTab.clamp(0, 2);
    _prevModeIndex = _modeIndex;

    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    _mismatchNotifier.dispose();
    _loginPhoneC.dispose();
    _loginGmailC.dispose();
    _loginPassC.dispose();
    _regPhoneC.dispose();
    _regNameC.dispose();
    _regPassC.dispose();
    _regPass2C.dispose();
    _regRefC.dispose();
    _resetPhoneC.dispose();
    _resetPassC.dispose();
    _resetPass2C.dispose();
    super.dispose();
  }

  void _switchMode(int next) {
    if (next == _modeIndex) return;
    setState(() {
      _prevModeIndex = _modeIndex;
      _modeIndex = next;
      _errorMsg = null;
    });
  }

  Future<void> _doLogin() async {
    setState(() {
      _loginBusy = true;
      _errorMsg = null;
    });

    final err = _loginWithGmail
        ? await widget.ctrl.loginWithGmail(_loginGmailC.text, _loginPassC.text)
        : await widget.ctrl.loginWithPassword(_loginPhoneC.text, _loginPassC.text);

    if (!mounted) return;
    setState(() => _loginBusy = false);
    if (err != null) {
      setState(() => _errorMsg = err);
    } else {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil masuk ke 2S Member!')),
      );
    }
  }

  Future<void> _startWaOtp({required String mode}) async {
    final phoneInput = mode == 'register' ? _regPhoneC.text : _resetPhoneC.text;
    final pass = mode == 'register' ? _regPassC.text : _resetPassC.text;
    final pass2 = mode == 'register' ? _regPass2C.text : _resetPass2C.text;

    if (phoneInput.trim().length < 9) {
      setState(() => _errorMsg = 'Nomor WhatsApp wajib diisi dengan benar (contoh: 0812...).');
      return;
    }
    if (mode == 'register' && _regNameC.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Nama lengkap wajib diisi.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _errorMsg = 'Password minimal 6 karakter.');
      return;
    }
    if (pass != pass2) {
      setState(() => _errorMsg = 'Konfirmasi password tidak sama.');
      return;
    }

    _mismatchNotifier.value = null;
    setState(() {
      _errorMsg = null;
      _waWaiting = true;
    });

    final res = await widget.ctrl.startReverseOtp(
      mode: mode,
      rawPhone: phoneInput,
      name: _regNameC.text,
      password: pass,
      refCode: _regRefC.text,
      onMismatch: (wrongPhone) {
        if (!mounted) return;
        _mismatchNotifier.value =
            '⚠️ Pesan masuk dari $wrongPhone berbeda dengan nomor ${_expectedPhone ?? phoneInput}! Tetap menunggu pesan dari nomor terdaftar.';
      },
      onCompleted: (err) {
        if (!mounted) return;
        setState(() => _waWaiting = false);
        if (_sheetOpen) {
          _sheetOpen = false;
          Navigator.of(context).pop();
        }
        if (err != null) {
          setState(() => _errorMsg = err);
        } else {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mode == 'register' ? 'Pendaftaran & Verifikasi WA berhasil!' : 'Password baru berhasil disimpan!')),
          );
        }
      },
    );

    if (!mounted) return;
    if (res.error != null) {
      setState(() {
        _waWaiting = false;
        _errorMsg = res.error;
      });
      return;
    }

    setState(() {
      _waCode = res.code;
      _expectedPhone = res.expectedPhone;
    });
    _showReverseOtpSheet(
      mode == 'register' ? 'Verifikasi Daftar Akun' : 'Verifikasi Reset Password',
      res.code!,
      res.expectedPhone!,
    );
  }

  Future<void> _launchWa(String code) async {
    final msg = Uri.encodeComponent('LOGIN $code');
    final url = Uri.parse('https://wa.me/${AppConfig.businessWaNumber}?text=$msg');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _showReverseOtpSheet(String title, String code, String targetPhone) {
    _sheetOpen = true;
    final cardBg = _darkTheme ? const Color(0xFF1B2436) : Colors.white;
    final txtColor = _darkTheme ? Colors.white : const Color(0xFF141B29);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: txtColor)),
            const SizedBox(height: 6),
            Text(
              'Kirim kode di bawah KHUSUS dari nomor WA $targetPhone. Jika dikirim dari nomor lain, sistem tidak akan memproses.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _darkTheme ? Colors.grey[400] : Colors.grey[700]),
            ),
            const SizedBox(height: 14),
            ScaleTransition(
              scale: Tween(begin: 0.97, end: 1.03).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B9E4B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1B9E4B), width: 1.5),
                ),
                child: Text(
                  'LOGIN $code',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF1B9E4B)),
                ),
              ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: _mismatchNotifier,
              builder: (_, warn, __) {
                if (warn == null) return const SizedBox(height: 12);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: Text(warn, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 12.5, fontWeight: FontWeight.w600)),
                );
              },
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B9E4B)),
                onPressed: () => _launchWa(code),
                icon: const Icon(Icons.chat),
                label: const Text('Buka WhatsApp Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'LOGIN $code'));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teks LOGIN disalin!')));
                  },
                  icon: const Icon(Icons.copy, size: 17),
                  label: const Text('Salin Teks'),
                ),
                TextButton(
                  onPressed: () {
                    widget.ctrl.cancelOtpWait();
                    setState(() => _waWaiting = false);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Batalkan', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(() => _sheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final bg = _darkTheme ? const Color(0xFF111827) : const Color(0xFFF6F8FC);
    final card = _darkTheme ? const Color(0xFF1B2436) : Colors.white;
    final textCol = _darkTheme ? Colors.white : const Color(0xFF141B29);
    final mutedCol = _darkTheme ? Colors.grey[400]! : Colors.grey[600]!;
    final primary = _darkTheme ? const Color(0xFFF59E0B) : const Color(0xFF0D47A1);
    final primary2 = _darkTheme ? const Color(0xFFD97706) : const Color(0xFF1976D2);
    final onPrimary = _darkTheme ? const Color(0xFF111827) : Colors.white;

    final titles = ['Selamat Datang!', 'Daftar 2S Member', 'Reset Password'];
    final subtitles = [
      'Masuk pakai No. WhatsApp atau Gmail terdaftar Anda.',
      'Masukkan No. WA Anda & verifikasi otomatis tanpa SMS.',
      'Masukkan No. WA terdaftar untuk membuat password baru.',
    ];
    final badges = ['2S SERVICE HP', '+150 POIN BARU', 'KEAMANAN AKUN'];

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, primary2], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back_ios_new, color: onPrimary, size: 20),
                      style: IconButton.styleFrom(backgroundColor: onPrimary.withValues(alpha: 0.14)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
                      child: Text(badges[_modeIndex], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black87)),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Ganti Tema',
                      onPressed: () => setState(() => _darkTheme = !_darkTheme),
                      icon: Icon(_darkTheme ? Icons.light_mode : Icons.dark_mode, color: onPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Column(
                    key: ValueKey(_modeIndex),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titles[_modeIndex], style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: onPrimary)),
                      const SizedBox(height: 4),
                      Text(subtitles[_modeIndex], style: TextStyle(fontSize: 13, color: onPrimary.withValues(alpha: 0.88))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: RepaintBoundary(
                    child: Column(
                      children: [
                        if (_errorMsg != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                            ),
                            child: Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                          ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) {
                            final forward = _modeIndex >= _prevModeIndex;
                            final offset = Tween<Offset>(begin: Offset(forward ? 0.12 : -0.12, 0), end: Offset.zero).animate(anim);
                            return FadeTransition(opacity: anim, child: SlideTransition(position: offset, child: child));
                          },
                          child: Container(
                            key: ValueKey(_modeIndex),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: _darkTheme ? Colors.white12 : Colors.black.withValues(alpha: 0.06)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 8))],
                            ),
                            child: _modeIndex == 0
                                ? _buildLoginCard(textCol, mutedCol, primary, onPrimary)
                                : (_modeIndex == 1
                                    ? _buildRegisterCard(textCol, mutedCol)
                                    : _buildResetCard(textCol, mutedCol)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildFooterLinks(mutedCol, primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(Color textCol, Color mutedCol, Color primary, Color onPrimary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pilihan Metode Masuk: No. WA atau Gmail
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _darkTheme ? const Color(0xFF131B2B) : const Color(0xFFF1F5FB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _loginWithGmail = false;
                    _errorMsg = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_loginWithGmail ? primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      'No. WhatsApp',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: !_loginWithGmail ? onPrimary : mutedCol),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _loginWithGmail = true;
                    _errorMsg = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _loginWithGmail ? primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      'Gmail',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _loginWithGmail ? onPrimary : mutedCol),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _loginWithGmail
              ? _field(_loginGmailC, 'Alamat Gmail Terverifikasi', Icons.email_outlined, textCol, mutedCol, key: const ValueKey('gm'), type: TextInputType.emailAddress)
              : _field(_loginPhoneC, 'Nomor WhatsApp (08... / 628...)', Icons.phone_android, textCol, mutedCol, key: const ValueKey('wa'), type: TextInputType.phone),
        ),
        const SizedBox(height: 12),
        _passField(_loginPassC, _loginWithGmail ? 'Password Email' : 'Password Akun', _hideLoginPass, () => setState(() => _hideLoginPass = !_hideLoginPass), textCol, mutedCol),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _switchMode(2),
            child: Text('Lupa Password? Reset via WA', style: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
        _ScaleButton(
          onTap: _loginBusy ? null : _doLogin,
          color: primary,
          textColor: onPrimary,
          label: _loginBusy ? 'Memeriksa...' : (_loginWithGmail ? 'Masuk dengan Gmail' : 'Masuk Sekarang'),
          icon: _loginWithGmail ? Icons.mail : Icons.login,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: textCol, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Lanjut sebagai Tamu'),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterCard(Color textCol, Color mutedCol) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(_regPhoneC, 'Nomor WhatsApp (08... / 628...)', Icons.phone_android, textCol, mutedCol, type: TextInputType.phone),
        const SizedBox(height: 12),
        _field(_regNameC, 'Nama Lengkap', Icons.person, textCol, mutedCol),
        const SizedBox(height: 12),
        _passField(_regPassC, 'Buat Password (min. 6 huruf)', _hideRegPass1, () => setState(() => _hideRegPass1 = !_hideRegPass1), textCol, mutedCol),
        const SizedBox(height: 12),
        _passField(_regPass2C, 'Ulangi Password', _hideRegPass2, () => setState(() => _hideRegPass2 = !_hideRegPass2), textCol, mutedCol),
        const SizedBox(height: 12),
        _field(_regRefC, 'Kode Referral Teman (Opsional)', Icons.card_giftcard, textCol, mutedCol),
        const SizedBox(height: 18),
        _ScaleButton(
          onTap: () => _startWaOtp(mode: 'register'),
          color: const Color(0xFF1B9E4B),
          textColor: Colors.white,
          label: _waWaiting ? 'Menunggu Verifikasi WA...' : 'Daftar & Verifikasi WhatsApp',
          icon: Icons.chat,
        ),
        if (_waWaiting && _waCode != null && _expectedPhone != null)
          TextButton(
            onPressed: () => _showReverseOtpSheet('Verifikasi Daftar Akun', _waCode!, _expectedPhone!),
            child: const Text('Buka Lagi Jendela Kode WA'),
          ),
      ],
    );
  }

  Widget _buildResetCard(Color textCol, Color mutedCol) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(_resetPhoneC, 'Nomor WhatsApp Terdaftar (08...)', Icons.phone_android, textCol, mutedCol, type: TextInputType.phone),
        const SizedBox(height: 12),
        _passField(_resetPassC, 'Password Baru (min. 6 huruf)', _hideResPass1, () => setState(() => _hideResPass1 = !_hideResPass1), textCol, mutedCol),
        const SizedBox(height: 12),
        _passField(_resetPass2C, 'Ulangi Password Baru', _hideResPass2, () => setState(() => _hideResPass2 = !_hideResPass2), textCol, mutedCol),
        const SizedBox(height: 18),
        _ScaleButton(
          onTap: () => _startWaOtp(mode: 'reset'),
          color: const Color(0xFF1B9E4B),
          textColor: Colors.white,
          label: _waWaiting ? 'Menunggu Verifikasi WA...' : 'Verifikasi Pemilik WA & Simpan',
          icon: Icons.verified_user,
        ),
        if (_waWaiting && _waCode != null && _expectedPhone != null)
          TextButton(
            onPressed: () => _showReverseOtpSheet('Verifikasi Reset Password', _waCode!, _expectedPhone!),
            child: const Text('Buka Lagi Jendela Kode WA'),
          ),
      ],
    );
  }

  Widget _buildFooterLinks(Color mutedCol, Color primary) {
    if (_modeIndex == 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Belum punya akun? ', style: TextStyle(color: mutedCol)),
          GestureDetector(
            onTap: () => _switchMode(1),
            child: Text('Daftar Sekarang', style: TextStyle(color: primary, fontWeight: FontWeight.w800)),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Sudah punya akun? ', style: TextStyle(color: mutedCol)),
        GestureDetector(
          onTap: () => _switchMode(0),
          child: Text('Masuk di sini', style: TextStyle(color: primary, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, Color textCol, Color mutedCol, {Key? key, TextInputType? type}) {
    return TextField(
      key: key,
      controller: c,
      keyboardType: type,
      style: TextStyle(color: textCol),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: mutedCol, fontSize: 13),
        prefixIcon: Icon(icon, color: mutedCol),
        filled: true,
        fillColor: _darkTheme ? const Color(0xFF131B2B) : const Color(0xFFF1F5FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _darkTheme ? Colors.amber : const Color(0xFF0D47A1), width: 1.5)),
      ),
    );
  }

  Widget _passField(TextEditingController c, String label, bool obscure, VoidCallback toggle, Color textCol, Color mutedCol) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: TextStyle(color: textCol),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: mutedCol, fontSize: 13),
        prefixIcon: Icon(Icons.lock_outline, color: mutedCol),
        suffixIcon: IconButton(
          onPressed: toggle,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(obscure ? Icons.visibility_off : Icons.visibility, key: ValueKey(obscure), color: mutedCol),
          ),
        ),
        filled: true,
        fillColor: _darkTheme ? const Color(0xFF131B2B) : const Color(0xFFF1F5FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _darkTheme ? Colors.amber : const Color(0xFF0D47A1), width: 1.5)),
      ),
    );
  }
}

class _ScaleButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  final String label;
  final IconData icon;

  const _ScaleButton({
    required this.onTap,
    required this.color,
    required this.textColor,
    required this.label,
    required this.icon,
  });

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _down = false);
              widget.onTap?.call();
            },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: widget.onTap == null ? widget.color.withValues(alpha: 0.6) : widget.color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.textColor, size: 20),
              const SizedBox(width: 8),
              Text(widget.label, style: TextStyle(color: widget.textColor, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

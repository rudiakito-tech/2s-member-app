import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_config.dart';
import 'cloudinary_service.dart';
import 'data_store.dart';
import 'jp_theme_widgets.dart';

enum AuthStep { login, register, verifyRegOtp, forgotPassword, verifyResetOtp, newPassword, resetSuccess }

class AuthPage extends StatefulWidget {
  final AppDataController ctrl;
  final int initialTab;
  final VoidCallback? onSkipToDashboard;

  const AuthPage({super.key, required this.ctrl, this.initialTab = 0, this.onSkipToDashboard});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late AuthStep _step;
  AuthStep _prevStep = AuthStep.login;

  final _loginIdC = TextEditingController();
  final _loginPassC = TextEditingController();
  final _regNameC = TextEditingController();
  final _regPhoneC = TextEditingController();
  final _regPassC = TextEditingController();
  final _regPass2C = TextEditingController();
  final _regRefC = TextEditingController();
  final _forgotPhoneC = TextEditingController();
  final _newPassC = TextEditingController();
  final _newPass2C = TextEditingController();

  bool _rememberMe = true, _agreeTerms = true, _uploadingPhoto = false;
  bool _hideLogin = true, _hideReg1 = true, _hideReg2 = true, _hideNew1 = true, _hideNew2 = true;
  bool _busy = false, _googleBusy = false;
  String? _errorMsg, _otpCode, _expectedPhone, _mismatchWarning;

  Timer? _timer;
  int _otpSecondsLeft = 179;
  int _resendCooldown = 56;

  @override
  void initState() {
    super.initState();
    _step = widget.initialTab == 1
        ? AuthStep.register
        : (widget.initialTab == 2 ? AuthStep.forgotPassword : AuthStep.login);
    _prevStep = _step;
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_loginIdC, _loginPassC, _regNameC, _regPhoneC, _regPassC, _regPass2C, _regRefC, _forgotPhoneC, _newPassC, _newPass2C]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(AuthStep next) {
    if (next == _step) return;
    setState(() {
      _prevStep = _step;
      _step = next;
      _errorMsg = null;
    });
  }

  void _finishAuthToDashboard() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      widget.onSkipToDashboard?.call();
    }
  }

  void _startOtpCountdown() {
    _timer?.cancel();
    setState(() {
      _otpSecondsLeft = 179;
      _resendCooldown = 56;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_otpSecondsLeft > 0) _otpSecondsLeft--;
        if (_resendCooldown > 0) _resendCooldown--;
      });
      if (_otpSecondsLeft == 0) t.cancel();
    });
  }

  String _formatClock(int sec) => '00:${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

  Future<void> _doLogin() async {
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    final err = await widget.ctrl.loginWithPassword(_loginIdC.text, _loginPassC.text, rememberMe: _rememberMe);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _errorMsg = err);
    } else {
      _finishAuthToDashboard();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil masuk ke 2S Member!')));
    }
  }

  Future<void> _doGoogleLogin() async {
    setState(() {
      _googleBusy = true;
      _errorMsg = null;
    });
    final res = await widget.ctrl.signInWithGoogleButton();
    if (!mounted) return;
    setState(() => _googleBusy = false);
    if (res.error != null) return setState(() => _errorMsg = res.error);
    if (res.loggedIn) {
      _finishAuthToDashboard();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil login Google (${res.email})!')));
      return;
    }
    if (res.needsWaRegistration) {
      if (_regNameC.text.isEmpty && (res.name ?? '').isNotEmpty) _regNameC.text = res.name!;
      _go(AuthStep.register);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google (${res.email}) terverifikasi! Lengkapi No. WA untuk daftar.')));
    }
  }

  Future<void> _pickRegisterPhoto() async {
    setState(() => _uploadingPhoto = true);
    final res = await CloudinaryService.pickAndUpload(context, folder: '2s_member/profiles');
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    if (res == null) return;
    if (res.url != null) {
      setState(() => widget.ctrl.pendingRegisterPhotoUrl = res.url);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profil diupload ke Cloudinary!')));
    } else if (res.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.error!)));
    }
  }

  Future<void> _startRegisterOtp() async {
    if (_regNameC.text.trim().isEmpty) return setState(() => _errorMsg = 'Nama lengkap wajib diisi.');
    if (_regPhoneC.text.trim().length < 9) return setState(() => _errorMsg = 'Nomor WhatsApp wajib diisi (08... / 628...).');
    if (_regPassC.text.length < 6) return setState(() => _errorMsg = 'Password minimal 6 karakter.');
    if (_regPassC.text != _regPass2C.text) return setState(() => _errorMsg = 'Konfirmasi password tidak sama.');
    if (!_agreeTerms) return setState(() => _errorMsg = 'Centang persetujuan Syarat & Ketentuan terlebih dahulu.');

    setState(() {
      _busy = true;
      _errorMsg = null;
      _mismatchWarning = null;
    });
    final res = await widget.ctrl.startReverseOtp(
      mode: 'register',
      rawPhone: _regPhoneC.text,
      name: _regNameC.text,
      password: _regPassC.text,
      refCode: _regRefC.text,
      onMismatch: (w) {
        if (mounted) setState(() => _mismatchWarning = '⚠️ Pengirim $w beda dengan nomor $_expectedPhone! Tetap menunggu dari nomor terdaftar.');
      },
      onCompleted: (err) {
        if (!mounted) return;
        _timer?.cancel();
        if (err != null) {
          setState(() => _errorMsg = err);
        } else {
          _finishAuthToDashboard();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pendaftaran & Verifikasi WA berhasil!')));
        }
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.error != null) return setState(() => _errorMsg = res.error);
    setState(() {
      _otpCode = res.code;
      _expectedPhone = res.expectedPhone;
    });
    _startOtpCountdown();
    _go(AuthStep.verifyRegOtp);
  }

  Future<void> _startResetOtp() async {
    if (_forgotPhoneC.text.trim().length < 9) return setState(() => _errorMsg = 'Masukkan Nomor WhatsApp terdaftar (08...).');
    setState(() {
      _busy = true;
      _errorMsg = null;
      _mismatchWarning = null;
    });
    final res = await widget.ctrl.startReverseOtp(
      mode: 'reset',
      rawPhone: _forgotPhoneC.text,
      onMismatch: (w) {
        if (mounted) setState(() => _mismatchWarning = '⚠️ Pengirim $w beda dengan nomor $_expectedPhone! Tetap menunggu dari nomor terdaftar.');
      },
      onCompleted: (err) {
        if (!mounted) return;
        _timer?.cancel();
        if (err != null) {
          setState(() => _errorMsg = err);
        } else {
          _go(AuthStep.newPassword);
        }
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.error != null) return setState(() => _errorMsg = res.error);
    setState(() {
      _otpCode = res.code;
      _expectedPhone = res.expectedPhone;
    });
    _startOtpCountdown();
    _go(AuthStep.verifyResetOtp);
  }

  Future<void> _saveNewPassword() async {
    final p1 = _newPassC.text;
    final okAlpha = RegExp(r'[A-Za-z]').hasMatch(p1) && RegExp(r'\d').hasMatch(p1);
    if (p1.length < 8 || !okAlpha) return setState(() => _errorMsg = 'Password wajib min. 8 karakter + huruf & angka.');
    if (p1 != _newPass2C.text) return setState(() => _errorMsg = 'Konfirmasi password tidak sama.');

    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    final err = await widget.ctrl.saveNewPasswordAfterReset(p1);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _errorMsg = err);
    } else {
      _newPassC.clear();
      _newPass2C.clear();
      _go(AuthStep.resetSuccess);
    }
  }

  Future<void> _launchWa() async {
    if (_otpCode == null) return;
    final text = widget.ctrl.buildWaOtpMessage(_otpCode!);
    final url = Uri.parse('https://wa.me/${AppConfig.businessWaNumber}?text=${Uri.encodeComponent(text)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final showTopFuji = _step == AuthStep.login || _step == AuthStep.verifyResetOtp;
    return Scaffold(
      body: JpBackdrop(
        topFuji: showTopFuji,
        bottomFuji: true,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) {
              final offset = Tween<Offset>(begin: Offset(_step.index >= _prevStep.index ? 0.08 : -0.08, 0), end: Offset.zero).animate(anim);
              return FadeTransition(opacity: anim, child: SlideTransition(position: offset, child: child));
            },
            child: SingleChildScrollView(
              key: ValueKey(_step),
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
              child: _buildStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case AuthStep.login:
        return _loginView();
      case AuthStep.register:
        return _registerView();
      case AuthStep.verifyRegOtp:
        return _otpView(isReset: false);
      case AuthStep.forgotPassword:
        return _forgotView();
      case AuthStep.verifyResetOtp:
        return _otpView(isReset: true);
      case AuthStep.newPassword:
        return _newPassView();
      case AuthStep.resetSuccess:
        return _successView();
    }
  }

  Widget _topNav({VoidCallback? onBack, Widget? right}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          onBack != null ? IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new, color: JpColors.navy, size: 20)) : const SizedBox(width: 40),
          right ?? const SizedBox(width: 40),
        ],
      );

  Widget _errBox() => _errorMsg == null
      ? const SizedBox.shrink()
      : Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.45))),
          child: Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12.5, fontWeight: FontWeight.w700)),
        );

  Widget _eye(bool hide, VoidCallback tap) => IconButton(
        onPressed: tap,
        icon: Icon(hide ? Icons.visibility_off : Icons.visibility, color: JpColors.navyMuted, size: 20),
      );

  Widget _loginView() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topNav(
            right: InkWell(
              onTap: _finishAuthToDashboard,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(20), border: Border.all(color: JpColors.inputBorder)),
                child: const Text('Lewati >', style: TextStyle(color: JpColors.navy, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: TwoSMemberLogo()),
          const SizedBox(height: 12),
          const Text('Login', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: JpColors.navy)),
          const Text('Masuk ke akun 2S Member Anda', textAlign: TextAlign.center, style: TextStyle(color: JpColors.navyMuted, fontSize: 13.5)),
          const SizedBox(height: 18),
          _errBox(),
          JpInputField(controller: _loginIdC, hint: 'Email / No. HP', icon: Icons.mail_outline),
          const SizedBox(height: 12),
          JpInputField(controller: _loginPassC, hint: 'Password', icon: Icons.lock_outline, obscure: _hideLogin, suffix: _eye(_hideLogin, () => setState(() => _hideLogin = !_hideLogin))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Checkbox(value: _rememberMe, activeColor: JpColors.orange, onChanged: (v) => setState(() => _rememberMe = v ?? true)),
                const Text('Ingat Saya', style: TextStyle(color: JpColors.navy, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              TextButton(onPressed: () => _go(AuthStep.forgotPassword), child: const Text('Lupa Password?', style: TextStyle(color: Color(0xFF1E56A0), fontWeight: FontWeight.w700, fontSize: 13))),
            ],
          ),
          const SizedBox(height: 8),
          JpOrangeButton(label: 'Login', icon: Icons.login, loading: _busy, onTap: _doLogin),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('atau', style: TextStyle(color: JpColors.navyMuted, fontSize: 12))), Expanded(child: Divider())]),
          ),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.94), side: const BorderSide(color: JpColors.inputBorder, width: 1.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
              onPressed: _googleBusy ? null : _doGoogleLogin,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _googleBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFDB4437))),
                  const SizedBox(width: 10),
                  Text(_googleBusy ? 'Menghubungkan Google...' : 'Login dengan Google', style: const TextStyle(color: JpColors.navy, fontWeight: FontWeight.w700, fontSize: 14.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Belum punya akun? ', style: TextStyle(color: JpColors.navyMuted, fontSize: 13)),
            GestureDetector(onTap: () => _go(AuthStep.register), child: const Text('Daftar Sekarang', style: TextStyle(color: Color(0xFF1E56A0), fontWeight: FontWeight.w800, fontSize: 13))),
          ]),
          const SizedBox(height: 80),
        ],
      );

  Widget _registerView() {
    final gEmail = widget.ctrl.pendingGoogleEmail;
    final photoUrl = widget.ctrl.pendingRegisterPhotoUrl ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topNav(onBack: () => _go(AuthStep.login), right: const TwoSMemberLogo(scale: 0.72)),
        const Text('Daftar Akun', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: JpColors.navy)),
        const Text('Bergabunglah dengan 2S Member untuk nikmati berbagai keuntungan!', textAlign: TextAlign.center, style: TextStyle(color: JpColors.navyMuted, fontSize: 13)),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _uploadingPhoto ? null : _pickRegisterPhoto,
            child: Column(children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: _uploadingPhoto ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : (photoUrl.isEmpty ? const Icon(Icons.camera_alt, color: JpColors.navy, size: 28) : null),
              ),
              const SizedBox(height: 4),
              Text(_uploadingPhoto ? 'Mengupload...' : (photoUrl.isEmpty ? 'Upload Foto (Opsional)' : 'Ganti Foto'), style: const TextStyle(fontSize: 11, color: JpColors.navyMuted)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        if (gEmail != null && gEmail.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text('✅ Google terhubung: $gEmail (+50 Poin ekstra)', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        _errBox(),
        JpInputField(controller: _regNameC, hint: 'Nama Lengkap', icon: Icons.person_outline),
        const SizedBox(height: 10),
        JpInputField(controller: _regPhoneC, hint: 'No. HP WhatsApp (08...)', icon: Icons.phone_android, keyboardType: TextInputType.phone),
        const SizedBox(height: 10),
        JpInputField(controller: _regPassC, hint: 'Password', icon: Icons.lock_outline, obscure: _hideReg1, suffix: _eye(_hideReg1, () => setState(() => _hideReg1 = !_hideReg1))),
        const SizedBox(height: 10),
        JpInputField(controller: _regPass2C, hint: 'Konfirmasi Password', icon: Icons.lock_outline, obscure: _hideReg2, suffix: _eye(_hideReg2, () => setState(() => _hideReg2 = !_hideReg2))),
        const SizedBox(height: 10),
        JpInputField(controller: _regRefC, hint: 'Kode Referral (Opsional)', icon: Icons.card_giftcard),
        Row(children: [
          Checkbox(value: _agreeTerms, activeColor: JpColors.orange, onChanged: (v) => setState(() => _agreeTerms = v ?? true)),
          const Expanded(child: Text('Saya setuju dengan Syarat & Ketentuan dan Kebijakan Privasi', style: TextStyle(fontSize: 12, color: JpColors.navy))),
        ]),
        const SizedBox(height: 8),
        JpOrangeButton(label: 'Daftar Sekarang', loading: _busy, onTap: _startRegisterOtp),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Sudah punya akun? ', style: TextStyle(color: JpColors.navyMuted, fontSize: 13)),
          GestureDetector(onTap: () => _go(AuthStep.login), child: const Text('Login', style: TextStyle(color: Color(0xFF1E56A0), fontWeight: FontWeight.w800, fontSize: 13))),
        ]),
        const SizedBox(height: 70),
      ],
    );
  }

  Widget _otpView({required bool isReset}) {
    final code = _otpCode ?? '000000';
    final chars = code.padRight(6, '0').split('').take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topNav(onBack: () {
          _timer?.cancel();
          widget.ctrl.cancelOtpWait();
          _go(isReset ? AuthStep.forgotPassword : AuthStep.register);
        }),
        SizedBox(height: isReset ? 72 : 12),
        Text(isReset ? 'Reset Password' : 'Konfirmasi Nomor WA', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: JpColors.navy)),
        const SizedBox(height: 6),
        Text(
          'Kirim pesan konfirmasi berisi kode verifikasi di bawah melalui WhatsApp dari nomor ${_expectedPhone ?? ''} ke 2S Member:',
          textAlign: TextAlign.center,
          style: const TextStyle(color: JpColors.navyMuted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: chars
              .map((ch) => Container(
                    width: 46,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: JpColors.inputBorder, width: 1.5)),
                    child: Text(ch, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: JpColors.navy)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(14), border: Border.all(color: JpColors.inputBorder)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.timer_outlined, color: JpColors.navy, size: 22),
            const SizedBox(width: 8),
            Text('Menunggu konfirmasi WA: ${_formatClock(_otpSecondsLeft)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: JpColors.navy)),
          ]),
        ),
        if (_mismatchWarning != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(_mismatchWarning!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        TextButton(
          onPressed: _resendCooldown > 0 ? null : () => isReset ? _startResetOtp() : _startRegisterOtp(),
          child: Text(_resendCooldown > 0 ? 'Buat Ulang Kode (${_resendCooldown}s)' : 'Buat Ulang Kode Baru', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        JpOrangeButton(label: 'Buka WhatsApp & Kirim', icon: Icons.chat, onTap: _launchWa),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.ctrl.buildWaOtpMessage(code)));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesan konfirmasi disalin!')));
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Salin Pesan Konfirmasi'),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _forgotView() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topNav(onBack: () => _go(AuthStep.login)),
          const SizedBox(height: 16),
          const Center(child: Icon(Icons.lock_reset, size: 60, color: Color(0xFF1E56A0))),
          const SizedBox(height: 12),
          const Text('Lupa Password?', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: JpColors.navy)),
          const Text('Masukkan nomor WhatsApp terdaftar Anda untuk konfirmasi kepemilikan nomor', textAlign: TextAlign.center, style: TextStyle(color: JpColors.navyMuted, fontSize: 13)),
          const SizedBox(height: 20),
          _errBox(),
          JpInputField(controller: _forgotPhoneC, hint: 'No. HP WhatsApp (08...)', icon: Icons.phone_android, keyboardType: TextInputType.phone),
          const SizedBox(height: 18),
          JpOrangeButton(label: 'Kirim Verifikasi WA', loading: _busy, onTap: _startResetOtp),
          const SizedBox(height: 120),
        ],
      );

  Widget _newPassView() {
    final p = _newPassC.text;
    final okLen = p.length >= 8;
    final okAlpha = RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p);
    final okMatch = p.isNotEmpty && p == _newPass2C.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topNav(onBack: () => _go(AuthStep.forgotPassword)),
        const SizedBox(height: 12),
        const Text('Buat Password Baru', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: JpColors.navy)),
        const SizedBox(height: 16),
        _errBox(),
        JpInputField(controller: _newPassC, hint: 'Password Baru', icon: Icons.lock_outline, obscure: _hideNew1, onChanged: (_) => setState(() {}), suffix: _eye(_hideNew1, () => setState(() => _hideNew1 = !_hideNew1))),
        const SizedBox(height: 10),
        JpInputField(controller: _newPass2C, hint: 'Konfirmasi Password', icon: Icons.lock_outline, obscure: _hideNew2, onChanged: (_) => setState(() {}), suffix: _eye(_hideNew2, () => setState(() => _hideNew2 = !_hideNew2))),
        const SizedBox(height: 14),
        _rule('Minimal 8 karakter', okLen),
        _rule('Mengandung huruf dan angka', okAlpha),
        _rule('Konfirmasi cocok & beda dari password lama', okMatch),
        const SizedBox(height: 18),
        JpOrangeButton(label: 'Simpan Password', loading: _busy, onTap: _saveNewPassword),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _rule(String text, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 17, color: ok ? Colors.green : JpColors.navyMuted),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12.5, color: ok ? Colors.green[800] : JpColors.navyMuted, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _successView() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 36),
          const Center(child: CircleAvatar(radius: 42, backgroundColor: Color(0xFF2E9E49), child: Icon(Icons.check, size: 50, color: Colors.white))),
          const SizedBox(height: 20),
          const Text('Password Berhasil Diubah!', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: JpColors.navy)),
          const Text('Password akun Anda telah berhasil diperbarui.', textAlign: TextAlign.center, style: TextStyle(color: JpColors.navyMuted, fontSize: 13.5)),
          const SizedBox(height: 24),
          JpOrangeButton(label: 'Login Sekarang', onTap: () => _go(AuthStep.login)),
          const SizedBox(height: 32),
          const JpMascotBadge(bubbleText: 'Selamat Bergabung Kembali!'),
          const SizedBox(height: 90),
        ],
      );
}
// AKHIR FILE auth_page.dart

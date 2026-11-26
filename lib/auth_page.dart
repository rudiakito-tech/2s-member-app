import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_config.dart';
import 'data_store.dart';
import 'jp_theme_widgets.dart';

enum AuthStep {
  login,
  register,
  verifyRegOtp,
  forgotPassword,
  verifyResetOtp,
  newPassword,
  resetSuccess,
}

class AuthPage extends StatefulWidget {
  final AppDataController ctrl;
  final int initialTab; // 0: Login, 1: Register, 2: Forgot Password
  final VoidCallback? onSkipToDashboard;

  const AuthPage({
    super.key,
    required this.ctrl,
    this.initialTab = 0,
    this.onSkipToDashboard,
  });

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

  bool _rememberMe = true;
  bool _agreeTerms = true;
  bool _hasMockPhoto = false;
  bool _hideLoginPass = true;
  bool _hideRegPass1 = true;
  bool _hideRegPass2 = true;
  bool _hideNewPass1 = true;
  bool _hideNewPass2 = true;

  bool _busy = false;
  bool _googleBusy = false;
  String? _errorMsg;
  String? _otpCode;
  String? _expectedPhone;
  String? _mismatchWarning;

  Timer? _timer;
  int _otpSecondsLeft = 179;
  int _resendCooldown = 56;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab == 1) {
      _step = AuthStep.register;
    } else if (widget.initialTab == 2) {
      _step = AuthStep.forgotPassword;
    } else {
      _step = AuthStep.login;
    }
    _prevStep = _step;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loginIdC.dispose();
    _loginPassC.dispose();
    _regNameC.dispose();
    _regPhoneC.dispose();
    _regPassC.dispose();
    _regPass2C.dispose();
    _regRefC.dispose();
    _forgotPhoneC.dispose();
    _newPassC.dispose();
    _newPass2C.dispose();
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

  String _formatClock(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '00:$m:$s';
  }

  Future<void> _doLogin() async {
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    final err = await widget.ctrl.loginWithPassword(
      _loginIdC.text,
      _loginPassC.text,
      rememberMe: _rememberMe,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _errorMsg = err);
    } else {
      _finishAuthToDashboard();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil masuk ke 2S Member!')),
      );
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

    if (res.error != null) {
      setState(() => _errorMsg = res.error);
      return;
    }
    if (res.loggedIn) {
      _finishAuthToDashboard();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil login Google (${res.email})!')),
      );
      return;
    }
    if (res.needsWaRegistration) {
      if (_regNameC.text.isEmpty && (res.name ?? '').isNotEmpty) {
        _regNameC.text = res.name!;
      }
      _go(AuthStep.register);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google (${res.email}) terverifikasi! Lengkapi No. WA untuk daftar.')),
      );
    }
  }

  Future<void> _startRegisterOtp() async {
    if (_regNameC.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Nama lengkap wajib diisi.');
      return;
    }
    if (_regPhoneC.text.trim().length < 9) {
      setState(() => _errorMsg = 'Nomor WhatsApp wajib diisi dengan benar (08... / 628...).');
      return;
    }
    if (_regPassC.text.length < 6) {
      setState(() => _errorMsg = 'Password minimal 6 karakter.');
      return;
    }
    if (_regPassC.text != _regPass2C.text) {
      setState(() => _errorMsg = 'Konfirmasi password tidak sama.');
      return;
    }
    if (!_agreeTerms) {
      setState(() => _errorMsg = 'Centang persetujuan Syarat & Ketentuan terlebih dahulu.');
      return;
    }

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
      onMismatch: (wrongPhone) {
        if (!mounted) return;
        setState(() {
          _mismatchWarning = '⚠️ Pesan masuk dari $wrongPhone berbeda dengan nomor $_expectedPhone! Tetap menunggu dari nomor terdaftar.';
        });
      },
      onCompleted: (err) {
        if (!mounted) return;
        _timer?.cancel();
        if (err != null) {
          setState(() => _errorMsg = err);
        } else {
          _finishAuthToDashboard();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pendaftaran & Verifikasi WhatsApp berhasil!')),
          );
        }
      },
    );

    if (!mounted) return;
    setState(() => _busy = false);
    if (res.error != null) {
      setState(() => _errorMsg = res.error);
      return;
    }

    setState(() {
      _otpCode = res.code;
      _expectedPhone = res.expectedPhone;
    });
    _startOtpCountdown();
    _go(AuthStep.verifyRegOtp);
  }

  Future<void> _startResetOtp() async {
    if (_forgotPhoneC.text.trim().length < 9) {
      setState(() => _errorMsg = 'Masukkan Nomor WhatsApp yang terdaftar (08... / 628...).');
      return;
    }

    setState(() {
      _busy = true;
      _errorMsg = null;
      _mismatchWarning = null;
    });

    final res = await widget.ctrl.startReverseOtp(
      mode: 'reset',
      rawPhone: _forgotPhoneC.text,
      onMismatch: (wrongPhone) {
        if (!mounted) return;
        setState(() {
          _mismatchWarning = '⚠️ Pesan masuk dari $wrongPhone berbeda dengan nomor $_expectedPhone! Tetap menunggu dari nomor terdaftar.';
        });
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
    if (res.error != null) {
      setState(() => _errorMsg = res.error);
      return;
    }

    setState(() {
      _otpCode = res.code;
      _expectedPhone = res.expectedPhone;
    });
    _startOtpCountdown();
    _go(AuthStep.verifyResetOtp);
  }

  Future<void> _saveNewPassword() async {
    final p1 = _newPassC.text;
    final p2 = _newPass2C.text;
    final hasLen = p1.length >= 8;
    final hasLetterNum = RegExp(r'[A-Za-z]').hasMatch(p1) && RegExp(r'\d').hasMatch(p1);

    if (!hasLen || !hasLetterNum) {
      setState(() => _errorMsg = 'Password wajib minimal 8 karakter dan mengandung huruf serta angka.');
      return;
    }
    if (p1 != p2) {
      setState(() => _errorMsg = 'Konfirmasi password tidak sama.');
      return;
    }

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
    final msg = Uri.encodeComponent('LOGIN $_otpCode');
    final url = Uri.parse('https://wa.me/${AppConfig.businessWaNumber}?text=$msg');
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
              final forward = _step.index >= _prevStep.index;
              final offset = Tween<Offset>(begin: Offset(forward ? 0.08 : -0.08, 0), end: Offset.zero).animate(anim);
              return FadeTransition(opacity: anim, child: SlideTransition(position: offset, child: child));
            },
            child: SingleChildScrollView(
              key: ValueKey(_step),
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
              child: _buildCurrentStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case AuthStep.login:
        return _buildLoginScreen();
      case AuthStep.register:
        return _buildRegisterScreen();
      case AuthStep.verifyRegOtp:
        return _buildReverseOtpScreen(isReset: false);
      case AuthStep.forgotPassword:
        return _buildForgotScreen();
      case AuthStep.verifyResetOtp:
        return _buildReverseOtpScreen(isReset: true);
      case AuthStep.newPassword:
        return _buildNewPasswordScreen();
      case AuthStep.resetSuccess:
        return _buildSuccessScreen();
    }
  }

  Widget _topNav({VoidCallback? onBack, Widget? rightWidget}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (onBack != null)
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, color: JpColors.navy, size: 20),
          )
        else
          const SizedBox(width: 40),
        if (rightWidget != null) rightWidget else const SizedBox(width: 40),
      ],
    );
  }

  Widget _errorBanner() {
    if (_errorMsg == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.45)),
      ),
      child: Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
  }

  // 2. LAYAR LOGIN
  Widget _buildLoginScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topNav(
          rightWidget: InkWell(
            onTap: _finishAuthToDashboard,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: JpColors.inputBorder),
              ),
              child: const Text('Lewati >', style: TextStyle(color: JpColors.navy, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(child: TwoSMemberLogo()),
        const SizedBox(height: 12),
        const Text('Login', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: JpColors.navy)),
        const SizedBox(height: 4),
        const Text('Masuk ke akun 2S Member Anda', textAlign: TextAlign.center, style: TextStyle(color: JpColors.navyMuted, fontSize: 13.5)),
        const SizedBox(height: 18),
        _errorBanner(),
        JpInputField(controller: _loginIdC, hint: 'Email / No. HP', icon: Icons.mail_outline),
        const SizedBox(height: 12),
        JpInputField(
          controller: _loginPassC,
          hint: 'Password',
          icon: Icons.lock_outline,
          obscure: _hideLoginPass,
          suffix: IconButton(
            onPressed: () => setState(() => _hideLoginPass = !_hideLoginPass),
            icon: Icon(_hideLoginPass ? Icons.visibility_off : Icons.visibility, color: JpColors.navyMuted, size: 20),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  activeColor: JpColors.orange,
                  onChanged: (v) => setState(() => _rememberMe = v ?? true),
                ),
                const Text('Ingat Saya', style: TextStyle(color: JpColors.navy, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            TextButton(
              onPressed: () => _go(AuthStep.forgotPassword),
              child: const Text('Lupa Password?', style: TextStyle(color: Color(0xFF1E56A0), fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        JpOrangeButton(label: 'Login', icon: Icons.login, loading: _busy, onTap: _doLogin),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(child: Divider(color: JpColors.inputBorder)),
              Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('atau', style: TextStyle(color: JpColors.navyMuted, fontSize: 12))),
              Expanded(child: Divider(color: JpColors.inputBorder)),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.94),
              side: const BorderSide(color: JpColors.inputBorder, width: 1.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            ),
            onPressed: _googleBusy ? null : _doGoogleLogin,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_googleBusy)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFDB4437))),
                const SizedBox(width: 10),
                Text(
                  _googleBusy ? 'Menghubungkan Google...' : 'Login dengan Google',
                  style: const TextStyle(color: JpColors.navy, fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Belum punya akun? ', style: TextStyle(color: JpColors.navyMuted, fontSize: 13)),
            GestureDetector(
              onTap: () => _go(AuthStep.register),
              child: const Text('Daftar Sekarang', style: TextStyle(color: Color(0xFF1E56A0), fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  // 3. LAYAR DAFTAR AKUN
  Widget _buildRegisterScreen() {
    final gEmail = widget.ctrl.pendingGoogleEmail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topNav(onBack: () => _go(AuthStep.login), rightWidget: const TwoSMemberLogo(scale: 0.72)),
        const SizedBox(height: 4),
        const Text('Daftar Akun', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: JpColors.navy)),
        const SizedBox(height: 4),
        const Text(
          'Bergabunglah dengan 2S Member untuk nikmati berbagai keuntungan!',
          textAlign: TextAlign.center,
          style: TextStyle(color: JpColors.navyMuted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: () {
              setState(() => _hasMockPhoto = !_hasMockPhoto);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Upload foto profil opsional siap dipakai setelah terhubung Cloudinary.')),
              );
            },
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasMockPhoto ? JpColors.gold.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.85),
                    border: Border.all(color: JpColors.inputBorder, width: 1.5),
                  ),
                  child: Icon(_hasMockPhoto ? Icons.person : Icons.camera_alt, color: JpColors.navy, size: 28),
                ),
                const SizedBox(height: 4),
                const Text('Upload Foto\n(Opsional)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: JpColors.navyMuted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (gEmail != null && gEmail.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text('✅ Google terhubung: $gEmail (+50 Poin ekstra)', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        _errorBanner(),
        JpInputField(controller: _regNameC, hint: 'Nama Lengkap', icon: Icons.person_outline),
        const SizedBox(height: 10),
        JpInputField(controller: _regPhoneC, hint: 'No. HP WhatsApp (08...)', icon: Icons.phone_android, keyboardType: TextInputType.phone),
        const SizedBox(height: 10),
        JpInputField(
          controller: _regPassC,
          hint: 'Password',
          icon: Icons.lock_outline,
          obscure: _hideRegPass1,
          suffix: IconButton(
            onPressed: () => setState(() => _hideRegPass1 = !_hideRegPass1),
            icon: Icon(_hideRegPass1 ? Icons.visibility_off : Icons.visibility, color: JpColors.navyMuted, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        JpInputField(
          controller: _regPass2C,
          hint: 'Konfirmasi Password',
          icon: Icons.lock_outline,
          obscure: _hideRegPass2,
          suffix: IconButton(
            onPressed: () => setState(() => _hideRegPass2 = !_hideRegPass2),
            icon: Icon(_hideRegPass2 ? Icons.visibility_off : Icons.visibility, color: JpColors.navyMuted, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        JpInputField(controller: _regRefC, hint: 'Kode Referral (Opsional)', icon: Icons.card_giftcard),
        const SizedBox(height: 6),
        Row(
          children: [
            Checkbox(value: _agreeTerms, activeColor: JpColors.orange, onChanged: (v) => setState(() => _agreeTerms = v ?? true)),
            const Expanded(
              child: Text('Saya setuju dengan Syarat & Ketentuan dan Kebijakan Privasi', style: TextStyle(fontSize: 12, color: JpColors.navy)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        JpOrangeButton(label: 'Daftar Sekarang', loading: _busy, onTap: _startRegisterOtp),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Sudah punya akun? ', style: TextStyle(color: JpColors.navyMuted, fontSize: 13)),
            GestureDetector(
              onTap: () => _go(AuthStep.login),
              child: const Text('Login', style: TextStyle(color: Color(0xFF1E56A0), fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 70),
      ],
    );
  }

  // 4 & 6. LAYAR VERIFIKASI REVERSE OTP (DAFTAR & RESET PASSWORD)
  Widget _buildReverseOtpScreen({required bool isReset}) {
    final codeSuffix = (_otpCode ?? '2S-000000').replaceFirst('2S-', '');
    final chars = codeSuffix.padRight(6, '0').split('').take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topNav(
          onBack: () {
            _timer?.cancel();
            widget.ctrl.cancelOtpWait();
            _go(isReset ? AuthStep.forgotPassword : AuthStep.register);
          },
        ),
        if (!isReset)
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: JpColors.gold, width: 2),
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.smartphone, size: 46, color: JpColors.navy),
                  Positioned(bottom: 14, right: 14, child: Icon(Icons.verified_user, size: 24, color: Color(0xFF2E7D32))),
                ],
              ),
            ),
          )
        else
          const SizedBox(height: 76),
        const SizedBox(height: 14),
        Text(
          isReset ? 'Reset Password' : 'Verifikasi Reverse OTP',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: JpColors.navy),
        ),
        const SizedBox(height: 6),
        Text(
          'Kirim kode berikut via WhatsApp dari nomor ${_expectedPhone ?? ''}\nke 2S Member (bukan menunggu SMS):',
          textAlign: TextAlign.center,
          style: const TextStyle(color: JpColors.navyMuted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: JpColors.navy, borderRadius: BorderRadius.circular(12)),
            child: Text('Format Pesan: LOGIN $_otpCode', style: const TextStyle(color: JpColors.gold, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ),
        const SizedBox(height: 12),
        // 6 KOTAK KODE REVERSE OTP
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: chars
              .map((ch) => Container(
                    width: 46,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: JpColors.inputBorder, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 3))],
                    ),
                    child: Text(ch, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: JpColors.navy)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: JpColors.inputBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, color: JpColors.navy, size: 22),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Menunggu pesan WhatsApp Anda selama', style: TextStyle(fontSize: 11, color: JpColors.navyMuted)),
                  Text(_formatClock(_otpSecondsLeft), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: JpColors.navy)),
                ],
              ),
            ],
          ),
        ),
        if (_mismatchWarning != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(_mismatchWarning!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _resendCooldown > 0
              ? null
              : () => isReset ? _startResetOtp() : _startRegisterOtp(),
          child: Text(
            _resendCooldown > 0 ? 'Buat Ulang Kode (${_resendCooldown}s)' : 'Buat Ulang Kode Baru',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        JpOrangeButton(label: 'Buka WhatsApp & Kirim Kode', icon: Icons.chat, onTap: _launchWa),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: 'LOGIN $_otpCode'));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teks LOGIN disalin!')));
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Salin Teks LOGIN Manual'),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, size: 16, color: JpColors.navyMuted),
            SizedBox(width: 6),
            Text('Pastikan dikirim dari nomor WA yang didaftarkan', style: TextStyle(fontSize: 11.5, color: JpColors.navyMuted)),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  // 5. LAYAR LUPA PASSWORD
  Widget _buildForgotScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topNav(onBack: () => _go(AuthStep.login)),
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.9),
              border: Border.all(color: JpColors.gold, width: 2),
            ),
            child: const Icon(Icons.lock_reset, size: 46, color: Color(0xFF1E56A0)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Lupa Password?', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: JpColors.navy)),
        const SizedBox(height: 6),
        const Text(
          'Masukkan nomor WhatsApp terdaftar Anda untuk verifikasi Reverse OTP',
          textAlign: TextAlign.center,
          style: TextStyle(color: JpColors.navyMuted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        _errorBanner(),
        JpInputField(controller: _forgotPhoneC, hint: 'No. HP WhatsApp (08...)', icon: Icons.phone_android, keyboardType: TextInputType.phone),
        const SizedBox(height: 18),
        JpOrangeButton(label: 'Kirim Verifikasi WA', loading: _busy, onTap: _startResetOtp),
        const SizedBox(height: 120),
      ],
    );
  }

  // 7. LAYAR BUAT PASSWORD BARU
  Widget _buildNewPasswordScreen() {
    final p = _newPassC.text;
    final okLen = p.length >= 8;
    final okAlphaNum = RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p);
    final okMatch = p.isNotEmpty && p == _newPass2C.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topNav(onBack: () => _go(AuthStep.forgotPassword)),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.9),
              border: Border.all(color: JpColors.gold, width: 2),
            ),
            child: const Icon(Icons.lock_open, size: 42, color: JpColors.orange),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Buat Password Baru', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: JpColors.navy)),
        const SizedBox(height: 4),
        const Text('Masukkan password baru Anda', textAlign: TextAlign.center, style: TextStyle(color: JpColors.navyMuted, fontSize: 13)),
        const SizedBox(height: 18),
        _errorBanner(),
        JpInputField(
          controller: _newPassC,
          hint: 'Password Baru',
          icon: Icons.lock_outline,
          obscure: _hideNewPass1,
          onChanged: (_) => setState(() {}),
          suffix: IconButton(
            onPressed: () => setState(() => _hideNewPass1 = !_hideNewPass1),
            icon: Icon(_hideNewPass1 ? Icons.visibility_off : Icons.visibility, color: JpColors.navyMuted, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        JpInputField(
          controller: _newPass2C,
          hint: 'Konfirmasi Password',
          icon: Icons.lock_outline,
          obscure: _hideNewPass2,
          onChanged: (_) => setState(() {}),
          suffix: IconButton(
            onPressed: () => setState(() => _hideNewPass2 = !_hideNewPass2),
            icon: Icon(_hideNewPass2 ? Icons.visibility_off : Icons.visibility, color: JpColors.navyMuted, size: 20),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Password harus memenuhi:', style: TextStyle(fontWeight: FontWeight.w800, color: JpColors.navy, fontSize: 13)),
        const SizedBox(height: 6),
        _ruleRow('Minimal 8 karakter', okLen),
        _ruleRow('Mengandung huruf dan angka', okAlphaNum),
        _ruleRow('Konfirmasi cocok & beda dari password lama', okMatch),
        const SizedBox(height: 18),
        JpOrangeButton(label: 'Simpan Password', loading: _busy, onTap: _saveNewPassword),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _ruleRow(String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 17, color: ok ? Colors.green : JpColors.navyMuted),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12.5, color: ok ? Colors.green[800] : JpColors.navyMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // 8. LAYAR PASSWORD BERHASIL DIUBAH
  Widget _buildSuccessScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 36),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2E9E49)),
            child: const Icon(Icons.check, size: 52, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Password Berhasil\nDiubah!', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: JpColors.navy)),
        const SizedBox(height: 8),
        const Text('Password akun Anda telah berhasil diperbarui.', textAlign: TextAlign.center, style: TextStyle(color: JpColors.navyMuted, fontSize: 13.5)),
        const SizedBox(height: 24),
        JpOrangeButton(label: 'Login Sekarang', onTap: () => _go(AuthStep.login)),
        const SizedBox(height: 36),
        const JpMascotBadge(bubbleText: 'Selamat Bergabung Kembali!'),
        const SizedBox(height: 90),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_config.dart';
import 'cloudinary_service.dart';
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
  bool _uploadingPhoto = false;
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

  Future<void> _pickRegisterPhoto() async {
    setState(() => _uploadingPhoto = true);
    final res = await CloudinaryService.pickAndUpload(context, folder: '2s_member/profiles');
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    if (res == null) return;
    if (res.url != null) {
      setState(() => widget.ctrl.pendingRegisterPhotoUrl = res.url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diupload ke Cloudinary!')),
      );
    } else if (res.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.error!)));
    }
  }

  Future<void> _startRegisterOtp() async {
    if (_regNameC.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Nama lengkap wajib diisi.');
      return;
    }
    if (_regPhoneC.text.trim().length < 9) {
      setState(() => _errorMsg = 'Nomor WhatsApp wajib diisi de

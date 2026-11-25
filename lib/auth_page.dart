import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_config.dart';
import 'data_store.dart';

class AuthPage extends StatefulWidget {
  final AppDataController ctrl;
  final int initialTab; // 0: Masuk, 1: Daftar, 2: Lupa Password
  const AuthPage({super.key, required this.ctrl, this.initialTab = 0});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Login form
  final _loginPhoneC = TextEditingController();
  final _loginPassC = TextEditingController();
  bool _loginBusy = false;

  // Register form
  final _regNameC = TextEditingController();
  final _regPassC = TextEditingController();
  final _regPass2C = TextEditingController();
  final _regRefC = TextEditingController();

  // Reset password form
  final _resetPassC = TextEditingController();
  final _resetPass2C = TextEditingController();

  bool _waWaiting = false;
  String? _waCode;
  String? _errorMsg;

  Future<void> _doLogin() async {
    setState(() {
      _loginBusy = true;
      _errorMsg = null;
    });
    final err = await widget.ctrl.loginWithPassword(_loginPhoneC.text, _loginPassC.text);
    if (!mounted) return;
    setState(() => _loginBusy = false);
    if (err != null) {
      setState(() => _errorMsg = err);
    } else {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil masuk ke 2S Member!')),
      );
    }
  }

  Future<void> _startWaOtp({required String mode}) async {
    final pass = mode == 'register' ? _regPassC.text : _resetPassC.text;
    final pass2 = mode == 'register' ? _regPass2C.text : _resetPass2C.text;

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

    setState(() {
      _errorMsg = null;
      _waWaiting = true;
    });

    final code = await widget.ctrl.startReverseOtp(
      mode: mode,
      name: _regNameC.text,
      password: pass,
      refCode: _regRefC.text,
      onCompleted: (err) {
        if (!mounted) return;
        setState(() => _waWaiting = false);
        if (err != null) {
          setState(() => _errorMsg = err);
        } else {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mode == 'register' ? 'Pendaftaran & Verifikasi WA berhasil!' : 'Password baru berhasil disimpan!')),
          );
        }
      },
    );

    if (!mounted) return;
    setState(() => _waCode = code);

    final msg = Uri.encodeComponent('LOGIN $code');
    final url = Uri.parse('https://wa.me/${AppConfig.businessWaNumber}?text=$msg');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Akun 2S Member'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Masuk'),
              Tab(text: 'Daftar'),
              Tab(text: 'Reset WA'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_errorMsg != null)
              Container(
                width: double.infinity,
                color: Colors.red.withValues(alpha: 0.12),
                padding: const EdgeInsets.all(12),
                child: Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  // TAB 1: MASUK CEPAT (NO. WA + PASSWORD)
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Masuk Tanpa OTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('Gunakan Nomor WA terdaftar dan Password Anda.', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _loginPhoneC,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Nomor WhatsApp (08... / 628...)', prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _loginPassC,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _loginBusy ? null : _doLogin,
                          icon: const Icon(Icons.login),
                          label: Text(_loginBusy ? 'Memeriksa...' : 'Masuk Sekarang'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Lupa password atau akun lama belum punya password? Geser ke tab "Reset WA" di atas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  // TAB 2: DAFTAR BARU (WAJIB REVERSE OTP WA)
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Daftar Member Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('Verifikasi nomor WA asli via Reverse OTP & dapatkan +150 Poin!', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _regNameC,
                          decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _regPassC,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Buat Password (min. 6 karakter)', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _regPass2C,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Ulangi Password', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _regRefC,
                          decoration: const InputDecoration(labelText: 'Kode Referral Teman (Opsional)', prefixIcon: Icon(Icons.card_giftcard), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _waWaiting ? null : () => _startWaOtp(mode: 'register'),
                          icon: const Icon(Icons.chat),
                          label: const Text('Daftar & Verifikasi via WhatsApp'),
                        ),
                        if (_waWaiting && _waCode != null) _buildWaWaitingCard(),
                      ],
                    ),
                  ),

                  // TAB 3: LUPA PASSWORD / VERIFIKASI WA ULANG
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Reset Password via WhatsApp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('Buat password baru lalu kirim OTP WA dari nomor Anda yang terdaftar.', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _resetPassC,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password Baru (min. 6 karakter)', prefixIcon: Icon(Icons.lock_reset), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _resetPass2C,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Ulangi Password Baru', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _waWaiting ? null : () => _startWaOtp(mode: 'reset'),
                          icon: const Icon(Icons.verified_user),
                          label: const Text('Verifikasi Pemilik WA & Simpan'),
                        ),
                        if (_waWaiting && _waCode != null) _buildWaWaitingCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaWaitingCard() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: Colors.green.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text('Kode Verifikasi: $_waCode', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Kirim pesan di WhatsApp lalu kembali ke aplikasi ini.', textAlign: TextAlign.center),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'LOGIN $_waCode'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teks LOGIN disalin!')));
              },
              child: const Text('Salin Teks LOGIN Manual'),
            ),
          ],
        ),
      ),
    );
  }
}

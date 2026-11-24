import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_config.dart';
import 'data_store.dart';
import 'tabs_extra.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.useFirebase) {
    await Firebase.initializeApp(options: AppConfig.firebaseAndroidOptions);
  }
  runApp(const TwoSMemberApp());
}

class TwoSMemberApp extends StatefulWidget {
  const TwoSMemberApp({super.key});
  @override
  State<TwoSMemberApp> createState() => _TwoSMemberAppState();
}

class _TwoSMemberAppState extends State<TwoSMemberApp> {
  final AppDataController ctrl = AppDataController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppConfig.appName,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
          ),
          home: ctrl.currentUser == null ? LoginOtpPage(ctrl: ctrl) : MainShell(ctrl: ctrl),
        );
      },
    );
  }
}

class LoginOtpPage extends StatefulWidget {
  final AppDataController ctrl;
  const LoginOtpPage({super.key, required this.ctrl});
  @override
  State<LoginOtpPage> createState() => _LoginOtpPageState();
}

class _LoginOtpPageState extends State<LoginOtpPage> {
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController(text: '081234567890');
  final _otpC = TextEditingController();
  final _refC = TextEditingController();
  bool _otpSent = false;
  String? _demoOtp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFF0D47A1),
                child: Icon(Icons.build_circle, size: 46, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text('2S Member', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text('2S Service Handphone • Nota • Garansi • Store', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              TextField(
                controller: _nameC,
                decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneC,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Nomor WhatsApp (OTP)', prefixIcon: Icon(Icons.chat), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _refC,
                decoration: const InputDecoration(labelText: 'Kode Referral / Affiliate (Opsional)', prefixIcon: Icon(Icons.card_giftcard), border: OutlineInputBorder()),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text('Simulasi WA OTP terkirim: $_demoOtp (masukkan kode ini)', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _otpC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Masukkan 6 Digit OTP WhatsApp', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  if (!_otpSent) {
                    setState(() {
                      _demoOtp = widget.ctrl.requestWhatsappOtp(_phoneC.text);
                      _otpSent = true;
                    });
                  } else {
                    final ok = await widget.ctrl.verifyWhatsappOtp(_phoneC.text, _nameC.text, _otpC.text, _refC.text);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kode OTP salah!')));
                    }
                  }
                },
                icon: Icon(_otpSent ? Icons.login : Icons.send),
                label: Text(_otpSent ? 'Verifikasi & Masuk' : 'Kirim OTP WhatsApp'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final AppDataController ctrl;
  const MainShell({super.key, required this.ctrl});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeServiceTab(ctrl: widget.ctrl),
      StoreTab(ctrl: widget.ctrl),
      GamesMissionTab(ctrl: widget.ctrl),
      LeaderboardAffiliateTab(ctrl: widget.ctrl),
      ProfileTab(ctrl: widget.ctrl),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('2S Member'),
        actions: [
          Row(
            children: [
              const Text('Kasir', style: TextStyle(fontSize: 12)),
              Switch(
                value: widget.ctrl.isAdminMode,
                onChanged: (v) => setState(() => widget.ctrl.isAdminMode = v),
              ),
            ],
          ),
        ],
      ),
      body: pages[_tab],
      floatingActionButton: widget.ctrl.isAdminMode && _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddServiceDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Input Servis'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.build_circle), label: 'Servis'),
          NavigationDestination(icon: Icon(Icons.storefront), label: 'Store'),
          NavigationDestination(icon: Icon(Icons.casino), label: 'Game & Misi'),
          NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Peringkat'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  void _showAddServiceDialog(BuildContext context) {
    final devC = TextEditingController();
    final compC = TextEditingController();
    final partC = TextEditingController();
    final costC = TextEditingController(text: '250000');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Transaksi Servis'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: devC, decoration: const InputDecoration(labelText: 'Tipe HP')),
              TextField(controller: compC, decoration: const InputDecoration(labelText: 'Keluhan')),
              TextField(controller: partC, decoration: const InputDecoration(labelText: 'Sparepart')),
              TextField(controller: costC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Biaya (Rp)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              widget.ctrl.addNewService(
                devC.text.isEmpty ? 'HP Pelanggan' : devC.text,
                compC.text.isEmpty ? 'Pengecekan' : compC.text,
                partC.text.isEmpty ? 'Jasa Servis' : partC.text,
                int.tryParse(costC.text) ?? 150000,
                30,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class HomeServiceTab extends StatelessWidget {
  final AppDataController ctrl;
  const HomeServiceTab({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final u = ctrl.currentUser!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF0D47A1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Halo, ${u.name}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Chip(label: Text('${u.tier} Member')),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${u.points} Poin', style: const TextStyle(color: Colors.amber, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: ctrl.canCheckInToday()
                        ? () {
                            final pts = ctrl.performDailyCheckIn();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check-in sukses! +$pts Poin')));
                          }
                        : null,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(ctrl.canCheckInToday() ? 'Check-in Harian (Streak ${u.checkInStreak}/7)' : 'Sudah Check-in Hari Ini'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Transaksi Servis, Nota & Garansi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...ctrl.services.map((s) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Chip(label: Text(s.status)),
                      ],
                    ),
                    Text(s.deviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('Keluhan: ${s.complaint}'),
                    Text('Total: ${ctrl.formatRupiah(s.totalCost)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 6),
                    Text(
                      s.status == 'Selesai' || s.status == 'Diambil'
                          ? 'Garansi: Sisa ${s.remainingWarrantyDays} hari dari ${s.warrantyDays} hari'
                          : 'Garansi aktif setelah servis selesai',
                      style: TextStyle(color: s.remainingWarrantyDays > 0 ? Colors.green : Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showNotaDialog(context, s),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const Text('Lihat e-Nota'),
                        ),
                        if ((s.status == 'Selesai' || s.status == 'Diambil') && s.remainingWarrantyDays > 0 && !s.warrantyClaimed)
                          OutlinedButton.icon(
                            onPressed: () {
                              ctrl.claimWarranty(s);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Klaim garansi diajukan! Bawa HP ke 2S Service.')));
                            },
                            icon: const Icon(Icons.verified_user, size: 18),
                            label: const Text('Klaim Garansi'),
                          ),
                        if (s.warrantyClaimed) const Chip(label: Text('Garansi Diajukan')),
                        if (ctrl.isAdminMode)
                          DropdownButton<String>(
                            value: s.status,
                            items: ['Menunggu Cek', 'Dikerjakan', 'Selesai', 'Diambil']
                                .map((st) => DropdownMenuItem(value: st, child: Text(st)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) ctrl.updateServiceStatus(s, v);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  void _showNotaDialog(BuildContext context, ServiceOrder s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('e-Nota 2S Service HP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No. Nota : ${s.invoiceNo}'),
            Text('Perangkat: ${s.deviceName}'),
            Text('Keluhan  : ${s.complaint}'),
            Text('Sparepart: ${s.replacedPart}'),
            Text('Status   : ${s.status}'),
            Text('Garansi  : ${s.warrantyDays} Hari'),
            const Divider(),
            Text('Total    : ${ctrl.formatRupiah(s.totalCost)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_config.dart';
import 'data_store.dart';
import 'tabs_extras.dart';

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
  final _phoneC = TextEditingController();
  final _otpC = TextEditingController();
  final _refC = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
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
                decoration: const InputDecoration(labelText: 'Nomor WhatsApp (cth: 081234567890)', prefixIcon: Icon(Icons.chat), border: OutlineInputBorder()),
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
                  child: Text('Simulasi OTP WA: $_demoOtp (masukkan kode ini)', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
                onPressed: _loading
                    ? null
                    : () async {
                        if (!_otpSent) {
                          if (_phoneC.text.trim().length < 9) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan nomor WA yang valid')));
                            return;
                          }
                          setState(() {
                            _demoOtp = widget.ctrl.requestWhatsappOtp(_phoneC.text);
                            _otpSent = true;
                          });
                        } else {
                          setState(() => _loading = true);
                          final err = await widget.ctrl.verifyWhatsappOtp(_phoneC.text, _nameC.text, _otpC.text, _refC.text);
                          if (mounted) {
                            setState(() => _loading = false);
                            if (err != null) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                            }
                          }
                        }
                      },
                icon: Icon(_otpSent ? Icons.login : Icons.send),
                label: Text(_loading ? 'Menghubungkan...' : (_otpSent ? 'Verifikasi & Masuk' : 'Kirim OTP WhatsApp')),
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
      appBar: AppBar(title: const Text('2S Member')),
      body: pages[_tab],
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
}

class HomeServiceTab extends StatelessWidget {
  final AppDataController ctrl;
  const HomeServiceTab({super.key, required this.ctrl});

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
                    Expanded(child: Text('Halo, ${u.name}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
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
                        ? () async {
                            final pts = await ctrl.performDailyCheckIn();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check-in sukses! +$pts Poin')));
                            }
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
        if (ctrl.services.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Belum ada data servis untuk nomor ${u.phone}.\n(Tambahkan dokumen di koleksi "services" Firebase Console dengan userPhone: "${u.phone}")'),
            ),
          ),
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
                          ? 'Garansi: Sisa ${s.remainingWarrantyDays} hari (s/d ${_fmtDate(s.warrantyExpiredAt)})'
                          : 'Garansi aktif setelah servis selesai (${s.warrantyDays} hari)',
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
                            onPressed: () async {
                              await ctrl.claimWarranty(s);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Klaim garansi diajukan! Bawa HP ke 2S Service.')),
                                );
                              }
                            },
                            icon: const Icon(Icons.verified_user, size: 18),
                            label: const Text('Klaim Garansi'),
                          ),
                        if (s.warrantyClaimed) const Chip(label: Text('Garansi Diajukan')),
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
    final textNota = '=== e-Nota 2S Service Handphone ===\n'
        'No. Nota : ${s.invoiceNo}\n'
        'Tanggal  : ${_fmtDate(s.createdAt)}\n'
        'Perangkat: ${s.deviceName}\n'
        'Keluhan  : ${s.complaint}\n'
        'Sparepart: ${s.replacedPart}\n'
        'Status   : ${s.status}\n'
        'Garansi  : ${s.warrantyDays} Hari\n'
        'Total    : ${ctrl.formatRupiah(s.totalCost)}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('e-Nota 2S Service HP'),
        content: Text(textNota),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: textNota));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('e-Nota disalin!')));
            },
            child: const Text('Salin Nota'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }
}

class StoreTab extends StatefulWidget {
  final AppDataController ctrl;
  const StoreTab({super.key, required this.ctrl});
  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  bool _usePoints = true;

  @override
  Widget build(BuildContext context) {
    final u = widget.ctrl.currentUser!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (u.extraStoreDiscount > 0)
          Card(
            color: Colors.amber.withValues(alpha: 0.2),
            child: ListTile(
              leading: const Icon(Icons.local_offer, color: Colors.orange),
              title: Text('Voucher Aktif: Potongan ${widget.ctrl.formatRupiah(u.extraStoreDiscount)}'),
            ),
          ),
        SwitchListTile(
          title: Text('Tukar Poin saat Beli (Saldo: ${u.points} pts)'),
          subtitle: const Text('1 Poin = Rp 100 potongan harga'),
          value: _usePoints,
          onChanged: (v) => setState(() => _usePoints = v),
        ),
        if (widget.ctrl.products.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Memuat katalog produk Store...'))),
        ...widget.ctrl.products.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  child: p.imageUrl.isNotEmpty
                      ? ClipOval(child: Image.network(p.imageUrl, width: 40, height: 40, fit: BoxFit.cover))
                      : const Icon(Icons.shopping_bag),
                ),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p.category} • Diskon ${p.discountPercent}%\n${widget.ctrl.formatRupiah(p.finalPrice)}'),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: () async {
                    final msg = await widget.ctrl.checkoutProduct(p, _usePoints);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                    }
                  },
                  child: const Text('Beli'),
                ),
              ),
            )),
      ],
    );
  }
}

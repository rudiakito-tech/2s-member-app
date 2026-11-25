import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_config.dart';
import 'data_store.dart';

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
  final _refC = TextEditingController();
  bool _loading = false;
  String? _otpCode;

  Future<void> _startReverseOtp() async {
    setState(() => _loading = true);
    final code = await widget.ctrl.createReverseOtpSession(_nameC.text, _refC.text);
    setState(() {
      _otpCode = code;
      _loading = false;
    });

    final msg = Uri.encodeComponent('LOGIN $code');
    final url = Uri.parse('https://wa.me/${AppConfig.businessWaNumber}?text=$msg');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 28),
              const CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFF0D47A1),
                child: Icon(Icons.build_circle, size: 46, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text('2S Member', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text('Reverse OTP WhatsApp • Tanpa Biaya SMS', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 28),
              TextField(
                controller: _nameC,
                decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _refC,
                decoration: const InputDecoration(labelText: 'Kode Referral (Opsional)', prefixIcon: Icon(Icons.card_giftcard), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loading ? null : _startReverseOtp,
                icon: const Icon(Icons.chat),
                label: Text(_loading ? 'Menyiapkan...' : 'Login via WhatsApp'),
              ),
              if (_otpCode != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: Colors.green.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text('Kode Anda: $_otpCode', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text(
                          'Kirim pesan yang muncul di WhatsApp, lalu kembali ke aplikasi ini. Halaman akan masuk otomatis!',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: 'LOGIN $_otpCode'));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teks LOGIN disalin!')));
                          },
                          child: const Text('Salin Teks LOGIN (jika WA tidak terbuka otomatis)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
              Switch(value: widget.ctrl.isAdminMode, onChanged: (v) => setState(() => widget.ctrl.isAdminMode = v)),
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
    final phoneC = TextEditingController(text: widget.ctrl.currentUser?.phone ?? '');
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
              TextField(controller: phoneC, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. WA Pelanggan')),
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
            onPressed: () async {
              await widget.ctrl.addNewService(
                phoneC.text,
                devC.text.isEmpty ? 'HP Pelanggan' : devC.text,
                compC.text.isEmpty ? 'Pengecekan' : compC.text,
                partC.text.isEmpty ? 'Jasa Servis' : partC.text,
                int.tryParse(costC.text) ?? 150000,
                30,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan ke Firestore'),
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
    final visibleServices = ctrl.isAdminMode
        ? ctrl.services
        : ctrl.services.where((s) => s.customerPhone == u.phone).toList();

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
        if (visibleServices.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada transaksi servis. Aktifkan sakelar Kasir di kanan atas untuk input servis tes!'),
            ),
          ),
        ...visibleServices.map((s) => Card(
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
                    Text(
                      s.status == 'Selesai' || s.status == 'Diambil'
                          ? 'Garansi: Sisa ${s.remainingWarrantyDays} hari'
                          : 'Garansi aktif setelah selesai',
                      style: TextStyle(color: s.remainingWarrantyDays > 0 ? Colors.green : Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showNotaDialog(context, s),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const Text('e-Nota'),
                        ),
                        if ((s.status == 'Selesai' || s.status == 'Diambil') && s.remainingWarrantyDays > 0 && !s.warrantyClaimed)
                          OutlinedButton.icon(
                            onPressed: () => ctrl.claimWarranty(s),
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
            Text('No. WA   : ${s.customerPhone}'),
            Text('Perangkat: ${s.deviceName}'),
            Text('Keluhan  : ${s.complaint}'),
            Text('Sparepart: ${s.replacedPart}'),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.ctrl.extraStoreDiscount > 0)
          Card(
            color: Colors.amber.withValues(alpha: 0.2),
            child: ListTile(
              leading: const Icon(Icons.local_offer, color: Colors.orange),
              title: Text('Voucher Aktif: Potongan ${widget.ctrl.formatRupiah(widget.ctrl.extraStoreDiscount)}'),
            ),
          ),
        SwitchListTile(
          title: Text('Tukar Poin (Saldo: ${widget.ctrl.currentUser!.points} pts)'),
          subtitle: const Text('1 Poin = Rp 100 potongan'),
          value: _usePoints,
          onChanged: (v) => setState(() => _usePoints = v),
        ),
        ...widget.ctrl.products.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(child: Icon(p.icon)),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p.category} • Diskon ${p.discountPercent}%\n${widget.ctrl.formatRupiah(p.finalPrice)}'),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: () async {
                    final msg = await widget.ctrl.checkoutProduct(p, _usePoints);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  },
                  child: const Text('Beli'),
                ),
              ),
            )),
      ],
    );
  }
}

class GamesMissionTab extends StatefulWidget {
  final AppDataController ctrl;
  const GamesMissionTab({super.key, required this.ctrl});
  @override
  State<GamesMissionTab> createState() => _GamesMissionTabState();
}

class _GamesMissionTabState extends State<GamesMissionTab> {
  double _turns = 0;

  @override
  Widget build(BuildContext context) {
    final u = widget.ctrl.currentUser!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Mini Game: Spin & Win 2S', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                AnimatedRotation(
                  turns: _turns,
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeOutCubic,
                  child: const CircleAvatar(radius: 52, backgroundColor: Colors.amber, child: Icon(Icons.casino, size: 54, color: Colors.deepOrange)),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    setState(() => _turns += 3 + Random().nextDouble());
                    await Future.delayed(const Duration(seconds: 2));
                    final result = await widget.ctrl.spinWheelReward();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
                  },
                  child: Text(u.freeSpinUsedToday ? 'Putar Lagi (20 Poin)' : 'Putar GRATIS Hari Ini!'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Misi Harian Berhadiah Poin', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...widget.ctrl.missions.map((m) => Card(
              child: ListTile(
                title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${m.description} (+${m.rewardPoints} Poin)'),
                trailing: m.isClaimed
                    ? const Chip(label: Text('Selesai'))
                    : FilledButton(onPressed: m.isCompleted ? () => widget.ctrl.claimMission(m) : null, child: Text(m.isCompleted ? 'Klaim' : 'Belum')),
              ),
            )),
      ],
    );
  }
}

class LeaderboardAffiliateTab extends StatelessWidget {
  final AppDataController ctrl;
  const LeaderboardAffiliateTab({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final u = ctrl.currentUser!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.indigo.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Program Affiliate 2S Member', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Kode Referral Anda: ${u.referralCode}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const Text('Ajak teman login pakai kode ini untuk dapat +100 Poin otomatis!'),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: u.referralCode));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kode referral disalin!')));
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Salin Kode Referral'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Peringkat Member (Live Firestore)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...List.generate(ctrl.leaderboard.length, (i) {
          final item = ctrl.leaderboard[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('#${i + 1}')),
              title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Tier: ${item['tier']}'),
              trailing: Text('${item['points']} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
            ),
          );
        }),
      ],
    );
  }
}

class ProfileTab extends StatefulWidget {
  final AppDataController ctrl;
  const ProfileTab({super.key, required this.ctrl});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.ctrl.currentUser!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('WA: ${u.phone} • Tier: ${u.tier}'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Verifikasi Email Resmi (Bonus +50 Poin)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (u.isEmailVerified)
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('Terverifikasi: ${u.email}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  )
                else ...[
                  TextField(controller: _emailC, decoration: const InputDecoration(labelText: 'Email Anda', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextField(controller: _passC, obscureText: true, decoration: const InputDecoration(labelText: 'Buat Password (min. 6 huruf)', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () async {
                          final msg = await widget.ctrl.sendRealEmailVerification(_emailC.text, _passC.text);
                          setState(() => _sent = true);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                        },
                        child: const Text('Kirim Link Email'),
                      ),
                      if (_sent)
                        OutlinedButton(
                          onPressed: () async {
                            final ok = await widget.ctrl.checkEmailVerificationStatus();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(ok ? 'Email berhasil diverifikasi! +50 Poin' : 'Belum diklik. Cek Inbox/Spam email Anda.')),
                              );
                            }
                          },
                          child: const Text('Saya Sudah Klik Link'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Riwayat Reward Poin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ...widget.ctrl.pointHistories.map((h) => ListTile(
              dense: true,
              title: Text(h.title),
              trailing: Text('${h.amount >= 0 ? '+' : ''}${h.amount} pts', style: TextStyle(fontWeight: FontWeight.bold, color: h.amount >= 0 ? Colors.green : Colors.red)),
            )),
      ],
    );
  }
}

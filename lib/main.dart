import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_config.dart';
import 'auth_page.dart';
import 'data_store.dart';
import 'jp_theme_widgets.dart';

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
  bool _splashMinDone = false;
  bool _skippedToGuest = false;

  @override
  void initState() {
    super.initState();
    ctrl.initSession();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _splashMinDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final ready = ctrl.isInitialized && _splashMinDone;
        Widget screen;
        if (!ready) {
          screen = const SplashScreenPage(key: ValueKey('splash'));
        } else if (ctrl.isGuest && !_skippedToGuest) {
          screen = AuthPage(
            key: const ValueKey('auth'),
            ctrl: ctrl,
            onSkipToDashboard: () => setState(() => _skippedToGuest = true),
          );
        } else {
          screen = MainShell(key: const ValueKey('main'), ctrl: ctrl);
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppConfig.appName,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: JpColors.creamBg,
            colorScheme: ColorScheme.fromSeed(seedColor: JpColors.orange, primary: JpColors.navy),
          ),
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: screen,
          ),
        );
      },
    );
  }
}

// 1. LAYAR SPLASH SCREEN
class SplashScreenPage extends StatelessWidget {
  const SplashScreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: JpBackdrop(
        topFuji: true,
        bottomFuji: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 18),
                const TwoSMemberLogo(scale: 1.15),
                const SizedBox(height: 8),
                const Text(
                  'Member Lebih Untung, Bersama 2S',
                  style: TextStyle(color: JpColors.navy, fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const Spacer(),
                const JpMascotBadge(
                  bubbleText: 'Nikmati Berbagai Keuntungan Menarik hanya di 2S Member!',
                ),
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.08, end: 1.0),
                  duration: const Duration(milliseconds: 1700),
                  curve: Curves.easeOutCubic,
                  builder: (_, val, __) => Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: val,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.7),
                          valueColor: const AlwaysStoppedAnimation<Color>(JpColors.orange),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Memuat aplikasi...',
                        style: TextStyle(color: JpColors.navyMuted, fontSize: 12.5, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void openAuthPage(BuildContext context, AppDataController ctrl, {int tab = 0}) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => AuthPage(ctrl: ctrl, initialTab: tab)));
}

void promptLoginDialog(BuildContext context, AppDataController ctrl, String actionName) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Masuk atau Daftar Dulu'),
      content: Text('Untuk $actionName, silakan Login atau Daftar akun 2S Member terlebih dahulu.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Nanti')),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(ctx);
            openAuthPage(context, ctrl, tab: 1);
          },
          child: const Text('Daftar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            openAuthPage(context, ctrl, tab: 0);
          },
          child: const Text('Login'),
        ),
      ],
    ),
  );
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
        backgroundColor: JpColors.creamLight,
        title: const Text('2S Member', style: TextStyle(fontWeight: FontWeight.w800, color: JpColors.navy)),
        actions: [
          if (widget.ctrl.isGuest)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonal(
                onPressed: () => openAuthPage(context, widget.ctrl, tab: 0),
                child: const Text('Login / Daftar'),
              ),
            )
          else if (widget.ctrl.canUseAdmin)
            Row(
              children: [
                const Text('Kasir', style: TextStyle(fontSize: 12)),
                Switch(value: widget.ctrl.isAdminMode, onChanged: (v) => setState(() => widget.ctrl.isAdminMode = v)),
              ],
            ),
        ],
      ),
      body: pages[_tab],
      floatingActionButton: widget.ctrl.isAdminMode && widget.ctrl.canUseAdmin && _tab == 0
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
    if (ctrl.isGuest) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: JpColors.navy,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.card_giftcard, color: JpColors.gold),
                      SizedBox(width: 8),
                      Text('Mode Tamu • Promo Member Baru', style: TextStyle(color: JpColors.gold, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Selamat Datang di 2S Service HP!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'Login atau Daftar untuk melacak servis HP, melihat e-Nota & garansi, Check-in poin & belanja Store.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: JpColors.orange, foregroundColor: Colors.white),
                          onPressed: () => openAuthPage(context, ctrl, tab: 0),
                          child: const Text('Login', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                          onPressed: () => openAuthPage(context, ctrl, tab: 1),
                          child: const Text('Daftar (+150 Poin)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Promo & Keunggulan 2S Member', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Card(child: ListTile(leading: Icon(Icons.local_offer, color: Colors.orange), title: Text('Diskon Aksesoris Store s/d 25%'), subtitle: Text('Khusus member aktif + potongan tukar poin!'))),
          const Card(child: ListTile(leading: Icon(Icons.verified_user, color: Colors.green), title: Text('e-Nota & Pantau Garansi Otomatis'), subtitle: Text('Tidak takut nota hilang saat klaim garansi servis.'))),
          const Card(child: ListTile(leading: Icon(Icons.casino, color: Colors.purple), title: Text('Check-in Harian & Mini Game Berhadiah'), subtitle: Text('Kumpulkan poin gratis setiap hari & raih tier Platinum!'))),
        ],
      );
    }

    final u = ctrl.currentUser!;
    final visibleServices = ctrl.isAdminMode
        ? ctrl.services
        : ctrl.services.where((s) => s.customerPhone == u.phone).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: JpColors.navy,
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
                Text('${u.points} Poin', style: const TextStyle(color: JpColors.gold, fontSize: 26, fontWeight: FontWeight.bold)),
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
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Belum ada transaksi servis atas nomor WA Anda.'))),
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
                        OutlinedButton.icon(onPressed: () => _showNotaDialog(context, s), icon: const Icon(Icons.receipt_long, size: 18), label: const Text('e-Nota')),
                        if ((s.status == 'Selesai' || s.status == 'Diambil') && s.remainingWarrantyDays > 0 && !s.warrantyClaimed)
                          OutlinedButton.icon(onPressed: () => ctrl.claimWarranty(s), icon: const Icon(Icons.verified_user, size: 18), label: const Text('Klaim Garansi')),
                        if (s.warrantyClaimed) const Chip(label: Text('Garansi Diajukan')),
                        if (ctrl.isAdminMode)
                          DropdownButton<String>(
                            value: s.status,
                            items: ['Menunggu Cek', 'Dikerjakan', 'Selesai', 'Diambil'].map((st) => DropdownMenuItem(value: st, child: Text(st))).toList(),
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
    final pts = widget.ctrl.currentUser?.points ?? 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.ctrl.isGuest)
          Card(
            color: Colors.amber.withValues(alpha: 0.15),
            child: ListTile(
              leading: const Icon(Icons.info, color: Colors.orange),
              title: const Text('Mode Tamu: Lihat katalog promo. Login untuk membeli!'),
              trailing: TextButton(onPressed: () => openAuthPage(context, widget.ctrl), child: const Text('Login')),
            ),
          ),
        if (widget.ctrl.extraStoreDiscount > 0)
          Card(
            color: Colors.amber.withValues(alpha: 0.2),
            child: ListTile(
              leading: const Icon(Icons.local_offer, color: Colors.orange),
              title: Text('Voucher Aktif: Potongan ${widget.ctrl.formatRupiah(widget.ctrl.extraStoreDiscount)}'),
            ),
          ),
        if (!widget.ctrl.isGuest)
          SwitchListTile(
            title: Text('Tukar Poin (Saldo: $pts pts)'),
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
                    if (widget.ctrl.isGuest) {
                      promptLoginDialog(context, widget.ctrl, 'membeli produk Store');
                      return;
                    }
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
    final u = widget.ctrl.currentUser;
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
                    if (widget.ctrl.isGuest) {
                      promptLoginDialog(context, widget.ctrl, 'memutar Mini Game');
                      return;
                    }
                    setState(() => _turns += 3 + Random().nextDouble());
                    await Future.delayed(const Duration(seconds: 2));
                    final result = await widget.ctrl.spinWheelReward();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
                  },
                  child: Text(u?.freeSpinUsedToday == true ? 'Putar Lagi (20 Poin)' : 'Putar GRATIS Hari Ini!'),
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
                    : FilledButton(
                        onPressed: widget.ctrl.isGuest
                            ? () => promptLoginDialog(context, widget.ctrl, 'klaim Misi')
                            : (m.isCompleted ? () => widget.ctrl.claimMission(m) : null),
                        child: Text(m.isCompleted ? 'Klaim' : 'Belum'),
                      ),
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
    final u = ctrl.currentUser;
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
                if (u == null) ...[
                  const Text('Login atau daftar untuk mendapatkan kode referral unik & komisi +100 Poin tiap teman mendaftar!'),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: () => openAuthPage(context, ctrl, tab: 1), child: const Text('Daftar Sekarang')),
                ] else ...[
                  Text('Kode Referral Anda: ${u.referralCode}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const Text('Ajak teman daftar pakai kode ini untuk dapat +100 Poin otomatis!'),
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
    final u = widget.ctrl.currentUser;
    if (u == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle, size: 80, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Anda belum login', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Login atau daftar untuk melihat profil, poin, dan verifikasi email.', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: () => openAuthPage(context, widget.ctrl, tab: 0), icon: const Icon(Icons.login), label: const Text('Login')),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () => openAuthPage(context, widget.ctrl, tab: 1), icon: const Icon(Icons.person_add), label: const Text('Daftar Akun')),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('WA: ${u.phone} • Tier: ${u.tier}'),
            trailing: const Chip(avatar: Icon(Icons.verified, color: Colors.green, size: 18), label: Text('WA OK')),
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
                  TextField(controller: _passC, obscureText: true, decoration: const InputDecoration(labelText: 'Password Email (min. 6 huruf)', border: OutlineInputBorder())),
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
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => widget.ctrl.logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Keluar dari Akun'),
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

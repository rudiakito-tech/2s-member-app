import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_config.dart';
import 'auth_page.dart';
import 'cloudinary_service.dart';
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
          home: AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: screen),
        );
      },
    );
  }
}

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
                const Text('Member Lebih Untung, Bersama 2S', style: TextStyle(color: JpColors.navy, fontWeight: FontWeight.w700, fontSize: 13.5)),
                const Spacer(),
                const JpMascotBadge(bubbleText: 'Nikmati Berbagai Keuntungan Menarik hanya di 2S Member!'),
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
                      const Text('Memuat aplikasi...', style: TextStyle(color: JpColors.navyMuted, fontSize: 12.5, fontStyle: FontStyle.italic)),
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
              child: FilledButton.tonal(onPressed: () => openAuthPage(context, widget.ctrl, tab: 0), child: const Text('Login / Daftar')),
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
    String photoUrl = '';
    bool uploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
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
                const SizedBox(height: 10),
                if (photoUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(photoUrl, height: 110, width: double.infinity, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          setDlg(() => uploading = true);
                          final res = await CloudinaryService.pickAndUpload(ctx, folder: '2s_member/services');
                          if (!ctx.mounted) return;
                          setDlg(() {
                            uploading = false;
                            if (res?.url != null) photoUrl = res!.url!;
                          });
                          if (res?.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res!.error!)));
                          }
                        },
                  icon: uploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt),
                  label: Text(photoUrl.isEmpty ? 'Upload Foto Kondisi HP' : 'Ganti Foto HP'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: uploading
                  ? null
                  : () async {
                      await widget.ctrl.addNewService(
                        phoneC.text,
                        devC.text.isEmpty ? 'HP Pelanggan' : devC.text,
                        compC.text.isEmpty ? 'Pengecekan' : compC.text,
                        partC.text.isEmpty ? 'Jasa Servis' : partC.text,
                        int.tryParse(costC.text) ?? 150000,
                        30,
                        photoUrl: photoUrl,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
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
                  const Text('Login atau Daftar untuk melacak servis HP, e-Nota, garansi, Check-in poin & belanja Store.', style: TextStyle(color: Colors.white70)),
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
          const Card(child: ListTile(leading: Icon(Icons.local_offer, color: Colors.orange), title: Text('Diskon Aksesoris Store'), subtitle: Text('Gunakan kode voucher & tukar poin saat checkout!'))),
          const Card(child: ListTile(leading: Icon(Icons.verified_user, color: Colors.green), title: Text('e-Nota & Bukti Foto Garansi'), subtitle: Text('Lengkap dengan foto kondisi HP saat masuk servis.'))),
          const Card(child: ListTile(leading: Icon(Icons.casino, color: Colors.purple), title: Text('Check-in Harian & Mini Game'), subtitle: Text('Kumpulkan poin gratis setiap hari & raih tier Platinum!'))),
        ],
      );
    }

    final u = ctrl.currentUser!;
    final visibleServices = ctrl.isAdminMode ? ctrl.services : ctrl.services.where((s) => s.customerPhone == u.phone).toList();

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
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check-in sukses! +$pts Poin')));
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
                    if (s.photoUrl.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(s.photoUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 8),
                    ],
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.photoUrl.isNotEmpty) ...[
                ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(s.photoUrl, height: 140, width: double.infinity, fit: BoxFit.cover)),
                const SizedBox(height: 10),
              ],
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
  void _showAddProductDialog() {
    final nameC = TextEditingController();
    final catC = TextEditingController(text: 'Aksesoris');
    final priceC = TextEditingController(text: '50000');
    final discC = TextEditingController(text: '10');
    final stockC = TextEditingController(text: '10');
    String photoUrl = '';
    bool uploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Tambah Produk Store'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama Produk')),
                TextField(controller: catC, decoration: const InputDecoration(labelText: 'Kategori')),
                TextField(controller: priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga (Rp)')),
                TextField(controller: discC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Diskon (%)')),
                TextField(controller: stockC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stok')),
                const SizedBox(height: 8),
                if (photoUrl.isNotEmpty)
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(photoUrl, height: 90, width: double.infinity, fit: BoxFit.cover)),
                OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          setDlg(() => uploading = true);
                          final res = await CloudinaryService.pickAndUpload(ctx, folder: '2s_member/products');
                          if (!ctx.mounted) return;
                          setDlg(() {
                            uploading = false;
                            if (res?.url != null) photoUrl = res!.url!;
                          });
                        },
                  icon: uploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image),
                  label: Text(photoUrl.isEmpty ? 'Upload Foto Produk' : 'Ganti Foto'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: uploading
                  ? null
                  : () async {
                      if (nameC.text.trim().isEmpty) return;
                      await widget.ctrl.addProduct(
                        name: nameC.text,
                        category: catC.text,
                        price: int.tryParse(priceC.text) ?? 50000,
                        discountPercent: int.tryParse(discC.text) ?? 0,
                        stock: int.tryParse(stockC.text) ?? 10,
                        photoUrl: photoUrl,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVoucherDialog() {
    final codeC = TextEditingController();
    final discC = TextEditingController(text: '15000');
    final minC = TextEditingController(text: '50000');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Voucher Diskon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Kode Voucher (misal: 2SBARU)')),
            TextField(controller: discC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Potongan (Rp)')),
            TextField(controller: minC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimal Belanja (Rp)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (codeC.text.trim().isEmpty) return;
              await widget.ctrl.addVoucher(
                code: codeC.text,
                discountAmount: int.tryParse(discC.text) ?? 10000,
                minSpend: int.tryParse(minC.text) ?? 0,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog(StoreProduct p) {
    bool usePts = true;
    String delivery = 'Ambil di Toko';
    final voucherC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Beli ${p.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Harga: ${widget.ctrl.formatRupiah(p.finalPrice)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(controller: voucherC, decoration: const InputDecoration(labelText: 'Kode Voucher (Opsional)', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: delivery,
                  decoration: const InputDecoration(labelText: 'Pengambilan', border: OutlineInputBorder()),
                  items: ['Ambil di Toko', 'Kirim Kurir'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setDlg(() => delivery = v ?? 'Ambil di Toko'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Tukar Poin (${widget.ctrl.currentUser!.points} pts)'),
                  value: usePts,
                  onChanged: (v) => setDlg(() => usePts = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final msg = await widget.ctrl.checkoutProduct(p, usePoints: usePts, voucherCode: voucherC.text, deliveryType: delivery);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              },
              child: const Text('Konfirmasi Beli'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.ctrl.currentUser;
    final myOrders = widget.ctrl.isAdminMode
        ? widget.ctrl.storeOrders
        : widget.ctrl.storeOrders.where((o) => o.customerPhone == u?.phone).toList();

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
        if (widget.ctrl.isAdminMode && widget.ctrl.canUseAdmin)
          Card(
            color: JpColors.navy.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: FilledButton.icon(onPressed: _showAddProductDialog, icon: const Icon(Icons.add), label: const Text('Produk'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: _showAddVoucherDialog, icon: const Icon(Icons.confirmation_number), label: const Text('Voucher'))),
                ],
              ),
            ),
          ),
        if (widget.ctrl.vouchers.isNotEmpty)
          Wrap(
            spacing: 6,
            children: widget.ctrl.vouchers.where((v) => v.isActive).map((v) => Chip(label: Text('Promo ${v.code}: -${widget.ctrl.formatRupiah(v.discountAmount)}'))).toList(),
          ),
        if (widget.ctrl.extraStoreDiscount > 0)
          Card(
            color: Colors.amber.withValues(alpha: 0.2),
            child: ListTile(
              leading: const Icon(Icons.local_offer, color: Colors.orange),
              title: Text('Hadiah Spin Aktif: Potongan ${widget.ctrl.formatRupiah(widget.ctrl.extraStoreDiscount)}'),
            ),
          ),
        const SizedBox(height: 8),
        ...widget.ctrl.products.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: p.photoUrl.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p.photoUrl, width: 52, height: 52, fit: BoxFit.cover))
                    : const CircleAvatar(child: Icon(Icons.shopping_bag)),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p.category} • Diskon ${p.discountPercent}% • Stok: ${p.stock}\n${widget.ctrl.formatRupiah(p.finalPrice)}'),
                isThreeLine: true,
                trailing: widget.ctrl.isAdminMode
                    ? IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => widget.ctrl.deleteProduct(p.id))
                    : FilledButton(
                        onPressed: p.stock <= 0
                            ? null
                            : () {
                                if (widget.ctrl.isGuest) {
                                  promptLoginDialog(context, widget.ctrl, 'membeli produk Store');
                                  return;
                                }
                                _showCheckoutDialog(p);
                              },
                        child: Text(p.stock <= 0 ? 'Habis' : 'Beli'),
                      ),
              ),
            )),
        if (!widget.ctrl.isGuest && myOrders.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(widget.ctrl.isAdminMode ? 'Semua Pesanan Store (Kasir)' : 'Pesanan Store Saya', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...myOrders.map((o) => Card(
                child: ListTile(
                  title: Text('${o.orderNo} • ${o.productName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${o.customerName} (${o.deliveryType}) • ${widget.ctrl.formatRupiah(o.finalTotal)}'),
                  trailing: widget.ctrl.isAdminMode
                      ? DropdownButton<String>(
                          value: o.status,
                          items: ['Menunggu', 'Diproses', 'Siap Diambil', 'Selesai'].map((st) => DropdownMenuItem(value: st, child: Text(st))).toList(),
                          onChanged: (v) {
                            if (v != null) widget.ctrl.updateStoreOrderStatus(o, v);
                          },
                        )
                      : Chip(label: Text(o.status)),
                ),
              )),
        ],
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
    final canFreeSpin = widget.ctrl.canSpinFreeToday();
    final missionDefs = [
      {'id': 'm_email', 'title': 'Verifikasi Email Resmi', 'desc': 'Verifikasi email di menu Profil', 'pts': 100},
      {'id': 'm_checkin', 'title': 'Check-in Hari Ini', 'desc': 'Lakukan check-in harian hari ini (reset tiap hari)', 'pts': 30},
      {'id': 'm_spin', 'title': 'Putar Spin Wheel', 'desc': 'Mainkan mini game hari ini (reset tiap hari)', 'pts': 25},
    ];

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
                  child: Text(canFreeSpin || widget.ctrl.isGuest ? 'Putar GRATIS Hari Ini!' : 'Putar Lagi (20 Poin)'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Misi Harian Berhadiah Poin', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...missionDefs.map((m) {
          final id = m['id'] as String;
          final pts = m['pts'] as int;
          final title = m['title'] as String;
          final claimed = widget.ctrl.isMissionClaimed(id);
          final completed = widget.ctrl.isMissionCompleted(id);
          return Card(
            child: ListTile(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${m['desc']} (+$pts Poin)'),
              trailing: claimed
                  ? const Chip(label: Text('Selesai'))
                  : FilledButton(
                      onPressed: widget.ctrl.isGuest
                          ? () => promptLoginDialog(context, widget.ctrl, 'klaim Misi')
                          : (completed ? () => widget.ctrl.claimMission(id, pts, title) : null),
                      child: Text(completed ? 'Klaim' : 'Belum'),
                    ),
            ),
          );
        }),
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
  bool _uploadingAvatar = false;

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
            leading: CircleAvatar(
              radius: 26,
              backgroundImage: u.photoUrl.isNotEmpty ? NetworkImage(u.photoUrl) : null,
              child: u.photoUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('WA: ${u.phone} • Tier: ${u.tier}'),
            trailing: TextButton.icon(
              onPressed: _uploadingAvatar
                  ? null
                  : () async {
                      setState(() => _uploadingAvatar = true);
                      final res = await CloudinaryService.pickAndUpload(context, folder: '2s_member/profiles');
                      if (!context.mounted) return;
                      setState(() => _uploadingAvatar = false);
                      if (res?.url != null) {
                        await widget.ctrl.updateProfilePhoto(res!.url!);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profil berhasil diperbarui!')));
                      } else if (res?.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res!.error!)));
                      }
                    },
              icon: _uploadingAvatar ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt, size: 18),
              label: const Text('Foto'),
            ),
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

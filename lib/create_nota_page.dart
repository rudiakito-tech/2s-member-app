import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cloudinary_service.dart';
import 'data_store.dart';
import 'jp_theme_widgets.dart';
import 'qr_member_widgets.dart';

class CreateNotaPage extends StatefulWidget {
  final AppDataController ctrl;
  final String? initialQrRaw;
  final Future<void> Function(ServiceOrder created)? onSendWa;

  const CreateNotaPage({super.key, required this.ctrl, this.initialQrRaw, this.onSendWa});

  @override
  State<CreateNotaPage> createState() => _CreateNotaPageState();
}

class _CreateNotaPageState extends State<CreateNotaPage> {
  final _phoneC = TextEditingController();
  final _nameC = TextEditingController();
  final _brandC = TextEditingController();
  final _typeC = TextEditingController();
  final _damageC = TextEditingController();
  final _repairC = TextEditingController();
  final _priceC = TextEditingController();
  final _dpC = TextEditingController();
  final _warrantyC = TextEditingController(text: '30');

  late DateTime _createdAt;
  MemberUser? _foundMember;
  bool _searched = false;
  bool _searching = false;
  bool _isTempMode = false;
  bool _uploadingPhoto = false;
  bool _saving = false;
  String _photoUrl = '';
  String _paymentStatus = 'Belum Bayar';

  final _quickBrands = ['Samsung', 'iPhone', 'Xiaomi', 'OPPO', 'Vivo', 'Realme', 'Infinix'];
  final _quickWarranties = ['0', '7', '14', '30', '90'];

  @override
  void initState() {
    super.initState();
    _createdAt = DateTime.now();
    if (widget.initialQrRaw != null && widget.initialQrRaw!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookupCustomer(widget.initialQrRaw!));
    }
  }

  @override
  void dispose() {
    for (final c in [_phoneC, _nameC, _brandC, _typeC, _damageC, _repairC, _priceC, _dpC, _warrantyC]) {
      c.dispose();
    }
    super.dispose();
  }

  void _activateTempAccount() {
    final code = 100000 + Random().nextInt(899999);
    setState(() {
      _isTempMode = true;
      _searched = false;
      _foundMember = null;
      _phoneC.text = 'TEMP-$code';
    });
  }

  Future<void> _lookupCustomer(String rawInput) async {
    final upper = rawInput.trim().toUpperCase();
    if (upper.startsWith('TEMP-')) {
      setState(() => _isTempMode = true);
      return;
    }
    final clean = widget.ctrl.normalizePhone(rawInput.replaceFirst('2SMEMBER|', ''));
    if (clean.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan nomor HP yang valid (min. 9 digit).')));
      return;
    }
    setState(() {
      _isTempMode = false;
      _searching = true;
      _phoneC.text = clean;
    });
    final member = await widget.ctrl.lookupMemberByPhone(clean);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searched = true;
      _foundMember = member;
      if (member != null) _nameC.text = member.name;
    });
  }

  Future<void> _scanQrCustomer() async {
    final raw = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (!mounted || raw == null) return;
    await _lookupCustomer(raw);
  }

  Future<void> _uploadDevicePhoto() async {
    setState(() => _uploadingPhoto = true);
    final res = await CloudinaryService.pickAndUpload(context, folder: '2s_member/services');
    if (!mounted) return;
    setState(() {
      _uploadingPhoto = false;
      if (res?.url != null) _photoUrl = res!.url!;
    });
    if (res?.error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res!.error!)));
  }

  Future<void> _saveNota() async {
    final rawPhone = _phoneC.text.trim().toUpperCase();
    final isTemp = rawPhone.startsWith('TEMP-');
    final phone = isTemp ? rawPhone : widget.ctrl.normalizePhone(_phoneC.text);

    if (!isTemp && phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor HP wajib diisi, atau klik "Lupa / Tanpa No. HP".')));
      return;
    }
    if (_nameC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama pelanggan wajib diisi.')));
      return;
    }
    if (_brandC.text.trim().isEmpty || _typeC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merek dan Type HP wajib diisi.')));
      return;
    }
    if (_damageC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kerusakan wajib diisi.')));
      return;
    }

    final totalCost = int.tryParse(_priceC.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    final dpVal = int.tryParse(_dpC.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    if (_paymentStatus == 'DP' && dpVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan nominal DP terlebih dahulu.')));
      return;
    }

    setState(() => _saving = true);
    final order = await widget.ctrl.addNewService(
      custPhone: phone,
      custName: _nameC.text.trim(),
      brand: _brandC.text.trim(),
      deviceType: _typeC.text.trim(),
      complaint: _damageC.text.trim(),
      repairAction: _repairC.text.trim().isEmpty ? 'Pengecekan & Servis' : _repairC.text.trim(),
      cost: totalCost,
      warrantyDays: int.tryParse(_warrantyC.text.trim()) ?? 30,
      paymentStatus: _paymentStatus,
      paidAmount: _paymentStatus == 'Lunas' ? totalCost : (_paymentStatus == 'DP' ? dpVal : 0),
      beforePhotoUrl: _photoUrl,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    final claimInfoText = 'No. Nota: ${order.invoiceNo}\nKode Klaim: ${order.claimCode}';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Nota Berhasil Dibuat!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No. Nota  : ${order.invoiceNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Status    : ${order.status}'),
            Text('Pelanggan : ${order.customerName} (${order.customerPhone})'),
            Text('Unit      : ${order.fullDeviceName}'),
            Text('Total     : ${widget.ctrl.formatRupiah(order.totalCost)}'),
            Text('Pembayaran: ${order.paymentStatus} (Masuk Kas Toko: ${widget.ctrl.formatRupiah(order.paidAmount)})'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: JpColors.gold)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kode Klaim Akun: ${order.claimCode}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: JpColors.navy)),
                  const SizedBox(height: 3),
                  const Text('Berikan No. Nota & Kode Klaim ini ke pelanggan agar bisa klaim akun/ganti nomor mandiri.', style: TextStyle(fontSize: 11.5, color: JpColors.navyMuted)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: claimInfoText));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No. Nota & Kode Klaim disalin!')));
            },
            icon: const Icon(Icons.copy, size: 17),
            label: const Text('Salin Klaim'),
          ),
          if (!isTemp && widget.onSendWa != null)
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.onSendWa!(order);
              },
              icon: const Icon(Icons.chat, color: Colors.green),
              label: const Text('Kirim WA'),
            ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Selesai')),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final estTotal = int.tryParse(_priceC.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    final estDp = int.tryParse(_dpC.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: JpColors.creamLight,
        title: const Text('Buat Nota Servis', style: TextStyle(fontWeight: FontWeight.w800, color: JpColors.navy)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: JpColors.navy,
            child: ListTile(
              leading: const Icon(Icons.access_time_filled, color: JpColors.gold),
              title: const Text('Tanggal & Jam Masuk • Status: Diterima', style: TextStyle(color: Colors.white70, fontSize: 12)),
              subtitle: Text(widget.ctrl.formatDateTime(_createdAt), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('1. Data Pelanggan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: JpColors.navy)),
                      TextButton.icon(
                        onPressed: _activateTempAccount,
                        icon: const Icon(Icons.person_off_outlined, size: 17),
                        label: const Text('Lupa / Tanpa No. HP', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _phoneC,
                    keyboardType: TextInputType.phone,
                    readOnly: _isTempMode,
                    onSubmitted: _lookupCustomer,
                    decoration: InputDecoration(
                      labelText: _isTempMode ? 'ID Sementara (Otomatis)' : 'No. HP / WhatsApp Pelanggan',
                      hintText: '0812... atau 628...',
                      border: const OutlineInputBorder(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isTempMode)
                            IconButton(
                              tooltip: 'Kembali isi No. HP',
                              onPressed: () => setState(() {
                                _isTempMode = false;
                                _phoneC.clear();
                              }),
                              icon: const Icon(Icons.close, color: Colors.red),
                            )
                          else
                            IconButton(
                              tooltip: 'Cari No. HP',
                              onPressed: _searching ? null : () => _lookupCustomer(_phoneC.text),
                              icon: _searching ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
                            ),
                          IconButton(
                            tooltip: 'Scan QR Pelanggan',
                            onPressed: _scanQrCustomer,
                            icon: const Icon(Icons.qr_code_scanner, color: JpColors.orange),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_isTempMode)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12), border: Border.all(color: JpColors.gold)),
                      child: const Text('🆕 Mode Tanpa No. HP: Akun sementara dibuatkan otomatis. Pelanggan klaim nanti pakai No. Nota & Kode Klaim.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: JpColors.navy)),
                    )
                  else if (_searched && _foundMember != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withValues(alpha: 0.4))),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 22, backgroundImage: _foundMember!.photoUrl.isNotEmpty ? NetworkImage(_foundMember!.photoUrl) : null, child: _foundMember!.photoUrl.isEmpty ? const Icon(Icons.person) : null),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('✅ Pelanggan Terdaftar (Terisi Otomatis)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Tier: ${_foundMember!.tier} • Poin: ${_foundMember!.points} pts', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                Text('Referral: ${_foundMember!.referralCode}', style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_searched && _foundMember == null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withValues(alpha: 0.5))),
                      child: const Text('🆕 Pelanggan Baru: Otomatis didaftarkan. Password diatur pelanggan via Lupa Password (Reverse OTP).', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: JpColors.navy)),
                    ),
                  TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'Nama Pelanggan', border: OutlineInputBorder())),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2. Detail Perangkat & Foto Before', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: JpColors.navy)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 4, children: _quickBrands.map((b) => ActionChip(label: Text(b, style: const TextStyle(fontSize: 12)), onPressed: () => setState(() => _brandC.text = b))).toList()),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _brandC, decoration: const InputDecoration(labelText: 'Merek (Samsung, iPhone...)', border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _typeC, decoration: const InputDecoration(labelText: 'Type (A54, 13 Pro...)', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _damageC, maxLines: 2, decoration: const InputDecoration(labelText: 'Kerusakan / Keluhan', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _repairC, maxLines: 2, decoration: const InputDecoration(labelText: 'Perbaikan / Sparepart', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _priceC, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Harga Estimasi / Fix (Rp)', border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      SizedBox(width: 115, child: TextField(controller: _warrantyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Garansi (Hari)', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: _quickWarranties.map((w) => ActionChip(label: Text('$w Hr', style: const TextStyle(fontSize: 11.5)), onPressed: () => setState(() => _warrantyC.text = w))).toList()),
                  const SizedBox(height: 10),
                  if (_photoUrl.isNotEmpty) ...[
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_photoUrl, height: 130, width: double.infinity, fit: BoxFit.cover)),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _uploadingPhoto ? null : _uploadDevicePhoto,
                      icon: _uploadingPhoto ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt),
                      label: Text(_photoUrl.isEmpty ? 'Upload Foto HP Before (Cloudinary)' : 'Ganti Foto Before'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('3. Status Pembayaran (Otomatis Kas Toko)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: JpColors.navy)),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Lunas', label: Text('Lunas')),
                      ButtonSegment(value: 'DP', label: Text('DP')),
                      ButtonSegment(value: 'Belum Bayar', label: Text('Belum Bayar')),
                    ],
                    selected: {_paymentStatus},
                    onSelectionChanged: (v) => setState(() => _paymentStatus = v.first),
                  ),
                  if (_paymentStatus == 'DP') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _dpC,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Nominal DP Dibayar (Rp)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Masuk Kas Toko: ${widget.ctrl.formatRupiah(estDp)} • Sisa: ${widget.ctrl.formatRupiah((estTotal - estDp) < 0 ? 0 : (estTotal - estDp))}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E56A0)),
                    ),
                  ] else if (_paymentStatus == 'Lunas') ...[
                    const SizedBox(height: 8),
                    Text('Uang masuk Kas Toko saat ini: ${widget.ctrl.formatRupiah(estTotal)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.green)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: JpColors.orange, foregroundColor: Colors.white),
              onPressed: _saving || _uploadingPhoto ? null : _saveNota,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
              label: Text(_saving ? 'Menyimpan Nota...' : 'Simpan & Buat Nota', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
// AKHIR FILE create_nota_page.dart

import 'package:flutter/material.dart';
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
  final _warrantyC = TextEditingController(text: '30');

  late DateTime _createdAt;
  MemberUser? _foundMember;
  bool _searched = false;
  bool _searching = false;
  bool _uploadingPhoto = false;
  bool _saving = false;
  String _photoUrl = '';

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
    for (final c in [_phoneC, _nameC, _brandC, _typeC, _damageC, _repairC, _priceC, _warrantyC]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _lookupCustomer(String rawInput) async {
    final clean = widget.ctrl.normalizePhone(rawInput.replaceFirst('2SMEMBER|', ''));
    if (clean.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan nomor HP yang valid (min. 9 digit).')));
      return;
    }
    setState(() {
      _searching = true;
      _phoneC.text = clean;
    });
    final member = await widget.ctrl.lookupMemberByPhone(clean);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searched = true;
      _foundMember = member;
      if (member != null) {
        _nameC.text = member.name;
      }
    });
  }

  Future<void> _scanQrCustomer() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
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
    if (res?.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res!.error!)));
    }
  }

  Future<void> _saveNota() async {
    final phone = widget.ctrl.normalizePhone(_phoneC.text);
    if (phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor HP pelanggan wajib diisi.')));
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

    setState(() => _saving = true);
    final order = await widget.ctrl.addNewService(
      custPhone: phone,
      custName: _nameC.text.trim(),
      brand: _brandC.text.trim(),
      deviceType: _typeC.text.trim(),
      complaint: _damageC.text.trim(),
      repairAction: _repairC.text.trim().isEmpty ? 'Pengecekan & Servis' : _repairC.text.trim(),
      cost: int.tryParse(_priceC.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
      warrantyDays: int.tryParse(_warrantyC.text.trim()) ?? 30,
      photoUrl: _photoUrl,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    final isNewMember = _foundMember == null;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Nota Berhasil Dibuat!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No. Nota : ${order.invoiceNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Pelanggan: ${order.customerName} (${order.customerPhone})'),
            Text('Unit     : ${order.fullDeviceName}'),
            Text('Total    : ${widget.ctrl.formatRupiah(order.totalCost)}'),
            if (isNewMember) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Text(
                  'Pelanggan baru otomatis terdaftar sebagai 2S Member (+150 Poin). Password dapat dibuat pelanggan lewat menu Lupa Password (Reverse OTP).',
                  style: TextStyle(fontSize: 12, color: JpColors.navy),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (widget.onSendWa != null)
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.onSendWa!(order);
              },
              icon: const Icon(Icons.chat, color: Colors.green),
              label: const Text('Kirim Nota ke WA'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: JpColors.creamLight,
        title: const Text('Buat Nota Servis', style: TextStyle(fontWeight: FontWeight.w800, color: JpColors.navy)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // TANGGAL & JAM OTOMATIS
          Card(
            color: JpColors.navy,
            child: ListTile(
              leading: const Icon(Icons.access_time_filled, color: JpColors.gold),
              title: const Text('Tanggal & Jam Masuk (Otomatis)', style: TextStyle(color: Colors.white70, fontSize: 12)),
              subtitle: Text(widget.ctrl.formatDateTime(_createdAt), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),

          // BAGIAN 1: FORM PELANGGAN (CARI NO. HP / SCAN QR DI UJUNG KANAN)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Data Pelanggan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: JpColors.navy)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneC,
                    keyboardType: TextInputType.phone,
                    onSubmitted: _lookupCustomer,
                    decoration: InputDecoration(
                      labelText: 'No. HP / WhatsApp Pelanggan',
                      hintText: '0812... atau 628...',
                      border: const OutlineInputBorder(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                  if (_searched && _foundMember != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: _foundMember!.photoUrl.isNotEmpty ? NetworkImage(_foundMember!.photoUrl) : null,
                            child: _foundMember!.photoUrl.isEmpty ? const Icon(Icons.person) : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('✅ Pelanggan Terdaftar (Terisi Otomatis)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Tier: ${_foundMember!.tier} • Poin: ${_foundMember!.points} pts', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                Text('Referral: ${_foundMember!.referralCode} • Email: ${_foundMember!.email.isEmpty ? "-" : _foundMember!.email}', style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
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
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        '🆕 Pelanggan Baru: Cukup isi Nama & No. HP. Sistem otomatis mendaftarkan akun default, dan password diatur pelanggan via Lupa Password (Reverse OTP).',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: JpColors.navy),
                      ),
                    ),
                  TextField(
                    controller: _nameC,
                    decoration: const InputDecoration(labelText: 'Nama Pelanggan', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // BAGIAN 2: DETAIL UNIT, KERUSAKAN, PERBAIKAN, HARGA & GARANSI
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2. Detail Perangkat & Biaya', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: JpColors.navy)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _quickBrands.map((b) => ActionChip(label: Text(b, style: const TextStyle(fontSize: 12)), onPressed: () => setState(() => _brandC.text = b))).toList(),
                  ),
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
                  TextField(controller: _repairC, maxLines: 2, decoration: const InputDecoration(labelText: 'Perbaikan / Sparepart Diganti', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga (Rp)', border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      SizedBox(width: 120, child: TextField(controller: _warrantyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Garansi (Hari)', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: _quickWarranties.map((w) => ActionChip(label: Text('$w Hr', style: const TextStyle(fontSize: 11.5)), onPressed: () => setState(() => _warrantyC.text = w))).toList(),
                  ),
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
                      label: Text(_photoUrl.isEmpty ? 'Upload Foto Kondisi HP (Cloudinary)' : 'Ganti Foto Kondisi HP'),
                    ),
                  ),
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

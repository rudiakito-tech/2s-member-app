import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cloudinary_service.dart';
import 'data_store.dart';
import 'jp_theme_widgets.dart';

class ServiceProgressPage extends StatefulWidget {
  final AppDataController ctrl;
  final ServiceOrder order;
  final bool isAdmin;

  const ServiceProgressPage({
    super.key,
    required this.ctrl,
    required this.order,
    required this.isAdmin,
  });

  @override
  State<ServiceProgressPage> createState() => _ServiceProgressPageState();
}

class _ServiceProgressPageState extends State<ServiceProgressPage> {
  late String _status;
  late String _paymentStatus;
  late String _sparepartSource;
  late String _beforePhotoUrl;
  late String _afterPhotoUrl;

  late final TextEditingController _damageC;
  late final TextEditingController _repairC;
  late final TextEditingController _techNoteC;
  late final TextEditingController _priceC;
  late final TextEditingController _paidC;
  late final TextEditingController _warrantyC;
  late final TextEditingController _spCostC;
  late final TextEditingController _spNoteC;

  bool _uploadingBefore = false;
  bool _uploadingAfter = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.order;
    _status = widget.ctrl.normalizeStage(s.status);
    _paymentStatus = {'Lunas', 'DP', 'Belum Bayar'}.contains(s.paymentStatus) ? s.paymentStatus : 'Belum Bayar';
    _sparepartSource = s.sparepartSource == 'TF dari Owner' ? 'TF dari Owner' : 'Kas Toko';
    _beforePhotoUrl = s.beforePhotoUrl;
    _afterPhotoUrl = s.afterPhotoUrl;

    _damageC = TextEditingController(text: s.complaint);
    _repairC = TextEditingController(text: s.replacedPart);
    _techNoteC = TextEditingController(text: s.techNote);
    _priceC = TextEditingController(text: s.totalCost.toString());
    _paidC = TextEditingController(text: s.paidAmount.toString());
    _warrantyC = TextEditingController(text: s.warrantyDays.toString());
    _spCostC = TextEditingController(text: s.sparepartCost.toString());
    _spNoteC = TextEditingController(text: s.sparepartNote);
  }

  @override
  void dispose() {
    for (final c in [_damageC, _repairC, _techNoteC, _priceC, _paidC, _warrantyC, _spCostC, _spNoteC]) {
      c.dispose();
    }
    super.dispose();
  }

  int _parseInt(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  Future<void> _uploadPhoto({required bool isBefore}) async {
    setState(() {
      if (isBefore) {
        _uploadingBefore = true;
      } else {
        _uploadingAfter = true;
      }
    });
    final res = await CloudinaryService.pickAndUpload(context, folder: '2s_member/services');
    if (!mounted) return;
    setState(() {
      if (isBefore) {
        _uploadingBefore = false;
        if (res?.url != null) _beforePhotoUrl = res!.url!;
      } else {
        _uploadingAfter = false;
        if (res?.url != null) _afterPhotoUrl = res!.url!;
      }
    });
    if (res?.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res!.error!)));
    }
  }

  Future<void> _saveUpdate({bool closeAfter = true}) async {
    final total = _parseInt(_priceC);
    final paid = _paymentStatus == 'Lunas' ? total : (_paymentStatus == 'DP' ? _parseInt(_paidC) : 0);
    setState(() => _saving = true);
    await widget.ctrl.updateServiceProgress(
      widget.order,
      status: _status,
      complaint: _damageC.text,
      repairAction: _repairC.text,
      totalCost: total,
      warrantyDays: _parseInt(_warrantyC) == 0 && _warrantyC.text.trim() != '0' ? 30 : _parseInt(_warrantyC),
      paymentStatus: _paymentStatus,
      paidAmount: paid,
      beforePhotoUrl: _beforePhotoUrl,
      afterPhotoUrl: _afterPhotoUrl,
      sparepartCost: _parseInt(_spCostC),
      sparepartSource: _sparepartSource,
      sparepartNote: _spNoteC.text,
      techNote: _techNoteC.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progres servis berhasil disimpan!')));
    if (closeAfter) Navigator.pop(context);
  }

  Future<void> _contactCustomerWa(String type) async {
    final s = widget.order;
    if (s.customerPhone.startsWith('TEMP-')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pelanggan memakai ID TEMP (belum ada No. WA).')));
      return;
    }
    final phone = widget.ctrl.normalizePhone(s.customerPhone);
    if (phone.length < 9) return;

    final nama = s.customerName.isEmpty ? 'Kak' : s.customerName;
    final total = _parseInt(_priceC);
    final paid = _paymentStatus == 'Lunas' ? total : (_paymentStatus == 'DP' ? _parseInt(_paidC) : 0);
    final sisa = (total - paid) < 0 ? 0 : (total - paid);
    final noteLine = _techNoteC.text.trim().isNotEmpty ? '\nCatatan Teknisi: ${_techNoteC.text.trim()}' : '';

    String msg;
    if (type == 'status') {
      msg = 'Halo $nama, kami dari *2S Service Handphone* mengabarkan update servis unit *${s.fullDeviceName}* (Nota: ${s.invoiceNo}):\n\n'
          'Status Saat Ini: *$_status*$noteLine\n\n'
          'Terima kasih telah mempercayakan unit Anda kepada kami.';
    } else if (type == 'redeal') {
      msg = 'Halo $nama, kami dari *2S Service Handphone* ingin mengonfirmasi hasil pengecekan unit *${s.fullDeviceName}* (Nota: ${s.invoiceNo}):\n\n'
          'Kerusakan: ${_damageC.text.trim()}$noteLine\n'
          'Rencana Perbaikan: ${_repairC.text.trim()}\n'
          'Fix Biaya Perbaikan: *${widget.ctrl.formatRupiah(total)}*\n'
          'Garansi: ${_warrantyC.text.trim()} Hari\n\n'
          'Mohon konfirmasinya apakah lanjut kami kerjakan sesuai rincian & harga tersebut ya Kak?';
    } else {
      final claimLine = (!s.claimUsed && s.claimCode.isNotEmpty) ? '\nKode Klaim: ${s.claimCode}' : '';
      msg = '*e-Nota & Update 2S Service Handphone*\n'
          'No. Nota  : ${s.invoiceNo}\n'
          'Tgl/Jam   : ${widget.ctrl.formatDateTime(s.createdAt)}\n'
          'Pelanggan : $nama\n'
          'Unit HP   : ${s.fullDeviceName}\n'
          'Kerusakan : ${_damageC.text.trim()}\n'
          'Perbaikan : ${_repairC.text.trim()}\n'
          'Status    : *$_status*\n'
          'Garansi   : ${_warrantyC.text.trim()} Hari\n'
          'Total     : *${widget.ctrl.formatRupiah(total)}*\n'
          'Pembayaran: $_paymentStatus (Dibayar: ${widget.ctrl.formatRupiah(paid)}, Sisa: ${widget.ctrl.formatRupiah(sisa)})$claimLine';
    }

    final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.order;
    final stages = AppDataController.serviceStages;
    final curIdx = stages.indexOf(_status);
    final total = _parseInt(_priceC);
    final paid = _paymentStatus == 'Lunas' ? total : (_paymentStatus == 'DP' ? _parseInt(_paidC) : 0);
    final sisa = (total - paid) < 0 ? 0 : (total - paid);
    final spCost = _parseInt(_spCostC);
    final grossProfit = total - spCost;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: JpColors.creamLight,
        title: Text(widget.isAdmin ? 'Kelola Progres ${s.invoiceNo}' : 'Progres ${s.invoiceNo}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: JpColors.navy)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. STEPPER PROGRES 5 TAHAP
          Card(
            color: JpColors.navy,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.fullDeviceName} • ${s.customerName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${widget.ctrl.formatDateTime(s.createdAt)} • WA: ${s.customerPhone}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 14),
                  Row(
                    children: List.generate(stages.length, (i) {
                      final active = i <= curIdx;
                      return Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: active ? JpColors.gold : Colors.white24,
                              child: Icon(active ? Icons.check : Icons.circle, size: 14, color: active ? JpColors.navy : Colors.white54),
                            ),
                            const SizedBox(height: 4),
                            Text(stages[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? JpColors.gold : Colors.white60)),
                          ],
                        ),
                      );
                    }),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 12),
                    const Text('Ubah Status Progres:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: stages.map((st) {
                        final selected = _status == st;
                        return ChoiceChip(
                          label: Text(st, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? JpColors.navy : Colors.black87)),
                          selected: selected,
                          selectedColor: JpColors.gold,
                          onSelected: (_) => setState(() => _status = st),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. FOTO BEFORE & AFTER
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Foto Kondisi HP (Before & After)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: JpColors.navy)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _photoBox(title: 'BEFORE (Masuk)', url: _beforePhotoUrl, uploading: _uploadingBefore, canEdit: widget.isAdmin, onTap: () => _uploadPhoto(isBefore: true))),
                      const SizedBox(width: 10),
                      Expanded(child: _photoBox(title: 'AFTER (Selesai)', url: _afterPhotoUrl, uploading: _uploadingAfter, canEdit: widget.isAdmin, onTap: () => _uploadPhoto(isBefore: false))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. DETAIL SERVIS, RE-DEAL HARGA & PEMBAYARAN
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rincian Kerusakan, Harga & Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: JpColors.navy)),
                  const SizedBox(height: 10),
                  if (widget.isAdmin) ...[
                    TextField(controller: _damageC, maxLines: 2, decoration: const InputDecoration(labelText: 'Kerusakan (bisa diperbarui setelah dicek)', border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    TextField(controller: _techNoteC, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan Konfirmasi / Re-deal Pelanggan', border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    TextField(controller: _repairC, maxLines: 2, decoration: const InputDecoration(labelText: 'Perbaikan / Sparepart', border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _priceC, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Fix Harga Baru (Rp)', border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        SizedBox(width: 110, child: TextField(controller: _warrantyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Garansi (Hr)', border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Status Pembayaran (Otomatis Masuk Kas Toko):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
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
                      const SizedBox(height: 8),
                      TextField(controller: _paidC, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Nominal DP / Sudah Dibayar (Rp)', border: OutlineInputBorder())),
                    ],
                    const SizedBox(height: 6),
                    Text('Masuk Kas Toko: ${widget.ctrl.formatRupiah(paid)} • Sisa Tagihan: ${widget.ctrl.formatRupiah(sisa)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E56A0), fontSize: 12.5)),
                  ] else ...[
                    Text('Kerusakan: ${s.complaint}'),
                    if (s.techNote.isNotEmpty) Text('Catatan Teknisi: ${s.techNote}', style: const TextStyle(color: Color(0xFF1E56A0), fontWeight: FontWeight.w600)),
                    Text('Perbaikan: ${s.replacedPart}'),
                    Text('Garansi  : ${s.warrantyDays} Hari (Sisa ${s.remainingWarrantyDays} hari)'),
                    const Divider(),
                    Text('Total Biaya: ${widget.ctrl.formatRupiah(s.totalCost)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Pembayaran: ${s.paymentStatus} • Sudah Bayar: ${widget.ctrl.formatRupiah(s.paidAmount)} • Sisa: ${widget.ctrl.formatRupiah(s.remainingPayment)}', style: TextStyle(fontWeight: FontWeight.bold, color: s.remainingPayment == 0 ? Colors.green : Colors.orange[800])),
                  ],
                ],
              ),
            ),
          ),

          // 4. KHUSUS ADMIN: MODAL SPAREPART, SUMBER DANA & HUBUNGI PELANGGAN
          if (widget.isAdmin) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.amber.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Modal Sparepart & Sumber Dana (Internal Kasir)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: JpColors.navy)),
                    const SizedBox(height: 10),
                    TextField(controller: _spCostC, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Biaya Beli Sparepart (Rp)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
                    const SizedBox(height: 8),
                    TextField(controller: _spNoteC, decoration: const InputDecoration(labelText: 'Rincian Beli Sparepart (opsional)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
                    const SizedBox(height: 10),
                    const Text('Sumber Dana Beli Sparepart:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Kas Toko', label: Text('Kas Toko')),
                        ButtonSegment(value: 'TF dari Owner', label: Text('TF dari Owner')),
                      ],
                      selected: {_sparepartSource},
                      onSelectionChanged: (v) => setState(() => _sparepartSource = v.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Estimasi Laba Kotor: ${widget.ctrl.formatRupiah(grossProfit)}',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: grossProfit >= 0 ? Colors.green[800] : Colors.red),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Hubungi / Kabari Pelanggan via WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: JpColors.navy)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: () => _contactCustomerWa('status'), icon: const Icon(Icons.notifications_active, color: Colors.blue), label: const Text('Kabari Status Terakhir')),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(onPressed: () => _contactCustomerWa('redeal'), icon: const Icon(Icons.handshake, color: Colors.orange), label: const Text('Konfirmasi Kerusakan & Deal Harga Baru')),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(onPressed: () => _contactCustomerWa('nota'), icon: const Icon(Icons.chat, color: Colors.green), label: const Text('Kirim e-Nota & Status Pembayaran')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: JpColors.orange, foregroundColor: Colors.white),
                onPressed: _saving || _uploadingBefore || _uploadingAfter ? null : () => _saveUpdate(closeAfter: true),
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan Update Progres', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _photoBox({required String title, required String url, required bool uploading, required bool canEdit, required VoidCallback onTap}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
          child: url.isNotEmpty
              ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.network(url, fit: BoxFit.cover))
              : const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 32)),
        ),
        if (canEdit)
          TextButton.icon(
            onPressed: uploading ? null : onTap,
            icon: uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt, size: 16),
            label: Text(url.isEmpty ? 'Upload' : 'Ganti', style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
// AKHIR FILE service_progress_page.dart

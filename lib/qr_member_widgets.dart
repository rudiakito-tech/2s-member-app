import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'data_store.dart';
import 'jp_theme_widgets.dart';

void showMemberQrDialog(BuildContext context, MemberUser user) {
  final qrPayload = '2SMEMBER|${user.phone}';
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Kartu QR 2S Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: JpColors.navy)),
            const SizedBox(height: 4),
            const Text('Tunjukkan QR ini ke Kasir saat servis / belanja', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: JpColors.navyMuted)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: JpColors.gold, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)],
              ),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 205,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Text(user.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: JpColors.navy)),
            Text('WA: ${user.phone} • ${user.tier} (${user.points} pts)', style: const TextStyle(fontSize: 12.5, color: JpColors.navyMuted)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
            ),
          ],
        ),
      ),
    ),
  );
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _camCtrl = MobileScannerController();
  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _camCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Member 2S'),
        actions: [
          IconButton(
            onPressed: () async {
              await _camCtrl.toggleTorch();
              if (mounted) setState(() => _torchOn = !_torchOn);
            },
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: _torchOn ? Colors.amber : Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _camCtrl,
            onDetect: (capture) {
              if (_handled) return;
              for (final b in capture.barcodes) {
                final val = b.rawValue;
                if (val != null && val.trim().isNotEmpty) {
                  _handled = true;
                  Navigator.of(context).pop(val.trim());
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: JpColors.gold, width: 3),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'Arahkan kamera ke QR Code pada layar HP pelanggan 2S Member',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:firebase_core/firebase_core.dart';

class AppConfig {
  static const String appName = '2S Member';
  static const String shopName = '2S Service Handphone';

  // Pastikan true jika 4 kode Firebase di bawah sudah diisi
  static const bool useFirebase = true;

  // Daftar Nomor WhatsApp Admin/Kasir (format 08... atau 628...)
  static const List<String> adminPhones = [
    '081234567890', // GANTI dengan nomor WA Anda
  ];

  // Konfigurasi Cloudinary (untuk Tahap 2B nanti)
  static const String cloudinaryCloudName = 'ISI_CLOUD_NAME_ANDA';
  static const String cloudinaryUploadPreset = 'ISI_UPLOAD_PRESET_ANDA';

  // Konfigurasi Firebase Android (dari google-services.json)
  static const FirebaseOptions firebaseAndroidOptions = FirebaseOptions(
    apiKey: 'AIzaSyAjl__6_vVoRlD1tqXVQBCmSPume2yjfzk',
    appId: '1:514037486909:android:393b7c1f0f0c123580e154',
    messagingSenderId: '514037486909',
    projectId: 'fir-member-78791',
  );

  static String normalizePhone(String raw) {
    var p = raw.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('0')) p = '62${p.substring(1)}';
    if (p.startsWith('8')) p = '62$p';
    return p;
  }
}

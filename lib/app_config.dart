import 'package:firebase_core/firebase_core.dart';

class AppConfig {
  static const String appName = '2S Member';
  static const String shopName = '2S Service Handphone';

  // Pastikan tetap true
  static const bool useFirebase = true;

  // WAJIB GANTI dengan nomor WA yang terhubung ke Fonnte (format 628..., tanpa + atau spasi)
  static const String businessWaNumber = '62895414593299';

  // Konfigurasi Cloudinary (untuk upload foto di tahap berikutnya)
  static const String cloudinaryCloudName = 'ISI_CLOUD_NAME_ANDA';
  static const String cloudinaryUploadPreset = 'ISI_UPLOAD_PRESET_ANDA';

  // BIARKAN kode Firebase Anda yang sudah benar di sini:
  static const FirebaseOptions firebaseAndroidOptions = FirebaseOptions(
    apiKey: 'AIzaSyAjl__6_vVoRlD1tqXVQBCmSPume2yjfzk',
    appId: '1:514037486909:android:393b7c1f0f0c123580e154',
    messagingSenderId: '514037486909',
    projectId: 'fir-member-78791',
  );
}

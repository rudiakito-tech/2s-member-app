import 'package:firebase_core/firebase_core.dart';

class AppConfig {
  static const String appName = '2S Member';
  static const String shopName = '2S Service Handphone';

  // Pastikan tetap true
  static const bool useFirebase = true;

  // WAJIB GANTI dengan nomor WA yang terhubung ke Fonnte (format 628..., tanpa + atau spasi)
  static const String businessWaNumber = '6281234567890';

  // Konfigurasi Cloudinary (untuk upload foto di tahap berikutnya)
  static const String cloudinaryCloudName = 'ISI_CLOUD_NAME_ANDA';
  static const String cloudinaryUploadPreset = 'ISI_UPLOAD_PRESET_ANDA';

  // BIARKAN kode Firebase Anda yang sudah benar di sini:
  static const FirebaseOptions firebaseAndroidOptions = FirebaseOptions(
    apiKey: 'ISI_API_KEY_ANDA',
    appId: 'ISI_APP_ID_ANDA',
    messagingSenderId: 'ISI_SENDER_ID_ANDA',
    projectId: 'ISI_PROJECT_ID_ANDA',
  );
}

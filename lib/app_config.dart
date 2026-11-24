import 'package:firebase_core/firebase_core.dart';

class AppConfig {
  static const String appName = '2S Member';
  static const String shopName = '2S Service Handphone';

  // Ubah ke true jika sudah mengisi konfigurasi Firebase di bawah
  static const bool useFirebase = false;

  // Konfigurasi Cloudinary (Gratis tanpa kartu kredit) untuk upload foto nanti
  static const String cloudinaryCloudName = 'ISI_CLOUD_NAME_ANDA';
  static const String cloudinaryUploadPreset = 'ISI_UPLOAD_PRESET_ANDA';

  // Konfigurasi Firebase Android (diambil dari Firebase Console -> Project Settings)
  static const FirebaseOptions firebaseAndroidOptions = FirebaseOptions(
    apiKey: 'ISI_API_KEY',
    appId: 'ISI_APP_ID',
    messagingSenderId: 'ISI_SENDER_ID',
    projectId: 'ISI_PROJECT_ID',
  );
}

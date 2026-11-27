import 'package:firebase_core/firebase_core.dart';

class AppConfig {
  static const String appName = '2S Member';
  static const String shopName = '2S Service Handphone';
  static const bool useFirebase = true;

  // Nomor WA toko yang terhubung ke Fonnte (format 628...)
  static const String businessWaNumber = '62895414593299';

  // Daftar nomor WA Admin/Kasir
  static const List<String> adminWaNumbers = [
    '6287878078074',
  ];

  // WAJIB ISI dari Firebase Console -> Authentication -> Google -> Web SDK configuration -> Web client ID
  static const String googleWebClientId = '514037486909-4k706d8cu25l6a3tg1cgl25oo3dl7p4j.apps.googleusercontent.com';

  static const String cloudinaryCloudName = 'dlz7e6vnx';
  static const String cloudinaryUploadPreset = 'member-service-upload';

  // BIARKAN kode Firebase Anda yang sudah terisi di sini:
  static const FirebaseOptions firebaseAndroidOptions = FirebaseOptions(
    apiKey: 'AIzaSyAjl__6_vVoRlD1tqXVQBCmSPume2yjfzk',
    appId: '1:514037486909:android:393b7c1f0f0c123580e154',
    messagingSenderId: '514037486909',
    projectId: 'fir-member-78791',
  );
}

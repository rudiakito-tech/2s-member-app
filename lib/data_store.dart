import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';

class MemberUser {
  String id, name, phone, email, photoUrl, referralCode, claimedMissionDate;
  bool isEmailVerified, isWaVerified, emailMissionClaimed;
  int points, checkInStreak;
  DateTime? lastCheckInDate, lastSpinDate;
  List<String> claimedDailyMissions;

  MemberUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.photoUrl = '',
    this.isEmailVerified = false,
    this.isWaVerified = true,
    this.emailMissionClaimed = false,
    this.points = 150,
    required this.referralCode,
    this.checkInStreak = 0,
    this.lastCheckInDate,
    this.lastSpinDate,
    this.claimedMissionDate = '',
    this.claimedDailyMissions = const [],
  });

  String get tier {
    if (points >= 2000) return 'Platinum';
    if (points >= 1000) return 'Gold';
    if (points >= 400) return 'Silver';
    return 'Bronze';
  }
}

class ServiceOrder {
  final String id, invoiceNo, customerPhone, customerName, brand, deviceType, deviceName, complaint, replacedPart, photoUrl, claimCode;
  String status;
  final int totalCost, warrantyDays;
  final DateTime createdAt;
  bool warrantyClaimed, claimUsed;

  ServiceOrder({
    required this.id,
    required this.invoiceNo,
    required this.customerPhone,
    this.customerName = '',
    this.brand = '',
    this.deviceType = '',
    required this.deviceName,
    required this.complaint,
    required this.replacedPart,
    this.photoUrl = '',
    this.claimCode = '',
    this.claimUsed = false,
    required this.status,
    required this.totalCost,
    required this.createdAt,
    this.warrantyDays = 30,
    this.warrantyClaimed = false,
  });

  String get fullDeviceName {
    final combined = '$brand $deviceType'.trim();
    return combined.isNotEmpty ? combined : deviceName;
  }

  DateTime get warrantyExpiredAt => createdAt.add(Duration(days: warrantyDays));
  int get remainingWarrantyDays {
    final diff = warrantyExpiredAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }
}

class StoreProduct {
  final String id, name, category, photoUrl;
  final int price, discountPercent, stock;

  StoreProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.discountPercent = 0,
    this.stock = 10,
    this.photoUrl = '',
  });

  int get finalPrice => (price * (100 - discountPercent) / 100).round();
}

class VoucherItem {
  final String id, code;
  final int discountAmount, minSpend;
  final bool isActive;

  VoucherItem({
    required this.id,
    required this.code,
    required this.discountAmount,
    required this.minSpend,
    this.isActive = true,
  });
}

class StoreOrder {
  final String id, orderNo, customerPhone, customerName, productName, voucherCode, deliveryType;
  String status;
  final int finalTotal, pointsUsed;
  final DateTime createdAt;

  StoreOrder({
    required this.id,
    required this.orderNo,
    required this.customerPhone,
    required this.customerName,
    required this.productName,
    required this.finalTotal,
    this.pointsUsed = 0,
    this.voucherCode = '',
    required this.deliveryType,
    required this.status,
    required this.createdAt,
  });
}

class PointHistory {
  final String title;
  final int amount;
  final DateTime date;
  PointHistory(this.title, this.amount, this.date);
}

class OtpStartResult {
  final String? code;
  final String? expectedPhone;
  final String? error;
  OtpStartResult({this.code, this.expectedPhone, this.error});
}

class GoogleAuthResult {
  final bool loggedIn;
  final bool needsWaRegistration;
  final String? email;
  final String? name;
  final String? error;
  GoogleAuthResult({
    this.loggedIn = false,
    this.needsWaRegistration = false,
    this.email,
    this.name,
    this.error,
  });
}

class AppDataController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  MemberUser? currentUser;
  bool isInitialized = false;
  bool isAdminMode = false;
  int extraStoreDiscount = 0;

  bool _googleReady = false;
  bool _seededProducts = false;
  String? pendingGoogleEmail;
  String? pendingGoogleName;
  String? pendingRegisterPhotoUrl;
  String? verifiedResetPhone;

  StreamSubscription<DocumentSnapshot>? _otpSub;
  StreamSubscription<QuerySnapshot>? _srvSub;
  StreamSubscription<QuerySnapshot>? _prodSub;
  StreamSubscription<QuerySnapshot>? _vouchSub;
  StreamSubscription<QuerySnapshot>? _ordSub;

  List<ServiceOrder> services = [];
  List<StoreProduct> products = [];
  List<VoucherItem> vouchers = [];
  List<StoreOrder> storeOrders = [];
  List<PointHistory> pointHistories = [];
  List<Map<String, dynamic>> leaderboard = [];

  bool get isGuest => currentUser == null;
  bool get canUseAdmin => !isGuest && AppConfig.adminWaNumbers.contains(currentUser!.phone);

  String get todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime? d) {
    if (d == null) return false;
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  String normalizePhone(String p) {
    var d = p.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0')) d = '62${d.substring(1)}';
    return d;
  }

  String _hashPassword(String phone, String password) {
    final bytes = utf8.encode('2S_HP_SALT_${phone}_$password');
    return sha256.convert(bytes).toString();
  }

  String formatRupiah(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  String formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y • $hh:$mm';
  }

  String buildWaOtpMessage(String code) {
    return '*Konfirmasi Akun 2S Member*\n\n'
        'Pesan ini digunakan untuk mengonfirmasi kepemilikan nomor WhatsApp akun Anda. '
        'Setelah mengirim pesan ini, silakan buka kembali aplikasi *2S Member*.\n\n'
        'Kode Verifikasi: *$code*';
  }

  Future<String> checkPhoneAccountStatus(String rawInput) async {
    final trimmed = rawInput.trim();
    if (trimmed.contains('@')) return 'email';
    final phone = normalizePhone(trimmed);
    if (phone.length < 10) return 'incomplete';
    try {
      final doc = await _db.collection('users').doc(phone).get();
      if (!doc.exists) return 'not_found';
      final hasPass = (doc.data()?['passwordHash'] ?? '').toString().isNotEmpty;
      return hasPass ? 'has_password' : 'no_password';
    } catch (_) {
      return 'error';
    }
  }

  Future<void> initSession() async {
    try {
      _listenStoreCatalog();
      await _loadLeaderboard();
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('2s_logged_phone');
      if (savedPhone != null && savedPhone.isNotEmpty) {
        final doc = await _db.collection('users').doc(savedPhone).get();
        if (doc.exists) {
          await _applyLoggedInUser(savedPhone, doc.data()!);
        }
      }
    } catch (_) {}
    isInitialized = true;
    notifyListeners();
  }

  void _listenStoreCatalog() {
    _prodSub?.cancel();
    _prodSub = _db.collection('products').orderBy('name').snapshots().listen((snap) async {
      if (snap.docs.isEmpty && !_seededProducts) {
        _seededProducts = true;
        final batch = _db.batch();
        final starter = [
          {'name': 'Kabel Data Fast Charging 65W', 'category': 'Aksesoris', 'price': 65000, 'discountPercent': 20, 'stock': 15, 'photoUrl': ''},
          {'name': 'Tempered Glass Anti-Spy', 'category': 'Pelindung', 'price': 45000, 'discountPercent': 10, 'stock': 25, 'photoUrl': ''},
          {'name': 'Charger Adapter GaN 33W', 'category': 'Charger', 'price': 150000, 'discountPercent': 15, 'stock': 8, 'photoUrl': ''},
        ];
        for (final p in starter) {
          batch.set(_db.collection('products').doc(), p);
        }
        await batch.commit();
        return;
      }
      products = snap.docs.map((doc) {
        final d = doc.data();
        return StoreProduct(
          id: doc.id,
          name: d['name'] ?? '-',
          category: d['category'] ?? 'Umum',
          price: (d['price'] ?? 0) as int,
          discountPercent: (d['discountPercent'] ?? 0) as int,
          stock: (d['stock'] ?? 0) as int,
          photoUrl: d['photoUrl'] ?? '',
        );
      }).toList();
      notifyListeners();
    });

    _vouchSub?.cancel();
    _vouchSub = _db.collection('vouchers').snapshots().listen((snap) {
      vouchers = snap.docs.map((doc) {
        final d = doc.data();
        return VoucherItem(
          id: doc.id,
          code: (d['code'] ?? '').toString().toUpperCase(),
          discountAmount: (d['discountAmount'] ?? 0) as int,
          minSpend: (d['minSpend'] ?? 0) as int,
          isActive: d['isActive'] ?? true,
        );
      }).toList();
      notifyListeners();
    });
  }

  Future<String?> loginWithPassword(String rawInput, String password, {bool rememberMe = true}) async {
    final input = rawInput.trim();
    if (input.contains('@')) return loginWithGmail(input, password, rememberMe: rememberMe);

    final phone = normalizePhone(input);
    if (phone.length < 9) return 'Nomor WhatsApp / Email tidak valid.';
    if (password.length < 6) return 'Password minimal 6 karakter.';

    final doc = await _db.collection('users').doc(phone).get();
    if (!doc.exists) return 'Nomor WA belum terdaftar. Silakan Daftar Sekarang.';

    final data = doc.data()!;
    final storedHash = (data['passwordHash'] ?? '').toString();
    if (storedHash.isEmpty) return 'PASSWORD_NOT_SET';
    if (storedHash != _hashPassword(phone, password)) return 'Password salah!';

    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('2s_logged_phone', phone);
    } else {
      await prefs.remove('2s_logged_phone');
    }
    await _applyLoggedInUser(phone, data);
    return null;
  }

  Future<String?> loginWithGmail(String rawEmail, String password, {bool rememberMe = true}) async {
    final email = rawEmail.trim().toLowerCase();
    if (!email.contains('@')) return 'Alamat email tidak valid.';
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      if (cred.user == null) return 'Gagal login email.';
      if (!cred.user!.emailVerified) {
        await cred.user!.sendEmailVerification();
        return 'Email belum diverifikasi. Link baru dikirim ke Inbox/Spam Anda.';
      }
      final q = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
      if (q.docs.isEmpty) return 'Email belum tertaut ke nomor WA. Masuk pakai No. WA dulu.';
      final userDoc = q.docs.first;
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString('2s_logged_phone', userDoc.id);
      } else {
        await prefs.remove('2s_logged_phone');
      }
      await _applyLoggedInUser(userDoc.id, userDoc.data());
      return null;
    } on FirebaseAuthException catch (e) {
      return 'Gagal login: ${e.message}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<GoogleAuthResult> signInWithGoogleButton() async {
    if (AppConfig.googleWebClientId.contains('ISI_WEB_CLIENT_ID')) {
      return GoogleAuthResult(error: 'googleWebClientId di app_config.dart belum diisi!');
    }
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(serverClientId: AppConfig.googleWebClientId);
        _googleReady = true;
      }
      final GoogleSignInAccount? account = await GoogleSignIn.instance.authenticate();
      if (account == null) return GoogleAuthResult(error: 'Login Google dibatalkan.');

      final idToken = account.authentication.idToken;
      if (idToken == null) return GoogleAuthResult(error: 'Token Google kosong. Cek Web Client ID & SHA-1.');

      await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      final email = account.email.trim().toLowerCase();
      final q = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();

      if (q.docs.isNotEmpty) {
        final userDoc = q.docs.first;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('2s_logged_phone', userDoc.id);
        await _applyLoggedInUser(userDoc.id, userDoc.data());
        return GoogleAuthResult(loggedIn: true, email: email);
      }

      pendingGoogleEmail = email;
      pendingGoogleName = account.displayName ?? '';
      return GoogleAuthResult(needsWaRegistration: true, email: email, name: pendingGoogleName);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return GoogleAuthResult(error: 'Login Google dibatalkan.');
      return GoogleAuthResult(error: 'Google Sign-In gagal (${e.code.name}): ${e.description ?? "Cek SHA-1"}');
    } catch (e) {
      return GoogleAuthResult(error: 'Error Google Sign-In: $e');
    }
  }

  // REVERSE OTP WA: mode 'register', 'reset', atau 'claim' (Klaim Nota / Ubah Nomor)
  Future<OtpStartResult> startReverseOtp({
    required String mode,
    required String rawPhone,
    String name = '',
    String password = '',
    String refCode = '',
    String claimInvoice = '',
    String claimCode = '',
    required void Function(String wrongPhone) onMismatch,
    required void Function(String? error) onCompleted,
  }) async {
    final expectedPhone = normalizePhone(rawPhone);
    if (expectedPhone.length < 9) return OtpStartResult(error: 'Nomor WhatsApp wajib diisi dengan benar.');

    String? claimServiceDocId;
    String? claimOldPhone;

    if (mode == 'claim') {
      final inv = claimInvoice.trim().toUpperCase();
      final cCode = claimCode.trim().toUpperCase();
      if (inv.isEmpty || cCode.length < 6) {
        return OtpStartResult(error: 'Masukkan No. Nota dan 6 digit Kode Klaim dengan benar.');
      }
      final srvSnap = await _db.collection('services').where('invoiceNo', isEqualTo: inv).limit(1).get();
      if (srvSnap.docs.isEmpty) {
        return OtpStartResult(error: 'Nomor Nota $inv tidak ditemukan.');
      }
      final srvDoc = srvSnap.docs.first;
      final sd = srvDoc.data();
      if ((sd['claimCode'] ?? '').toString().toUpperCase() != cCode) {
        return OtpStartResult(error: 'Kode Klaim tidak cocok untuk nota $inv.');
      }
      if (sd['claimUsed'] == true) {
        return OtpStartResult(error: 'Kode Klaim nota $inv sudah pernah digunakan.');
      }
      final oldPhone = (sd['customerPhone'] ?? '').toString();
      if (oldPhone.isNotEmpty && oldPhone != expectedPhone) {
        final oldUserDoc = await _db.collection('users').doc(oldPhone).get();
        if (oldUserDoc.exists && (oldUserDoc.data()?['passwordHash'] ?? '').toString().isNotEmpty) {
          return OtpStartResult(error: 'Nota ini terhubung ke akun aktif ber-password. Hubungi Admin 2S Service untuk keamanan.');
        }
      }
      claimServiceDocId = srvDoc.id;
      claimOldPhone = oldPhone;
    } else {
      final existing = await _db.collection('users').doc(expectedPhone).get();
      if (mode == 'register' && existing.exists) {
        final hasPass = (existing.data()?['passwordHash'] ?? '').toString().isNotEmpty;
        if (hasPass) {
          return OtpStartResult(error: 'Nomor WA $expectedPhone sudah terdaftar! Silakan langsung Login.');
        }
        return OtpStartResult(error: 'PASSWORD_NOT_SET');
      }
      if (mode == 'reset' && !existing.exists) {
        return OtpStartResult(error: 'Nomor WA $expectedPhone belum terdaftar! Silakan Daftar Akun.');
      }
    }

    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    final code = List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();

    final sessionDoc = await _db.collection('otp_sessions').add({
      'code': code,
      'mode': mode,
      'expectedPhone': expectedPhone,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    Timestamp? lastMismatchTs;
    await _otpSub?.cancel();
    _otpSub = sessionDoc.snapshots().listen((snap) async {
      final d = snap.data();
      if (d == null) return;
      if (d['status'] == 'pending' && d['mismatchSender'] != null) {
        final ts = d['mismatchAt'] as Timestamp?;
        if (ts != null && ts != lastMismatchTs) {
          lastMismatchTs = ts;
          onMismatch(d['mismatchSender'].toString());
        }
        return;
      }
      if (d['status'] == 'verified') {
        final phone = normalizePhone(d['phone'] ?? '');
        if (phone != expectedPhone) {
          onMismatch(phone);
          return;
        }
        await _otpSub?.cancel();
        final waName = (d['waName'] ?? '').toString();
        final err = await _finishWaVerification(
          mode: mode,
          phone: phone,
          name: name.trim().isNotEmpty ? name.trim() : (waName.isNotEmpty ? waName : 'Member 2S'),
          password: password,
          refCode: refCode.trim().toUpperCase(),
          claimServiceDocId: claimServiceDocId,
          claimOldPhone: claimOldPhone,
        );
        onCompleted(err);
      }
    });

    return OtpStartResult(code: code, expectedPhone: expectedPhone);
  }

  Future<void> cancelOtpWait() async => await _otpSub?.cancel();

  Future<String?> _finishWaVerification({
    required String mode,
    required String phone,
    required String name,
    required String password,
    required String refCode,
    String? claimServiceDocId,
    String? claimOldPhone,
  }) async {
    final userRef = _db.collection('users').doc(phone);
    final doc = await userRef.get();

    if (mode == 'claim') {
      final passHash = _hashPassword(phone, password);
      String finalName = name;
      int bonusTransferPts = 150;

      if (claimServiceDocId != null) {
        final sDoc = await _db.collection('services').doc(claimServiceDocId).get();
        final sName = (sDoc.data()?['customerName'] ?? '').toString();
        if (sName.isNotEmpty && finalName == 'Member 2S') finalName = sName;
        await _db.collection('services').doc(claimServiceDocId).update({
          'customerPhone': phone,
          'claimUsed': true,
        });
      }

      if (claimOldPhone != null && claimOldPhone.isNotEmpty && claimOldPhone != phone) {
        // Pindahkan semua nota lain yang memakai ID lama/TEMP ke nomor WA asli
        final otherSrvs = await _db.collection('services').where('customerPhone', isEqualTo: claimOldPhone).get();
        for (final os in otherSrvs.docs) {
          await os.reference.update({'customerPhone': phone});
        }
        final oldDoc = await _db.collection('users').doc(claimOldPhone).get();
        if (oldDoc.exists) {
          bonusTransferPts = (oldDoc.data()?['points'] ?? 150) as int;
          await oldDoc.reference.update({'mergedTo': phone, 'points': 0});
        }
      }

      final suffix = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
      if (!doc.exists) {
        await userRef.set({
          'name': finalName,
          'phone': phone,
          'photoUrl': '',
          'passwordHash': passHash,
          'isWaVerified': true,
          'email': '',
          'isEmailVerified': false,
          'emailMissionClaimed': false,
          'points': bonusTransferPts,
          'referralCode': '2S-$suffix',
          'checkInStreak': 0,
          'lastCheckInDate': null,
          'lastSpinDate': null,
          'claimedMissionDate': '',
          'claimedDailyMissions': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
        await userRef.collection('point_histories').add({
          'title': 'Klaim Nota & Aktivasi Akun 2S',
          'amount': bonusTransferPts,
          'date': FieldValue.serverTimestamp(),
        });
      } else {
        await userRef.update({
          'passwordHash': passHash,
          'isWaVerified': true,
        });
      }

      final fresh = await userRef.get();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('2s_logged_phone', phone);
      await _applyLoggedInUser(phone, fresh.data()!);
      return null;
    }

    if (mode == 'register') {
      final passHash = _hashPassword(phone, password);
      if (doc.exists && (doc.data()?['passwordHash'] ?? '').toString().isNotEmpty) {
        return 'Nomor WA $phone sudah terdaftar! Silakan Login.';
      }
      final suffix = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
      int startPts = 150;
      if (refCode.isNotEmpty) {
        final refSnap = await _db.collection('users').where('referralCode', isEqualTo: refCode).limit(1).get();
        if (refSnap.docs.isNotEmpty) {
          startPts += 50;
          await refSnap.docs.first.reference.update({'points': FieldValue.increment(100)});
          await refSnap.docs.first.reference.collection('point_histories').add({
            'title': 'Komisi Affiliate ($name)',
            'amount': 100,
            'date': FieldValue.serverTimestamp(),
          });
        }
      }
      final hasGoogle = pendingGoogleEmail != null && pendingGoogleEmail!.isNotEmpty;
      if (hasGoogle) startPts += 50;

      await userRef.set({
        'name': name,
        'phone': phone,
        'photoUrl': pendingRegisterPhotoUrl ?? (doc.data()?['photoUrl'] ?? ''),
        'passwordHash': passHash,
        'isWaVerified': true,
        'email': hasGoogle ? pendingGoogleEmail : (doc.data()?['email'] ?? ''),
        'isEmailVerified': hasGoogle ? true : (doc.data()?['isEmailVerified'] ?? false),
        'emailMissionClaimed': doc.data()?['emailMissionClaimed'] ?? false,
        'points': doc.exists ? (doc.data()?['points'] ?? startPts) : startPts,
        'referralCode': doc.data()?['referralCode'] ?? '2S-$suffix',
        'checkInStreak': doc.data()?['checkInStreak'] ?? 0,
        'lastCheckInDate': doc.data()?['lastCheckInDate'],
        'lastSpinDate': doc.data()?['lastSpinDate'],
        'claimedMissionDate': doc.data()?['claimedMissionDate'] ?? '',
        'claimedDailyMissions': doc.data()?['claimedDailyMissions'] ?? [],
        'createdAt': doc.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!doc.exists) {
        await userRef.collection('point_histories').add({
          'title': hasGoogle ? 'Bonus Daftar + Google Terverifikasi' : 'Bonus Member Baru 2S',
          'amount': startPts,
          'date': FieldValue.serverTimestamp(),
        });
      }
      pendingGoogleEmail = null;
      pendingGoogleName = null;
      pendingRegisterPhotoUrl = null;

      final fresh = await userRef.get();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('2s_logged_phone', phone);
      await _applyLoggedInUser(phone, fresh.data()!);
      return null;
    } else {
      if (!doc.exists) return 'Nomor WA $phone belum terdaftar.';
      verifiedResetPhone = phone;
      return null;
    }
  }

  Future<String?> saveNewPasswordAfterReset(String newPassword) async {
    final phone = verifiedResetPhone;
    if (phone == null || phone.isEmpty) return 'Sesi verifikasi habis. Ulangi Lupa Password.';
    final doc = await _db.collection('users').doc(phone).get();
    if (!doc.exists) return 'Akun tidak ditemukan.';
    final newHash = _hashPassword(phone, newPassword);
    final oldHash = (doc.data()?['passwordHash'] ?? '').toString();
    if (oldHash.isNotEmpty && newHash == oldHash) return 'Password baru tidak boleh sama dengan password lama.';
    await _db.collection('users').doc(phone).update({'passwordHash': newHash, 'isWaVerified': true});
    verifiedResetPhone = null;
    return null;
  }

  Future<void> _applyLoggedInUser(String phone, Map<String, dynamic> d) async {
    final savedDate = (d['claimedMissionDate'] ?? '').toString();
    final List<String> dailyList = savedDate == todayKey
        ? List<String>.from(d['claimedDailyMissions'] ?? [])
        : <String>[];

    currentUser = MemberUser(
      id: phone,
      name: d['name'] ?? 'Member 2S',
      phone: phone,
      email: d['email'] ?? '',
      photoUrl: d['photoUrl'] ?? '',
      isEmailVerified: d['isEmailVerified'] ?? false,
      isWaVerified: d['isWaVerified'] ?? true,
      emailMissionClaimed: d['emailMissionClaimed'] ?? false,
      points: (d['points'] ?? 150) as int,
      referralCode: d['referralCode'] ?? '2S-$phone',
      checkInStreak: (d['checkInStreak'] ?? 0) as int,
      lastCheckInDate: (d['lastCheckInDate'] as Timestamp?)?.toDate(),
      lastSpinDate: (d['lastSpinDate'] as Timestamp?)?.toDate(),
      claimedMissionDate: todayKey,
      claimedDailyMissions: dailyList,
    );
    await _loadUserHistories();
    await _loadLeaderboard();
    _listenServices();
    _listenStoreOrders();
    notifyListeners();
  }

  Future<void> updateProfilePhoto(String url) async {
    if (currentUser == null) return;
    currentUser!.photoUrl = url;
    await _db.collection('users').doc(currentUser!.id).update({'photoUrl': url});
    notifyListeners();
  }

  Future<MemberUser?> lookupMemberByPhone(String rawInput) async {
    var clean = rawInput.trim();
    if (clean.startsWith('2SMEMBER|')) {
      clean = clean.replaceFirst('2SMEMBER|', '');
    }
    final isTemp = clean.toUpperCase().startsWith('TEMP-');
    final phone = isTemp ? clean.toUpperCase() : normalizePhone(clean);
    if (!isTemp && phone.length < 9) return null;
    final doc = await _db.collection('users').doc(phone).get();
    if (!doc.exists) return null;
    final d = doc.data()!;
    return MemberUser(
      id: phone,
      name: d['name'] ?? 'Member 2S',
      phone: phone,
      email: d['email'] ?? '',
      photoUrl: d['photoUrl'] ?? '',
      isEmailVerified: d['isEmailVerified'] ?? false,
      isWaVerified: d['isWaVerified'] ?? true,
      points: (d['points'] ?? 0) as int,
      referralCode: d['referralCode'] ?? '2S-$phone',
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('2s_logged_phone');
    try {
      await FirebaseAuth.instance.signOut();
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _srvSub?.cancel();
    await _ordSub?.cancel();
    currentUser = null;
    isAdminMode = false;
    services = [];
    storeOrders = [];
    pointHistories = [];
    notifyListeners();
  }

  void _listenServices() {
    _srvSub?.cancel();
    _srvSub = _db.collection('services').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      services = snap.docs.map((doc) {
        final d = doc.data();
        return ServiceOrder(
          id: doc.id,
          invoiceNo: d['invoiceNo'] ?? '-',
          customerPhone: d['customerPhone'] ?? '',
          customerName: d['customerName'] ?? '',
          brand: d['brand'] ?? '',
          deviceType: d['deviceType'] ?? '',
          deviceName: d['deviceName'] ?? '-',
          complaint: d['complaint'] ?? '-',
          replacedPart: d['replacedPart'] ?? '-',
          photoUrl: d['photoUrl'] ?? '',
          claimCode: d['claimCode'] ?? '',
          claimUsed: d['claimUsed'] ?? false,
          status: d['status'] ?? 'Menunggu Cek',
          totalCost: (d['totalCost'] ?? 0) as int,
          createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          warrantyDays: (d['warrantyDays'] ?? 30) as int,
          warrantyClaimed: d['warrantyClaimed'] ?? false,
        );
      }).toList();
      notifyListeners();
    });
  }

  void _listenStoreOrders() {
    _ordSub?.cancel();
    _ordSub = _db.collection('store_orders').orderBy('createdAt', descending: true).limit(50).snapshots().listen((snap) {
      storeOrders = snap.docs.map((doc) {
        final d = doc.data();
        return StoreOrder(
          id: doc.id,
          orderNo: d['orderNo'] ?? '-',
          customerPhone: d['customerPhone'] ?? '',
          customerName: d['customerName'] ?? '-',
          productName: d['productName'] ?? '-',
          finalTotal: (d['finalTotal'] ?? 0) as int,
          pointsUsed: (d['pointsUsed'] ?? 0) as int,
          voucherCode: d['voucherCode'] ?? '',
          deliveryType: d['deliveryType'] ?? 'Ambil di Toko',
          status: d['status'] ?? 'Menunggu',
          createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      notifyListeners();
    });
  }

  Future<void> _loadUserHistories() async {
    if (currentUser == null) return;
    final snap = await _db.collection('users').doc(currentUser!.id).collection('point_histories').orderBy('date', descending: true).limit(20).get();
    pointHistories = snap.docs.map((doc) {
      final d = doc.data();
      return PointHistory(d['title'] ?? 'Poin', (d['amount'] ?? 0) as int, (d['date'] as Timestamp?)?.toDate() ?? DateTime.now());
    }).toList();
  }

  Future<void> _loadLeaderboard() async {
    final snap = await _db.collection('users').orderBy('points', descending: true).limit(10).get();
    leaderboard = snap.docs.map((doc) {
      final d = doc.data();
      final pts = (d['points'] ?? 0) as int;
      final tier = pts >= 2000 ? 'Platinum' : (pts >= 1000 ? 'Gold' : (pts >= 400 ? 'Silver' : 'Bronze'));
      return {'name': d['name'] ?? 'Member', 'points': pts, 'tier': tier};
    }).toList();
  }

  Future<String> sendRealEmailVerification(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final auth = FirebaseAuth.instance;
      UserCredential cred;
      try {
        cred = await auth.createUserWithEmailAndPassword(email: cleanEmail, password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          cred = await auth.signInWithEmailAndPassword(email: cleanEmail, password: password);
        } else {
          return 'Gagal: ${e.message}';
        }
      }
      if (cred.user != null && !cred.user!.emailVerified) {
        await cred.user!.sendEmailVerification();
        return 'Link verifikasi dikirim ke $cleanEmail! Cek Inbox/Spam.';
      } else if (cred.user?.emailVerified == true) {
        await markEmailVerifiedInDb(cleanEmail);
        return 'Email sudah terverifikasi!';
      }
      return 'Silakan cek email Anda.';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<bool> checkEmailVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed != null && refreshed.emailVerified) {
      await markEmailVerifiedInDb((refreshed.email ?? '').toLowerCase());
      return true;
    }
    return false;
  }

  Future<void> markEmailVerifiedInDb(String email) async {
    if (currentUser == null || currentUser!.isEmailVerified) return;
    currentUser!.email = email.toLowerCase();
    currentUser!.isEmailVerified = true;
    await _db.collection('users').doc(currentUser!.id).update({'email': email.toLowerCase(), 'isEmailVerified': true});
    await addPoints(50, 'Bonus Verifikasi Email');
  }

  bool canCheckInToday() => currentUser != null && !_isSameDay(currentUser!.lastCheckInDate);
  bool canSpinFreeToday() => currentUser != null && !_isSameDay(currentUser!.lastSpinDate);

  bool isMissionClaimed(String id) {
    if (currentUser == null) return false;
    if (id == 'm_email') return currentUser!.emailMissionClaimed;
    if (currentUser!.claimedMissionDate != todayKey) return false;
    return currentUser!.claimedDailyMissions.contains(id);
  }

  bool isMissionCompleted(String id) {
    if (currentUser == null) return false;
    if (id == 'm_email') return currentUser!.isEmailVerified;
    if (id == 'm_checkin') return !canCheckInToday();
    if (id == 'm_spin') return !canSpinFreeToday();
    return false;
  }

  Future<void> claimMission(String id, int reward, String title) async {
    if (currentUser == null || isMissionClaimed(id) || !isMissionCompleted(id)) return;
    if (id == 'm_email') {
      currentUser!.emailMissionClaimed = true;
      await _db.collection('users').doc(currentUser!.id).update({'emailMissionClaimed': true});
    } else {
      if (currentUser!.claimedMissionDate != todayKey) {
        currentUser!.claimedMissionDate = todayKey;
        currentUser!.claimedDailyMissions = [id];
      } else {
        currentUser!.claimedDailyMissions = [...currentUser!.claimedDailyMissions, id];
      }
      await _db.collection('users').doc(currentUser!.id).update({
        'claimedMissionDate': todayKey,
        'claimedDailyMissions': currentUser!.claimedDailyMissions,
      });
    }
    await addPoints(reward, 'Klaim Misi: $title');
  }

  Future<int> performDailyCheckIn() async {
    if (currentUser == null || !canCheckInToday()) return 0;
    currentUser!.checkInStreak = (currentUser!.checkInStreak % 7) + 1;
    currentUser!.lastCheckInDate = DateTime.now();
    final reward = 15 + (currentUser!.checkInStreak * 5);
    await _db.collection('users').doc(currentUser!.id).update({
      'checkInStreak': currentUser!.checkInStreak,
      'lastCheckInDate': Timestamp.fromDate(currentUser!.lastCheckInDate!),
    });
    await addPoints(reward, 'Check-in Hari ke-${currentUser!.checkInStreak}');
    return reward;
  }

  Future<String> spinWheelReward() async {
    if (currentUser == null) return '';
    if (!canSpinFreeToday()) {
      if (currentUser!.points < 20) return 'Poin tidak cukup (butuh 20 poin)';
      await addPoints(-20, 'Tiket Putar Mini Game');
    } else {
      currentUser!.lastSpinDate = DateTime.now();
      await _db.collection('users').doc(currentUser!.id).update({
        'lastSpinDate': Timestamp.fromDate(currentUser!.lastSpinDate!),
      });
    }
    final rewards = [10, 25, 50, 100, 0];
    final win = rewards[Random().nextInt(rewards.length)];
    if (win == 0) {
      extraStoreDiscount = 15000;
      notifyListeners();
      return 'Menang Voucher Diskon Store Rp 15.000!';
    } else {
      await addPoints(win, 'Hadiah Mini Game Spin Wheel');
      return 'Selamat! Dapat +$win Poin!';
    }
  }

  Future<void> addPoints(int amount, String title) async {
    if (currentUser == null) return;
    currentUser!.points += amount;
    pointHistories.insert(0, PointHistory(title, amount, DateTime.now()));
    await _db.collection('users').doc(currentUser!.id).update({'points': FieldValue.increment(amount)});
    await _db.collection('users').doc(currentUser!.id).collection('point_histories').add({
      'title': title,
      'amount': amount,
      'date': FieldValue.serverTimestamp(),
    });
    await _loadLeaderboard();
    notifyListeners();
  }

  // PEMBUATAN NOTA + AUTO-DAFTAR (TERMASUK AKUN TEMP) + KODE KLAIM 6 DIGIT
  Future<ServiceOrder> addNewService({
    required String custPhone,
    required String custName,
    required String brand,
    required String deviceType,
    required String complaint,
    required String repairAction,
    required int cost,
    required int warrantyDays,
    String photoUrl = '',
  }) async {
    final trimmed = custPhone.trim().toUpperCase();
    final isTemp = trimmed.startsWith('TEMP-');
    final phone = isTemp ? trimmed : normalizePhone(custPhone);
    final finalName = custName.trim().isEmpty ? 'Member 2S' : custName.trim();

    if (isTemp || phone.length >= 9) {
      final userRef = _db.collection('users').doc(phone);
      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        final suffix = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
        await userRef.set({
          'name': finalName,
          'phone': phone,
          'photoUrl': '',
          'passwordHash': '',
          'isTempAccount': isTemp,
          'isWaVerified': false,
          'email': '',
          'isEmailVerified': false,
          'emailMissionClaimed': false,
          'points': 150,
          'referralCode': '2S-$suffix',
          'checkInStreak': 0,
          'lastCheckInDate': null,
          'lastSpinDate': null,
          'claimedMissionDate': '',
          'claimedDailyMissions': [],
          'createdByCashier': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await userRef.collection('point_histories').add({
          'title': 'Bonus Member Baru (Terdaftar via Nota)',
          'amount': 150,
          'date': FieldValue.serverTimestamp(),
        });
      }
    }

    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    final claimCode = List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();

    final now = DateTime.now();
    final inv = '2S-INV-${now.millisecondsSinceEpoch.toString().substring(7)}';
    final fullDevice = '$brand $deviceType'.trim();
    final docRef = await _db.collection('services').add({
      'invoiceNo': inv,
      'customerPhone': phone,
      'customerName': finalName,
      'brand': brand.trim(),
      'deviceType': deviceType.trim(),
      'deviceName': fullDevice.isEmpty ? 'Handphone' : fullDevice,
      'complaint': complaint.trim(),
      'replacedPart': repairAction.trim(),
      'photoUrl': photoUrl,
      'claimCode': claimCode,
      'claimUsed': false,
      'status': 'Menunggu Cek',
      'totalCost': cost,
      'warrantyDays': warrantyDays,
      'warrantyClaimed': false,
      'createdAt': Timestamp.fromDate(now),
    });

    return ServiceOrder(
      id: docRef.id,
      invoiceNo: inv,
      customerPhone: phone,
      customerName: finalName,
      brand: brand.trim(),
      deviceType: deviceType.trim(),
      deviceName: fullDevice.isEmpty ? 'Handphone' : fullDevice,
      complaint: complaint.trim(),
      replacedPart: repairAction.trim(),
      photoUrl: photoUrl,
      claimCode: claimCode,
      claimUsed: false,
      status: 'Menunggu Cek',
      totalCost: cost,
      createdAt: now,
      warrantyDays: warrantyDays,
    );
  }

  // KASIR EDIT NO. HP LANGSUNG DI NOTA (JIKA SALAH KETIK DI TOKO)
  Future<String?> updateServiceCustomerPhone(ServiceOrder s, String newRawPhone) async {
    final newPhone = normalizePhone(newRawPhone);
    if (newPhone.length < 9) return 'Nomor WA baru tidak valid.';

    final userRef = _db.collection('users').doc(newPhone);
    final userDoc = await userRef.get();
    if (!userDoc.exists) {
      final suffix = newPhone.length >= 4 ? newPhone.substring(newPhone.length - 4) : newPhone;
      await userRef.set({
        'name': s.customerName.isEmpty ? 'Member 2S' : s.customerName,
        'phone': newPhone,
        'photoUrl': '',
        'passwordHash': '',
        'isWaVerified': false,
        'email': '',
        'isEmailVerified': false,
        'emailMissionClaimed': false,
        'points': 150,
        'referralCode': '2S-$suffix',
        'checkInStreak': 0,
        'createdByCashier': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await _db.collection('services').doc(s.id).update({'customerPhone': newPhone});
    return null;
  }

  Future<void> updateServiceStatus(ServiceOrder s, String newStatus) async {
    await _db.collection('services').doc(s.id).update({'status': newStatus});
    if (newStatus == 'Selesai' && s.customerPhone.isNotEmpty) {
      await _db.collection('users').doc(s.customerPhone).set({'points': FieldValue.increment(50)}, SetOptions(merge: true));
      if (s.customerPhone == currentUser?.id) {
        currentUser!.points += 50;
        pointHistories.insert(0, PointHistory('Poin Servis ${s.invoiceNo}', 50, DateTime.now()));
      }
    }
    notifyListeners();
  }

  Future<void> claimWarranty(ServiceOrder s) async {
    await _db.collection('services').doc(s.id).update({'warrantyClaimed': true});
  }

  Future<void> addProduct({
    required String name,
    required String category,
    required int price,
    required int discountPercent,
    required int stock,
    String photoUrl = '',
  }) async {
    await _db.collection('products').add({
      'name': name.trim(),
      'category': category.trim().isEmpty ? 'Aksesoris' : category.trim(),
      'price': price,
      'discountPercent': discountPercent.clamp(0, 90),
      'stock': stock,
      'photoUrl': photoUrl,
    });
  }

  Future<void> deleteProduct(String productId) async {
    await _db.collection('products').doc(productId).delete();
  }

  Future<void> addVoucher({required String code, required int discountAmount, required int minSpend}) async {
    await _db.collection('vouchers').add({
      'code': code.trim().toUpperCase(),
      'discountAmount': discountAmount,
      'minSpend': minSpend,
      'isActive': true,
    });
  }

  VoucherItem? findValidVoucher(String rawCode, int subtotal) {
    final c = rawCode.trim().toUpperCase();
    if (c.isEmpty) return null;
    for (final v in vouchers) {
      if (v.isActive && v.code == c && subtotal >= v.minSpend) return v;
    }
    return null;
  }

  Future<String> checkoutProduct(
    StoreProduct p, {
    required bool usePoints,
    String voucherCode = '',
    String deliveryType = 'Ambil di Toko',
  }) async {
    if (currentUser == null) return 'Silakan login terlebih dahulu.';
    if (p.stock <= 0) return 'Maaf, stok ${p.name} sedang habis.';

    int total = p.finalPrice - extraStoreDiscount;
    final voucher = findValidVoucher(voucherCode, p.finalPrice);
    if (voucherCode.trim().isNotEmpty && voucher == null) {
      return 'Kode voucher tidak valid atau belum memenuhi minimal belanja.';
    }
    if (voucher != null) total -= voucher.discountAmount;
    if (total < 0) total = 0;

    int usedPts = 0;
    if (usePoints && currentUser!.points > 0) {
      final maxCut = min(total, currentUser!.points * 100);
      usedPts = (maxCut / 100).floor();
      total -= usedPts * 100;
      if (usedPts > 0) await addPoints(-usedPts, 'Tukar Poin Beli ${p.name}');
    }

    final ordNo = '2S-ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    await _db.collection('store_orders').add({
      'orderNo': ordNo,
      'customerPhone': currentUser!.phone,
      'customerName': currentUser!.name,
      'productId': p.id,
      'productName': p.name,
      'finalTotal': total,
      'pointsUsed': usedPts,
      'voucherCode': voucher?.code ?? '',
      'deliveryType': deliveryType,
      'status': 'Menunggu',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('products').doc(p.id).update({'stock': FieldValue.increment(-1)});

    extraStoreDiscount = 0;
    await addPoints(20, 'Cashback Poin Order $ordNo');
    return 'Pesanan $ordNo berhasil! Total bayar: ${formatRupiah(total)}';
  }

  Future<void> updateStoreOrderStatus(StoreOrder o, String newStatus) async {
    await _db.collection('store_orders').doc(o.id).update({'status': newStatus});
  }

  @override
  void dispose() {
    _otpSub?.cancel();
    _srvSub?.cancel();
    _prodSub?.cancel();
    _vouchSub?.cancel();
    _ordSub?.cancel();
    super.dispose();
  }
}
// AKHIR FILE data_store.dart

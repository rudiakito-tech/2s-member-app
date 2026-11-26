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
  String id, name, phone, email, referralCode;
  bool isEmailVerified, isWaVerified, freeSpinUsedToday;
  int points, checkInStreak;
  DateTime? lastCheckInDate;

  MemberUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.isEmailVerified = false,
    this.isWaVerified = true,
    this.points = 150,
    required this.referralCode,
    this.checkInStreak = 0,
    this.lastCheckInDate,
    this.freeSpinUsedToday = false,
  });

  String get tier {
    if (points >= 2000) return 'Platinum';
    if (points >= 1000) return 'Gold';
    if (points >= 400) return 'Silver';
    return 'Bronze';
  }
}

class ServiceOrder {
  final String id, invoiceNo, customerPhone, deviceName, complaint, replacedPart;
  String status;
  final int totalCost, warrantyDays;
  final DateTime createdAt;
  bool warrantyClaimed;

  ServiceOrder({
    required this.id,
    required this.invoiceNo,
    required this.customerPhone,
    required this.deviceName,
    required this.complaint,
    required this.replacedPart,
    required this.status,
    required this.totalCost,
    required this.createdAt,
    this.warrantyDays = 30,
    this.warrantyClaimed = false,
  });

  DateTime get warrantyExpiredAt => createdAt.add(Duration(days: warrantyDays));
  int get remainingWarrantyDays {
    final diff = warrantyExpiredAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }
}

class StoreProduct {
  final String id, name, category;
  final int price, discountPercent;
  final IconData icon;

  StoreProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.discountPercent = 0,
    required this.icon,
  });

  int get finalPrice => (price * (100 - discountPercent) / 100).round();
}

class MissionItem {
  final String id, title, description;
  final int rewardPoints;
  bool isCompleted, isClaimed;

  MissionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardPoints,
    this.isCompleted = false,
    this.isClaimed = false,
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
  String? pendingGoogleEmail;
  String? pendingGoogleName;
  String? verifiedResetPhone;

  StreamSubscription<DocumentSnapshot>? _otpSub;
  StreamSubscription<QuerySnapshot>? _srvSub;

  List<ServiceOrder> services = [];
  List<PointHistory> pointHistories = [];
  List<Map<String, dynamic>> leaderboard = [];

  bool get isGuest => currentUser == null;
  bool get canUseAdmin => !isGuest && AppConfig.adminWaNumbers.contains(currentUser!.phone);

  final List<StoreProduct> products = [
    StoreProduct(id: 'p1', name: 'Kabel Data Fast Charging 65W', category: 'Aksesoris', price: 65000, discountPercent: 20, icon: Icons.cable),
    StoreProduct(id: 'p2', name: 'Tempered Glass Anti-Spy', category: 'Pelindung', price: 45000, discountPercent: 10, icon: Icons.security),
    StoreProduct(id: 'p3', name: 'Charger Adapter GaN 33W', category: 'Charger', price: 150000, discountPercent: 15, icon: Icons.battery_charging_full),
    StoreProduct(id: 'p4', name: 'TWS Earbuds 2S Bass', category: 'Audio', price: 199000, discountPercent: 25, icon: Icons.headphones),
  ];

  final List<MissionItem> missions = [
    MissionItem(id: 'm1', title: 'Verifikasi Email', description: 'Verifikasi email asli di menu Profil', rewardPoints: 100),
    MissionItem(id: 'm2', title: 'Check-In Pertama', description: 'Lakukan check-in harian hari ini', rewardPoints: 30),
    MissionItem(id: 'm3', title: 'Ajak Teman Affiliate', description: 'Teman daftar pakai kode referral Anda', rewardPoints: 150),
  ];

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

  Future<void> initSession() async {
    try {
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

  // LOGIN 1: EMAIL / NO. WA + PASSWORD (MENDUKUNG INGAT SAYA)
  Future<String?> loginWithPassword(String rawInput, String password, {bool rememberMe = true}) async {
    final input = rawInput.trim();
    if (input.contains('@')) {
      return loginWithGmail(input, password, rememberMe: rememberMe);
    }

    final phone = normalizePhone(input);
    if (phone.length < 9) return 'Nomor WhatsApp / Email tidak valid.';
    if (password.length < 6) return 'Password minimal 6 karakter.';

    final doc = await _db.collection('users').doc(phone).get();
    if (!doc.exists) return 'Nomor WA belum terdaftar. Silakan Daftar Sekarang.';

    final data = doc.data()!;
    final storedHash = (data['passwordHash'] ?? '').toString();
    if (storedHash.isEmpty) return 'Akun belum punya password. Gunakan Lupa Password.';
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

  // LOGIN 2: TOMBOL RESMI GOOGLE
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
      if (idToken == null) {
        return GoogleAuthResult(error: 'Token Google kosong. Pastikan Web Client ID & SHA-1 di Firebase sudah benar.');
      }

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
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return GoogleAuthResult(error: 'Login Google dibatalkan.');
      }
      return GoogleAuthResult(error: 'Google Sign-In gagal (${e.code.name}): ${e.description ?? "Periksa SHA-1 di Firebase"}');
    } catch (e) {
      return GoogleAuthResult(error: 'Error Google Sign-In: $e');
    }
  }

  // REVERSE OTP WA DENGAN VALIDASI KETAT NOMOR HP
  Future<OtpStartResult> startReverseOtp({
    required String mode, // 'register' atau 'reset'
    required String rawPhone,
    String name = '',
    String password = '',
    String refCode = '',
    required void Function(String wrongPhone) onMismatch,
    required void Function(String? error) onCompleted,
  }) async {
    final expectedPhone = normalizePhone(rawPhone);
    if (expectedPhone.length < 9) {
      return OtpStartResult(error: 'Nomor WhatsApp wajib diisi dengan benar (contoh: 0812...).');
    }

    final existing = await _db.collection('users').doc(expectedPhone).get();
    if (mode == 'register' && existing.exists && (existing.data()?['passwordHash'] ?? '').toString().isNotEmpty) {
      return OtpStartResult(error: 'Nomor WA $expectedPhone sudah terdaftar! Silakan langsung Login.');
    }
    if (mode == 'reset' && !existing.exists) {
      return OtpStartResult(error: 'Nomor WA $expectedPhone belum terdaftar! Silakan Daftar Akun.');
    }

    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    final code = '2S-${List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join()}';

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
  }) async {
    final userRef = _db.collection('users').doc(phone);
    final doc = await userRef.get();

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
        'passwordHash': passHash,
        'isWaVerified': true,
        'email': hasGoogle ? pendingGoogleEmail : (doc.data()?['email'] ?? ''),
        'isEmailVerified': hasGoogle ? true : (doc.data()?['isEmailVerified'] ?? false),
        'points': doc.exists ? (doc.data()?['points'] ?? startPts) : startPts,
        'referralCode': doc.data()?['referralCode'] ?? '2S-$suffix',
        'checkInStreak': doc.data()?['checkInStreak'] ?? 0,
        'lastCheckInDate': doc.data()?['lastCheckInDate'],
        'freeSpinUsedToday': doc.data()?['freeSpinUsedToday'] ?? false,
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

      final fresh = await userRef.get();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('2s_logged_phone', phone);
      await _applyLoggedInUser(phone, fresh.data()!);
      return null;
    } else {
      // Mode reset: simpan nomor terverifikasi, lalu lanjut ke layar "Buat Password Baru"
      if (!doc.exists) return 'Nomor WA $phone belum terdaftar.';
      verifiedResetPhone = phone;
      return null;
    }
  }

  Future<String?> saveNewPasswordAfterReset(String newPassword) async {
    final phone = verifiedResetPhone;
    if (phone == null || phone.isEmpty) {
      return 'Sesi verifikasi habis. Ulangi proses Lupa Password.';
    }
    final doc = await _db.collection('users').doc(phone).get();
    if (!doc.exists) return 'Akun tidak ditemukan.';

    final newHash = _hashPassword(phone, newPassword);
    final oldHash = (doc.data()?['passwordHash'] ?? '').toString();
    if (oldHash.isNotEmpty && newHash == oldHash) {
      return 'Password baru tidak boleh sama dengan password lama.';
    }

    await _db.collection('users').doc(phone).update({
      'passwordHash': newHash,
      'isWaVerified': true,
    });
    verifiedResetPhone = null;
    return null;
  }

  Future<void> _applyLoggedInUser(String phone, Map<String, dynamic> d) async {
    currentUser = MemberUser(
      id: phone,
      name: d['name'] ?? 'Member 2S',
      phone: phone,
      email: d['email'] ?? '',
      isEmailVerified: d['isEmailVerified'] ?? false,
      isWaVerified: d['isWaVerified'] ?? true,
      points: (d['points'] ?? 150) as int,
      referralCode: d['referralCode'] ?? '2S-$phone',
      checkInStreak: (d['checkInStreak'] ?? 0) as int,
      lastCheckInDate: (d['lastCheckInDate'] as Timestamp?)?.toDate(),
      freeSpinUsedToday: d['freeSpinUsedToday'] ?? false,
    );
    missions[0].isCompleted = currentUser!.isEmailVerified;
    await _loadUserHistories();
    await _loadLeaderboard();
    _listenServices();
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('2s_logged_phone');
    try {
      await FirebaseAuth.instance.signOut();
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _srvSub?.cancel();
    currentUser = null;
    isAdminMode = false;
    services = [];
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
          deviceName: d['deviceName'] ?? '-',
          complaint: d['complaint'] ?? '-',
          replacedPart: d['replacedPart'] ?? '-',
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
    missions[0].isCompleted = true;
    await _db.collection('users').doc(currentUser!.id).update({'email': email.toLowerCase(), 'isEmailVerified': true});
    await addPoints(50, 'Bonus Verifikasi Email');
  }

  bool canCheckInToday() {
    final last = currentUser?.lastCheckInDate;
    if (last == null) return true;
    final now = DateTime.now();
    return !(last.year == now.year && last.month == now.month && last.day == now.day);
  }

  Future<int> performDailyCheckIn() async {
    if (currentUser == null || !canCheckInToday()) return 0;
    currentUser!.checkInStreak = (currentUser!.checkInStreak % 7) + 1;
    currentUser!.lastCheckInDate = DateTime.now();
    missions[1].isCompleted = true;
    final reward = 15 + (currentUser!.checkInStreak * 5);
    await _db.collection('users').doc(currentUser!.id).update({
      'checkInStreak': currentUser!.checkInStreak,
      'lastCheckInDate': Timestamp.fromDate(currentUser!.lastCheckInDate!),
    });
    await addPoints(reward, 'Check-in Hari ke-${currentUser!.checkInStreak}');
    return reward;
  }

  Future<void> claimMission(MissionItem m) async {
    if (!m.isCompleted || m.isClaimed) return;
    m.isClaimed = true;
    await addPoints(m.rewardPoints, 'Klaim Misi: ${m.title}');
  }

  Future<String> spinWheelReward() async {
    if (currentUser == null) return '';
    if (currentUser!.freeSpinUsedToday) {
      if (currentUser!.points < 20) return 'Poin tidak cukup (butuh 20 poin)';
      await addPoints(-20, 'Tiket Putar Mini Game');
    } else {
      currentUser!.freeSpinUsedToday = true;
      await _db.collection('users').doc(currentUser!.id).update({'freeSpinUsedToday': true});
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

  Future<void> addNewService(String custPhone, String device, String complaint, String part, int cost, int warranty) async {
    final inv = '2S-INV-${100 + services.length + 1}';
    await _db.collection('services').add({
      'invoiceNo': inv,
      'customerPhone': normalizePhone(custPhone),
      'deviceName': device,
      'complaint': complaint,
      'replacedPart': part,
      'status': 'Menunggu Cek',
      'totalCost': cost,
      'warrantyDays': warranty,
      'warrantyClaimed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
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

  Future<String> checkoutProduct(StoreProduct p, bool usePoints) async {
    if (currentUser == null) return 'Silakan login';
    int total = p.finalPrice - extraStoreDiscount;
    if (total < 0) total = 0;
    if (usePoints && currentUser!.points > 0) {
      final maxCut = min(total, currentUser!.points * 100);
      final usedPts = (maxCut / 100).floor();
      total -= usedPts * 100;
      if (usedPts > 0) await addPoints(-usedPts, 'Tukar Poin Beli ${p.name}');
    }
    extraStoreDiscount = 0;
    await addPoints(20, 'Cashback Poin Belanja Store');
    return 'Order ${p.name} berhasil! Total bayar: ${formatRupiah(total)}';
  }

  @override
  void dispose() {
    _otpSub?.cancel();
    _srvSub?.cancel();
    super.dispose();
  }
}

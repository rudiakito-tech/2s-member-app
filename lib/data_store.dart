import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_config.dart';

class MemberUser {
  String id, name, phone, email, referralCode, referredBy;
  bool isEmailVerified;
  int points, checkInStreak, extraStoreDiscount;
  String lastCheckInDate, lastFreeSpinDate;
  List<String> claimedMissions;

  MemberUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.isEmailVerified = false,
    this.points = 150,
    required this.referralCode,
    this.referredBy = '',
    this.checkInStreak = 0,
    this.lastCheckInDate = '',
    this.lastFreeSpinDate = '',
    this.extraStoreDiscount = 0,
    this.claimedMissions = const [],
  });

  String get tier {
    if (points >= 2000) return 'Platinum';
    if (points >= 1000) return 'Gold';
    if (points >= 400) return 'Silver';
    return 'Bronze';
  }

  factory MemberUser.fromMap(String id, Map<String, dynamic> m) => MemberUser(
        id: id,
        name: (m['name'] ?? 'Member 2S').toString(),
        phone: (m['phone'] ?? id).toString(),
        email: (m['email'] ?? '').toString(),
        isEmailVerified: m['isEmailVerified'] == true,
        points: _toInt(m['points'], 0),
        referralCode: (m['referralCode'] ?? '2S-$id').toString(),
        referredBy: (m['referredBy'] ?? '').toString(),
        checkInStreak: _toInt(m['checkInStreak'], 0),
        lastCheckInDate: (m['lastCheckInDate'] ?? '').toString(),
        lastFreeSpinDate: (m['lastFreeSpinDate'] ?? '').toString(),
        extraStoreDiscount: _toInt(m['extraStoreDiscount'], 0),
        claimedMissions: List<String>.from(m['claimedMissions'] ?? []),
      );
}

class ServiceOrder {
  final String id, invoiceNo, userPhone, deviceName, complaint, replacedPart, status;
  final int totalCost, warrantyDays;
  final DateTime createdAt;
  final bool warrantyClaimed;

  ServiceOrder({
    required this.id,
    required this.invoiceNo,
    required this.userPhone,
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

  factory ServiceOrder.fromMap(String id, Map<String, dynamic> m) => ServiceOrder(
        id: id,
        invoiceNo: (m['invoiceNo'] ?? id).toString(),
        userPhone: (m['userPhone'] ?? '').toString(),
        deviceName: (m['deviceName'] ?? 'Handphone').toString(),
        complaint: (m['complaint'] ?? '-').toString(),
        replacedPart: (m['replacedPart'] ?? '-').toString(),
        status: (m['status'] ?? 'Menunggu Cek').toString(),
        totalCost: _toInt(m['totalCost'], 0),
        createdAt: _toDate(m['createdAt']),
        warrantyDays: _toInt(m['warrantyDays'], 30),
        warrantyClaimed: m['warrantyClaimed'] == true,
      );
}

class StoreProduct {
  final String id, name, category, imageUrl;
  final int price, discountPercent;
  final bool isActive;

  StoreProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.discountPercent = 0,
    this.imageUrl = '',
    this.isActive = true,
  });

  int get finalPrice => (price * (100 - discountPercent) / 100).round();

  factory StoreProduct.fromMap(String id, Map<String, dynamic> m) => StoreProduct(
        id: id,
        name: (m['name'] ?? 'Produk 2S').toString(),
        category: (m['category'] ?? 'Aksesoris').toString(),
        price: _toInt(m['price'], 0),
        discountPercent: _toInt(m['discountPercent'], 0),
        imageUrl: (m['imageUrl'] ?? '').toString(),
        isActive: m['isActive'] ?? true,
      );
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

int _toInt(dynamic v, [int def = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? def;
}

DateTime _toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

class AppDataController extends ChangeNotifier {
  MemberUser? currentUser;
  String? pendingOtp;
  List<ServiceOrder> services = [];
  List<StoreProduct> products = [];
  List<PointHistory> pointHistories = [];
  List<Map<String, dynamic>> leaderboard = [];

  final _subs = <StreamSubscription>[];
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  List<MissionItem> get missions {
    final u = currentUser;
    if (u == null) return [];
    return [
      MissionItem(
        id: 'm1',
        title: 'Verifikasi Email',
        description: 'Verifikasi email aktif di menu Profil',
        rewardPoints: 100,
        isCompleted: u.isEmailVerified,
        isClaimed: u.claimedMissions.contains('m1'),
      ),
      MissionItem(
        id: 'm2',
        title: 'Check-In Harian',
        description: 'Lakukan check-in hari ini',
        rewardPoints: 30,
        isCompleted: u.lastCheckInDate == _todayKey,
        isClaimed: u.claimedMissions.contains('m2_${_todayKey}'),
      ),
      MissionItem(
        id: 'm3',
        title: 'Servis / Belanja Pertama',
        description: 'Punya minimal 1 riwayat transaksi servis',
        rewardPoints: 150,
        isCompleted: services.isNotEmpty,
        isClaimed: u.claimedMissions.contains('m3'),
      ),
    ];
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

  String normalizePhone(String phone) {
    var clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('62')) clean = '0${clean.substring(2)}';
    return clean;
  }

  String requestWhatsappOtp(String phone) {
    final code = (100000 + Random().nextInt(900000)).toString();
    pendingOtp = code;
    return code;
  }

  Future<String?> verifyWhatsappOtp(String phone, String name, String code, String ref) async {
    if (code.trim() != pendingOtp) return 'Kode OTP salah!';
    final cleanPhone = normalizePhone(phone);
    if (cleanPhone.length < 9) return 'Nomor WhatsApp tidak valid!';

    if (!AppConfig.useFirebase) return 'Aktifkan useFirebase = true di app_config.dart';

    final userRef = _db.collection('users').doc(cleanPhone);
    final snap = await userRef.get();

    if (!snap.exists) {
      final suffix = cleanPhone.substring(cleanPhone.length - 4);
      final newUser = {
        'name': name.trim().isEmpty ? 'Member 2S' : name.trim(),
        'phone': cleanPhone,
        'email': '',
        'isEmailVerified': false,
        'points': ref.trim().isNotEmpty ? 200 : 150,
        'referralCode': '2S-$suffix',
        'referredBy': ref.trim().toUpperCase(),
        'checkInStreak': 0,
        'lastCheckInDate': '',
        'lastFreeSpinDate': '',
        'extraStoreDiscount': 0,
        'claimedMissions': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      };
      await userRef.set(newUser);
      await _addPointLog(cleanPhone, 'Bonus Member Baru 2S', ref.trim().isNotEmpty ? 200 : 150);

      // Bonus affiliate ke pengajak jika kode referral valid
      if (ref.trim().isNotEmpty) {
        final refQ = await _db
            .collection('users')
            .where('referralCode', isEqualTo: ref.trim().toUpperCase())
            .limit(1)
            .get();
        if (refQ.docs.isNotEmpty) {
          final inviterDoc = refQ.docs.first;
          await inviterDoc.reference.update({'points': FieldValue.increment(100)});
          await _addPointLog(inviterDoc.id, 'Komisi Affiliate (${cleanPhone})', 100);
        }
      }
    }

    await _seedInitialStoreAndSampleService(cleanPhone);
    _startRealtimeListeners(cleanPhone);
    return null;
  }

  Future<void> _seedInitialStoreAndSampleService(String phone) async {
    final prodSnap = await _db.collection('products').limit(1).get();
    if (prodSnap.docs.isEmpty) {
      final samples = [
        {'name': 'Kabel Data Fast Charging 65W', 'category': 'Aksesoris', 'price': 65000, 'discountPercent': 20, 'isActive': true},
        {'name': 'Tempered Glass Anti-Spy', 'category': 'Pelindung', 'price': 45000, 'discountPercent': 10, 'isActive': true},
        {'name': 'Charger Adapter GaN 33W', 'category': 'Charger', 'price': 150000, 'discountPercent': 15, 'isActive': true},
      ];
      for (final p in samples) {
        await _db.collection('products').add(p);
      }
    }
  }

  void _startRealtimeListeners(String phone) {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();

    // 1. User profile & points real-time
    _subs.add(_db.collection('users').doc(phone).snapshots().listen((doc) {
      if (doc.exists && doc.data() != null) {
        currentUser = MemberUser.fromMap(doc.id, doc.data()!);
        notifyListeners();
      }
    }));

    // 2. Transaksi Servis real-time (sort di Dart agar tidak perlu composite index)
    _subs.add(_db.collection('services').where('userPhone', isEqualTo: phone).snapshots().listen((snap) {
      services = snap.docs.map((d) => ServiceOrder.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }));

    // 3. Katalog Store real-time
    _subs.add(_db.collection('products').snapshots().listen((snap) {
      products = snap.docs
          .map((d) => StoreProduct.fromMap(d.id, d.data()))
          .where((p) => p.isActive)
          .toList();
      notifyListeners();
    }));

    // 4. Riwayat Poin real-time (subcollection)
    _subs.add(_db
        .collection('users')
        .doc(phone)
        .collection('point_histories')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .listen((snap) {
      pointHistories = snap.docs
          .map((d) => PointHistory(
                (d.data()['title'] ?? '').toString(),
                _toInt(d.data()['amount'], 0),
                _toDate(d.data()['createdAt']),
              ))
          .toList();
      notifyListeners();
    }));

    // 5. Leaderboard real-time
    _subs.add(_db
        .collection('users')
        .orderBy('points', descending: true)
        .limit(15)
        .snapshots()
        .listen((snap) {
      leaderboard = snap.docs.map((d) {
        final u = MemberUser.fromMap(d.id, d.data());
        return {'name': u.name, 'points': u.points, 'tier': u.tier, 'phone': u.phone};
      }).toList();
      notifyListeners();
    }));
  }

  Future<void> _addPointLog(String phone, String title, int amount) async {
    await _db.collection('users').doc(phone).collection('point_histories').add({
      'title': title,
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addPoints(int amount, String title) async {
    final u = currentUser;
    if (u == null) return;
    await _db.collection('users').doc(u.id).update({'points': FieldValue.increment(amount)});
    await _addPointLog(u.id, title, amount);
  }

  bool canCheckInToday() => currentUser != null && currentUser!.lastCheckInDate != _todayKey;

  Future<int> performDailyCheckIn() async {
    final u = currentUser;
    if (u == null || !canCheckInToday()) return 0;
    final nextStreak = (u.checkInStreak % 7) + 1;
    final reward = 15 + (nextStreak * 5);
    await _db.collection('users').doc(u.id).update({
      'checkInStreak': nextStreak,
      'lastCheckInDate': _todayKey,
      'points': FieldValue.increment(reward),
    });
    await _addPointLog(u.id, 'Check-in Hari ke-$nextStreak', reward);
    return reward;
  }

  Future<void> claimMission(MissionItem m) async {
    final u = currentUser;
    if (u == null || !m.isCompleted || m.isClaimed) return;
    final key = m.id == 'm2' ? 'm2_${_todayKey}' : m.id;
    await _db.collection('users').doc(u.id).update({
      'claimedMissions': FieldValue.arrayUnion([key]),
      'points': FieldValue.increment(m.rewardPoints),
    });
    await _addPointLog(u.id, 'Klaim Misi: ${m.title}', m.rewardPoints);
  }

  bool get freeSpinAvailable => currentUser != null && currentUser!.lastFreeSpinDate != _todayKey;

  Future<String> spinWheelReward() async {
    final u = currentUser;
    if (u == null) return '';
    if (!freeSpinAvailable) {
      if (u.points < 20) return 'Poin tidak cukup (butuh 20 poin)';
      await addPoints(-20, 'Tiket Putar Mini Game');
    } else {
      await _db.collection('users').doc(u.id).update({'lastFreeSpinDate': _todayKey});
    }

    final rewards = [10, 25, 50, 100, 0];
    final win = rewards[Random().nextInt(rewards.length)];
    if (win == 0) {
      await _db.collection('users').doc(u.id).update({'extraStoreDiscount': 15000});
      return 'Menang Voucher Diskon Store Rp 15.000!';
    } else {
      await addPoints(win, 'Hadiah Mini Game Spin Wheel');
      return 'Selamat! Dapat +$win Poin!';
    }
  }

  Future<void> claimWarranty(ServiceOrder s) async {
    await _db.collection('services').doc(s.id).update({'warrantyClaimed': true});
  }

  Future<String> checkoutProduct(StoreProduct p, bool usePoints) async {
    final u = currentUser;
    if (u == null) return 'Silakan login';
    int total = p.finalPrice - u.extraStoreDiscount;
    if (total < 0) total = 0;

    int usedPts = 0;
    if (usePoints && u.points > 0) {
      final maxCut = min(total, u.points * 100);
      usedPts = (maxCut / 100).floor();
      total -= usedPts * 100;
      if (usedPts > 0) await addPoints(-usedPts, 'Tukar Poin Beli ${p.name}');
    }
    if (u.extraStoreDiscount > 0) {
      await _db.collection('users').doc(u.id).update({'extraStoreDiscount': 0});
    }
    await _db.collection('orders').add({
      'userPhone': u.phone,
      'userName': u.name,
      'productId': p.id,
      'productName': p.name,
      'finalPaid': total,
      'pointsUsed': usedPts,
      'status': 'Diproses',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await addPoints(20, 'Cashback Poin Belanja Store');
    return 'Order ${p.name} masuk! Total bayar: ${formatRupiah(total)}';
  }

  Future<String> sendFirebaseEmailVerification(String email, String password) async {
    final auth = FirebaseAuth.instance;
    try {
      UserCredential cred;
      try {
        cred = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          cred = await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        } else {
          return e.message ?? 'Gagal mendaftarkan email';
        }
      }
      await cred.user?.sendEmailVerification();
      if (currentUser != null) {
        await _db.collection('users').doc(currentUser!.id).update({'email': email.trim()});
      }
      return 'OK';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<bool> checkAndCompleteEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || currentUser == null) return false;
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed != null && refreshed.emailVerified) {
      await _db.collection('users').doc(currentUser!.id).update({
        'email': refreshed.email ?? currentUser!.email,
        'isEmailVerified': true,
      });
      await addPoints(50, 'Bonus Verifikasi Email');
      return true;
    }
    return false;
  }

  void logout() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    currentUser = null;
    services = [];
    notifyListeners();
  }
}
